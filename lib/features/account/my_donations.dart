import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';
import '../../core/network/auth_service.dart';

// ─────────────────────────────────────────────
//  APP COLORS  (same palette as MyCampaigns)
// ─────────────────────────────────────────────
class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const savanna     = Color(0xFFE8A020);
  static const crimson     = Color(0xFFD93025);
  static const amber       = Color(0xFFE8860A);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF4F6F4);
  static const white       = Color(0xFFFFFFFF);
  static const darkBg      = Color(0xFF060E09);
  static const darkCard    = Color(0xFF0D1A11);
  static const darkBorder  = Color(0xFF1C2E22);
  static const darkMist    = Color(0xFF4D6657);
  static const mist        = Color(0xFF8FA896);
}

// ─────────────────────────────────────────────
//  AUTH STORE  (replace with your provider)
// ─────────────────────────────────────────────
class AuthStore {
  static String? token;
  static String? userId;
  static String? userEmail;
  static String? userName;
  static String? userPhone;
  static bool get isAuthenticated => token != null && token!.isNotEmpty;
}

// ─────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────
class Donation {
  final String id;
  final String? paymentReference;
  final double donationAmount;
  final double platformFee;
  final String? campaignTitle;
  final String? purpose;
  final String? paymentStatus;
  final String? createdAt;
  final String? donorEmail;
  final String? donorId;
  final String? donorPhone;

  Donation({
    required this.id,
    this.paymentReference,
    required this.donationAmount,
    required this.platformFee,
    this.campaignTitle,
    this.purpose,
    this.paymentStatus,
    this.createdAt,
    this.donorEmail,
    this.donorId,
    this.donorPhone,
  });

  factory Donation.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return Donation(
      id: j['_id']?.toString() ?? '',
      paymentReference: j['paymentReference']?.toString(),
      donationAmount: _d(j['donationAmount'] ?? j['amount']),
      platformFee: _d(j['platformFee'] ?? j['platform_fee']),
      campaignTitle: j['campaignTitle']?.toString(),
      purpose: j['purpose']?.toString(),
      paymentStatus: j['paymentStatus']?.toString(),
      createdAt: j['createdAt']?.toString(),
      donorEmail: (j['donorEmail'] ?? j['email'] ?? j['userEmail'])?.toString(),
      donorId: (j['donorId'] ?? j['userId'] ?? j['user_id'])?.toString(),
      donorPhone: (j['donorPhone'] ?? j['phoneNumber'] ?? j['phone'])?.toString(),
    );
  }

  String get campaign => campaignTitle ?? purpose ?? 'Unspecified';
}

class DonationMetrics {
  final int totalDonations;
  final double totalAmount;
  final double totalPlatformFee;
  final double averageDonation;
  final List<CampaignBreakdown> campaignBreakdown;
  final List<CampaignBreakdown> topCampaigns;

  DonationMetrics({
    this.totalDonations = 0,
    this.totalAmount = 0,
    this.totalPlatformFee = 0,
    this.averageDonation = 0,
    this.campaignBreakdown = const [],
    this.topCampaigns = const [],
  });
}

class CampaignBreakdown {
  final String name;
  double total;
  int count;
  CampaignBreakdown({required this.name, required this.total, required this.count});
}

// ─────────────────────────────────────────────
//  API SERVICE
// ─────────────────────────────────────────────
class DonationService {
  static const _base = 'https://api.inuafund.co.ke/api/v1/donations/user/donations';

  static Future<List<Donation>> fetchUserDonations() async {
    final params = <String, String>{};
    if (AuthStore.userEmail != null) params['email'] = AuthStore.userEmail!;
    if (AuthStore.userId != null) {
      params['userId'] = AuthStore.userId!;
      params['donorId'] = AuthStore.userId!;
    }
    if (AuthStore.userName != null) params['name'] = AuthStore.userName!;
    if (AuthStore.userPhone != null) params['phoneNumber'] = AuthStore.userPhone!;
    params['page'] = '1';
    params['limit'] = '1000';

    final uri = Uri.parse(_base).replace(queryParameters: params);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AuthStore.token != null) headers['Authorization'] = 'Bearer ${AuthStore.token}';

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final body = json.decode(res.body);
    if (body['status'] == 'success' || body['success'] == true) {
      final raw = (body['data']?['donations'] ?? body['donations'] ?? []) as List;
      final all = raw.map((e) => Donation.fromJson(e)).toList();
      return _filterUserDonations(all);
    }
    throw Exception(body['message'] ?? 'Failed to load donations');
  }

  static List<Donation> _filterUserDonations(List<Donation> all) {
    return all.where((d) {
      if (AuthStore.userEmail != null && d.donorEmail != null) {
        return d.donorEmail!.toLowerCase() == AuthStore.userEmail!.toLowerCase();
      }
      if (AuthStore.userId != null && d.donorId != null) {
        return d.donorId == AuthStore.userId;
      }
      if (AuthStore.userPhone != null && d.donorPhone != null) {
        return d.donorPhone == AuthStore.userPhone;
      }
      return false;
    }).toList();
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _kes(double v, {bool compact = false}) {
  if (compact) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(1)}K';
  }
  return 'KES ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

String _date(String? iso) {
  if (iso == null) return 'N/A';
  try {
    final d = DateTime.parse(iso);
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

DonationMetrics _calcMetrics(List<Donation> list) {
  if (list.isEmpty) return DonationMetrics();
  final totalAmount = list.fold(0.0, (s, d) => s + d.donationAmount);
  final totalFee    = list.fold(0.0, (s, d) => s + d.platformFee);

  final Map<String, CampaignBreakdown> map = {};
  for (final d in list) {
    final key = d.campaign;
    if (map.containsKey(key)) {
      map[key]!.total += d.donationAmount;
      map[key]!.count += 1;
    } else {
      map[key] = CampaignBreakdown(name: key, total: d.donationAmount, count: 1);
    }
  }
  final breakdown = map.values.toList()..sort((a, b) => b.total.compareTo(a.total));

  return DonationMetrics(
    totalDonations: list.length,
    totalAmount: totalAmount,
    totalPlatformFee: totalFee,
    averageDonation: totalAmount / list.length,
    campaignBreakdown: breakdown,
    topCampaigns: breakdown.take(5).toList(),
  );
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen>
    with TickerProviderStateMixin {
  List<Donation> _donations = [];
  bool _loading = true;
  String? _error;

  String _campaignFilter = 'all';
  double _minAmount = 0;

  DonationMetrics _metrics = DonationMetrics();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetch();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }
Future<void> _fetch() async {
  setState(() { _loading = true; _error = null; });
  try {
    final auth = context.read<AuthProvider>();
    // Sync AuthStore so DonationService can use it
    AuthStore.token     = auth.token;
    AuthStore.userId    = auth.user?.id;
    AuthStore.userEmail = auth.user?.email;
    AuthStore.userName  = auth.user?.username;
    AuthStore.userPhone = auth.user?.phoneNumber;

    final donations = await DonationService.fetchUserDonations();
    setState(() {
      _donations = donations;
      _metrics = _calcMetrics(donations);
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);
  } catch (e) {
    setState(() { _error = e.toString(); _loading = false; });
  }
}
  List<Donation> get _filtered {
    return _donations.where((d) {
      final passAmount = d.donationAmount >= _minAmount;
      final passCampaign = _campaignFilter == 'all' || d.campaign == _campaignFilter;
      return passAmount && passCampaign;
    }).toList();
  }

  Future<void> _export() async {
    final list = _filtered;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }
    final lines = ['Reference,Date,Amount,Campaign,Status,Platform Fee'];
    for (final d in list) {
      lines.add(
        '${d.paymentReference ?? ""},'
        '${_date(d.createdAt)},'
        '${d.donationAmount},'
        '"${d.campaign}",'
        '${d.paymentStatus ?? "Unknown"},'
        '${d.platformFee}',
      );
    }
    final csv = lines.join('\n');
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/my_donations_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'My Donations Export');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
    }
  }

 @override
Widget build(BuildContext context) {
  final auth = context.watch<AuthProvider>();
  if (!auth.isAuthenticated) return const _NotAuthScreen();
  if (_loading) return const _LoadingScreen();
  if (_error != null) return _ErrorScreen(error: _error!, onRetry: _fetch);

  final filtered = _filtered;
  final userName = auth.user?.username ?? auth.user?.fullName ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              // ── HEADER ──
              SliverToBoxAdapter(child: _Header(userName: userName, onRefresh: _fetch)),

              // ── STAT CARDS ──
              SliverToBoxAdapter(
                child: _loading
                    ? const _SectionLoader()
                    : _MetricsGrid(metrics: _metrics),
              ),

              // ── FILTERS ──
              SliverToBoxAdapter(
                child: _FilterBar(
                  campaignFilter: _campaignFilter,
                  minAmount: _minAmount,
                  campaigns: _metrics.campaignBreakdown.map((c) => c.name).toList(),
                  onCampaignChanged: (v) => setState(() => _campaignFilter = v),
                  onMinAmountChanged: (v) => setState(() => _minAmount = v),
                  onRefresh: _fetch,
                  onExport: _export,
                ),
              ),

              // ── RECENT DONATIONS TABLE ──
              SliverToBoxAdapter(
                child: _SectionCard(
                  title: 'Recent Donations',
                  child: filtered.isEmpty
                      ? const _EmptyRow(message: 'No donations matching criteria.')
                      : _DonationsTable(donations: filtered.take(10).toList()),
                ),
              ),

              // ── BAR CHART ──
              SliverToBoxAdapter(
                child: _SectionCard(
                  title: 'Campaign Breakdown',
                  child: _metrics.campaignBreakdown.isEmpty
                      ? const _EmptyRow(message: 'No campaign data available.')
                      : _CampaignChart(data: _metrics.campaignBreakdown),
                ),
              ),

              // ── TOP CAMPAIGNS ──
              SliverToBoxAdapter(
                child: _SectionCard(
                  title: 'Top Campaigns (Your Contributions)',
                  child: _metrics.topCampaigns.isEmpty
                      ? const _EmptyRow(message: 'No campaign data found.')
                      : _TopCampaignsTable(campaigns: _metrics.topCampaigns),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String userName;
  final VoidCallback onRefresh;
  const _Header({required this.userName, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Donation Dashboard',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Hello, $userName! Here\'s your contribution summary.',
                  style: const TextStyle(fontSize: 13, color: AppColors.mist),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.midGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, color: AppColors.midGreen, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final DonationMetrics metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricData(icon: Icons.favorite_rounded,       label: 'Total Donations',  value: metrics.totalDonations.toString(),       sub: 'Number of donations',      grad: [AppColors.midGreen, AppColors.forestGreen]),
      _MetricData(icon: Icons.trending_up_rounded,    label: 'Total Amount',     value: _kes(metrics.totalAmount, compact: true), sub: 'Total donated',            grad: [AppColors.limeGreen, AppColors.midGreen]),
      _MetricData(icon: Icons.bar_chart_rounded,      label: 'Average Donation', value: _kes(metrics.averageDonation, compact: true), sub: 'Per donation',         grad: [AppColors.savanna, AppColors.amber]),
      _MetricData(icon: Icons.receipt_long_rounded,   label: 'Platform Fees',    value: _kes(metrics.totalPlatformFee, compact: true), sub: 'Total fees paid',     grad: [AppColors.forestGreen, AppColors.darkBg]),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        children: cards.map((c) => _MetricCard(data: c)).toList(),
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final List<Color> grad;
  const _MetricData({required this.icon, required this.label, required this.value, required this.sub, required this.grad});
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: data.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: AppColors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.mist, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(data.sub, style: const TextStyle(fontSize: 10, color: AppColors.mist)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String campaignFilter;
  final double minAmount;
  final List<String> campaigns;
  final ValueChanged<String> onCampaignChanged;
  final ValueChanged<double> onMinAmountChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  const _FilterBar({
    required this.campaignFilter,
    required this.minAmount,
    required this.campaigns,
    required this.onCampaignChanged,
    required this.onMinAmountChanged,
    required this.onRefresh,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(
        children: [
          // Campaign dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.snow, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: campaigns.contains(campaignFilter) || campaignFilter == 'all' ? campaignFilter : 'all',
                isExpanded: true,
                style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mist, size: 18),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Campaigns')),
                  ...campaigns.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) { if (v != null) onCampaignChanged(v); },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Min amount + buttons
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Min Amount',
                    hintStyle: TextStyle(color: AppColors.mist, fontSize: 13),
                    prefixText: 'KES ',
                    prefixStyle: const TextStyle(color: AppColors.mist, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.snow,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => onMinAmountChanged(double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 10),
              _IconBtn(icon: Icons.refresh_rounded, label: 'Refresh', onTap: onRefresh, outlined: true),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.download_rounded, label: 'Export', onTap: onExport, outlined: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _IconBtn({required this.icon, required this.label, required this.onTap, required this.outlined});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: outlined ? AppColors.snow : AppColors.midGreen,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: AppColors.cloud) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: outlined ? AppColors.ink : AppColors.white),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: outlined ? AppColors.ink : AppColors.white)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DonationsTable extends StatelessWidget {
  final List<Donation> donations;
  const _DonationsTable({required this.donations});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 16,
        headingTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mist,
        ),
        dataTextStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
        columns: const [
          DataColumn(label: Text('REFERENCE')),
          DataColumn(label: Text('DATE')),
          DataColumn(label: Text('AMOUNT')),
          DataColumn(label: Text('CAMPAIGN')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('FEE')),
        ],
        rows: donations.map((d) => DataRow(cells: [
          DataCell(SizedBox(
            width: 90,
            child: Text(d.paymentReference ?? 'N/A', overflow: TextOverflow.ellipsis),
          )),
          DataCell(Text(_date(d.createdAt), style: const TextStyle(fontSize: 11))),
          DataCell(Text(_kes(d.donationAmount))),
          DataCell(SizedBox(
            width: 110,
            child: Text(d.campaign, overflow: TextOverflow.ellipsis),
          )),
          DataCell(_StatusBadge(status: d.paymentStatus ?? 'Unknown')),
          DataCell(Text(_kes(d.platformFee))),
        ])).toList(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _bg {
    switch (status.toLowerCase()) {
      case 'completed': return AppColors.limeGreen.withOpacity(0.12);
      case 'pending':   return AppColors.savanna.withOpacity(0.12);
      case 'failed':    return AppColors.crimson.withOpacity(0.10);
      default:          return AppColors.cloud;
    }
  }

  Color get _fg {
    switch (status.toLowerCase()) {
      case 'completed': return AppColors.forestGreen;
      case 'pending':   return AppColors.amber;
      case 'failed':    return AppColors.crimson;
      default:          return AppColors.mist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fg),
      ),
    );
  }
}

class _CampaignChart extends StatelessWidget {
  final List<CampaignBreakdown> data;
  const _CampaignChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                //tooltipBgColor: AppColors.ink.withOpacity(0.85),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final name = data[group.x].name;
                  return BarTooltipItem(
                    '$name\n${_kes(rod.toY)}',
                    const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i >= data.length) return const SizedBox();
                    final label = data[i].name;
                    final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(short, style: const TextStyle(fontSize: 9, color: AppColors.mist)),
                    );
                  },
                  reservedSize: 32,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) => Text(
                    _kes(value, compact: true),
                    style: const TextStyle(fontSize: 9, color: AppColors.mist),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cloud, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].total,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: const LinearGradient(
                      colors: [AppColors.limeGreen, AppColors.midGreen],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TopCampaignsTable extends StatelessWidget {
  final List<CampaignBreakdown> campaigns;
  const _TopCampaignsTable({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Header row
          Row(
            children: const [
              Expanded(flex: 3, child: Text('Campaign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mist))),
              Expanded(flex: 2, child: Text('Total Donated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mist))),
              SizedBox(width: 70, child: Text('Count', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mist))),
            ],
          ),
          const Divider(color: AppColors.cloud, height: 16),
          ...campaigns.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < campaigns.length - 1
                    ? const Border(bottom: BorderSide(color: AppColors.cloud, width: 0.5))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: i == 0
                                  ? [AppColors.savanna, AppColors.amber]
                                  : i == 1
                                      ? [AppColors.mist, AppColors.darkMist]
                                      : [AppColors.limeGreen, AppColors.midGreen],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${i+1}',
                            style: const TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_kes(c.total),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.midGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${c.count}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.midGreen),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.mist, fontSize: 13)),
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 2.5),
      ),
    );
  }
}

// ── AUTH / LOADING / ERROR SCREENS ────────────
class _NotAuthScreen extends StatelessWidget {
  const _NotAuthScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Authentication Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please log in to view your donation dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mist, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midGreen,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Go to Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading your donations...',
              style: TextStyle(color: AppColors.mist, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error, style: const TextStyle(color: AppColors.crimson, fontSize: 12)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}