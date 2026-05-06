import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';
import '../../core/network/auth_service.dart';

// ─────────────────────────────────────────────
//  APP COLORS
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
//  MODELS
// ─────────────────────────────────────────────
class Campaign {
  final String id;
  final String title;
  final String description;
  final double goal;
  final double amountRaised;
  final String category;
  final String status;
  final String approvalStatus;
  final String createdAt;
  final String? reviewNotes;
  final String? imageUrl;
  final String? userId;
  final String? username;
  final String? contactEmail;
  final String? creatorEmail;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.amountRaised,
    required this.category,
    required this.status,
    required this.approvalStatus,
    required this.createdAt,
    this.reviewNotes,
    this.imageUrl,
    this.userId,
    this.username,
    this.contactEmail,
    this.creatorEmail,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String? extractCreatorId(dynamic creatorId) {
      if (creatorId == null) return null;
      if (creatorId is String) return creatorId;
      if (creatorId is Map) return creatorId['_id']?.toString();
      return null;
    }

    return Campaign(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      goal: parseDouble(json['goal']),
      amountRaised: parseDouble(json['amountRaised']),
      category: json['category']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      approvalStatus: json['approvalStatus']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString() ?? '',
      reviewNotes: json['reviewNotes']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      userId: extractCreatorId(json['creator_Id']) ?? json['userId']?.toString(),
      username: json['username']?.toString(),
      contactEmail: json['contactEmail']?.toString(),
      creatorEmail: json['creatorEmail']?.toString(),
    );
  }

  double get progressPercentage => goal > 0 ? (amountRaised / goal * 100).clamp(0, 100) : 0;
}

// ─────────────────────────────────────────────
//  SIMPLE AUTH STORE  (replace with your provider)
// ─────────────────────────────────────────────
class AuthStore {
  static String? token;
  static String? userId;
  static String? userEmail;
  static String? username;
  static bool get isAuthenticated => token != null && token!.isNotEmpty;
}

// ─────────────────────────────────────────────
//  API SERVICE
// ─────────────────────────────────────────────
class CampaignService {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<List<Campaign>> fetchAll() async {
    final res = await http.get(
      Uri.parse('$_base/campaigns'),
      headers: {
        'Authorization': 'Bearer ${AuthStore.token}',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      if (body['status'] == 'success') {
        return (body['data'] as List).map((e) => Campaign.fromJson(e)).toList();
      }
    }
    throw Exception('Failed to fetch campaigns (${res.statusCode})');
  }

  static Future<void> delete(String id) async {
    final res = await http.delete(
      Uri.parse('$_base/campaigns/$id'),
      headers: {
        'Authorization': 'Bearer ${AuthStore.token}',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      final body = json.decode(res.body);
      throw Exception(body['message'] ?? 'Failed to delete campaign');
    }
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _currency(double amount) {
  if (amount >= 1000000) {
    return 'KES ${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (amount >= 1000) {
    return 'KES ${(amount / 1000).toStringAsFixed(1)}K';
  }
  return 'KES ${amount.toStringAsFixed(0)}';
}

String _currencyFull(double amount) =>
    'KES ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

String _date(String iso) {
  try {
    final d = DateTime.parse(iso);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

bool _belongsToUser(Campaign c) {
  if (!AuthStore.isAuthenticated) return false;
  if (AuthStore.userId != null) {
    if (c.userId == AuthStore.userId) return true;
  }
  if (AuthStore.username != null && c.username == AuthStore.username) return true;
  if (AuthStore.userEmail != null) {
    if (c.contactEmail == AuthStore.userEmail || c.creatorEmail == AuthStore.userEmail) return true;
  }
  return false;
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});

  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen>
    with TickerProviderStateMixin {
  List<Campaign> _all = [];
  List<Campaign> _mine = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  String _approvalFilter = '';
  String _sortBy = 'newest';
  int _page = 1;
  final int _perPage = 10;

  String? _deleteSuccess;
  String? _deleteError;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

 Future<void> _fetch() async {
  setState(() { _loading = true; _error = null; });
  try {
    final auth = context.read<AuthProvider>();
    // Sync AuthStore so CampaignService can use it
    AuthStore.token     = auth.token;
    AuthStore.userId    = auth.user?.id;
    AuthStore.userEmail = auth.user?.email;
    AuthStore.username  = auth.user?.username;
    
    final campaigns = await CampaignService.fetchAll();
    final mine = campaigns.where(_belongsToUser).toList();
    setState(() { _all = campaigns; _mine = mine; _loading = false; });
    _fadeCtrl.forward(from: 0);
  } catch (e) {
    setState(() { _error = e.toString(); _loading = false; });
  }
}

  List<Campaign> get _filtered {
    var list = [..._mine];
    if (_approvalFilter.isNotEmpty) {
      list = list.where((c) => c.approvalStatus == _approvalFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) =>
        c.title.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.category.toLowerCase().contains(q),
      ).toList();
    }
    switch (_sortBy) {
      case 'oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'popular':
        list.sort((a, b) => b.amountRaised.compareTo(a.amountRaised));
        break;
      case 'goal:desc':
        list.sort((a, b) => b.goal.compareTo(a.goal));
        break;
      case 'goal:asc':
        list.sort((a, b) => a.goal.compareTo(b.goal));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  List<Campaign> get _paginated {
    final f = _filtered;
    final start = (_page - 1) * _perPage;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _perPage).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.length / _perPage).ceil().clamp(1, 9999);

  void _resetPage() => setState(() => _page = 1);

  Future<void> _confirmDelete(Campaign c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(campaign: c),
    );
    if (confirmed != true) return;

    try {
      await CampaignService.delete(c.id);
      setState(() {
        _deleteSuccess = '"${c.title}" deleted successfully.';
        _deleteError = null;
      });
      await _fetch();
    } catch (e) {
      setState(() {
        _deleteError = e.toString();
        _deleteSuccess = null;
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _deleteSuccess = null; _deleteError = null; });
    });
  }

  void _navigate(String action, Campaign c) {
    switch (action) {
      case 'View':
        context.push('/campaigns/${c.id}');
        break;
      case 'Edit':
        context.push('/campaigns/manage/${c.id}');
        break;
      case 'Withdraw':
        context.push('/profile/withdrawal/${c.id}');
        break;
      case 'Delete':
        _confirmDelete(c);
        break;
    }
  }

  // ── STATS ───────────────────────────────────
  double get _totalRaised => _mine.fold(0, (s, c) => s + c.amountRaised);
  int get _activeCount => _mine.where((c) => c.status == 'active').length;
  int get _approvedCount => _mine.where((c) => c.approvalStatus == 'approved').length;

 @override
Widget build(BuildContext context) {
  final auth = context.watch<AuthProvider>();
  if (!auth.isAuthenticated) return const _NotAuthScreen();
  if (_loading) return const _LoadingScreen();
  if (_error != null) return _ErrorScreen(error: _error!, onRetry: _fetch);
    final campaigns = _paginated;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              // ── APP BAR ──
              SliverToBoxAdapter(
                child: _Header(
                  onCreateTap: () => context.push('/start-campaign'),
                ),
              ),

              // ── NOTIFICATION BANNERS ──
              if (_deleteSuccess != null || _deleteError != null)
                SliverToBoxAdapter(
                  child: _Banner(
                    message: _deleteSuccess ?? _deleteError!,
                    isError: _deleteError != null,
                  ),
                ),

              // ── SEARCH + FILTERS ──
              SliverToBoxAdapter(
                child: _FilterBar(
                  search: _search,
                  approvalFilter: _approvalFilter,
                  sortBy: _sortBy,
                  onSearchChanged: (v) { setState(() => _search = v); _resetPage(); },
                  onApprovalChanged: (v) { setState(() => _approvalFilter = v); _resetPage(); },
                  onSortChanged: (v) { setState(() => _sortBy = v); _resetPage(); },
                ),
              ),

              // ── STATS ──
              SliverToBoxAdapter(
                child: _StatsRow(
                  total: _mine.length,
                  raised: _totalRaised,
                  active: _activeCount,
                  approved: _approvedCount,
                ),
              ),

              // ── CAMPAIGNS ──
              campaigns.isEmpty
                  ? SliverFillRemaining(
                      child: _EmptyState(
                        hasFilters: _search.isNotEmpty || _approvalFilter.isNotEmpty,
                        hasCampaigns: _mine.isNotEmpty,
                        onCreate: () => context.push('/start-campaign'),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CampaignCard(
                          campaign: campaigns[i],
                          onAction: (action) => _navigate(action, campaigns[i]),
                        ),
                        childCount: campaigns.length,
                      ),
                    ),

              // ── PAGINATION ──
              if (campaigns.isNotEmpty && _totalPages > 1)
                SliverToBoxAdapter(
                  child: _Pagination(
                    current: _page,
                    total: _totalPages,
                    onPrev: _page > 1 ? () => setState(() => _page--) : null,
                    onNext: _page < _totalPages ? () => setState(() => _page++) : null,
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
//  SUB-WIDGETS
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _Header({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Campaigns',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Track your fundraising journey',
                style: TextStyle(fontSize: 14, color: AppColors.mist),
              ),
            ],
          ),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.midGreen, AppColors.forestGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.midGreen.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, color: AppColors.white, size: 18),
                  SizedBox(width: 6),
                  Text('New', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? AppColors.crimson.withOpacity(0.08) : AppColors.limeGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppColors.crimson.withOpacity(0.25) : AppColors.limeGreen.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.crimson : AppColors.midGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? AppColors.crimson : AppColors.forestGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String search;
  final String approvalFilter;
  final String sortBy;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onApprovalChanged;
  final ValueChanged<String> onSortChanged;

  const _FilterBar({
    required this.search,
    required this.approvalFilter,
    required this.sortBy,
    required this.onSearchChanged,
    required this.onApprovalChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Search campaigns...',
              hintStyle: TextStyle(color: AppColors.mist, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mist, size: 20),
              filled: true,
              fillColor: AppColors.snow,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Dropdowns row
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: approvalFilter,
                  label: 'Approval',
                  items: const {
                    '': 'All Status',
                    'pending': 'Pending',
                    'approved': 'Approved',
                    'rejected': 'Rejected',
                  },
                  onChanged: onApprovalChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown(
                  value: sortBy,
                  label: 'Sort',
                  items: const {
                    'newest': 'Newest First',
                    'oldest': 'Oldest First',
                    'popular': 'Most Raised',
                    'goal:desc': 'Highest Goal',
                    'goal:asc': 'Lowest Goal',
                  },
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w500),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mist, size: 18),
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int total;
  final double raised;
  final int active;
  final int approved;

  const _StatsRow({
    required this.total,
    required this.raised,
    required this.active,
    required this.approved,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(icon: Icons.bar_chart_rounded,   label: 'Total',    value: total.toString(),      grad: [AppColors.midGreen, AppColors.forestGreen]),
      _StatItem(icon: Icons.attach_money_rounded, label: 'Raised',   value: _currency(raised),     grad: [AppColors.limeGreen, AppColors.midGreen]),
      _StatItem(icon: Icons.bolt_rounded,         label: 'Active',   value: active.toString(),     grad: [AppColors.savanna, AppColors.amber]),
      _StatItem(icon: Icons.verified_rounded,     label: 'Approved', value: approved.toString(),   grad: [AppColors.forestGreen, AppColors.darkBg]),
    ];

    return Container(
      height: 110,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: stats
            .map((s) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StatCard(item: s),
            )))
            .toList(),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> grad;
  const _StatItem({required this.icon, required this.label, required this.value, required this.grad});
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: item.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: AppColors.white, size: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(item.label,
                style: const TextStyle(fontSize: 10, color: AppColors.mist, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final void Function(String action) onAction;

  const _CampaignCard({required this.campaign, required this.onAction});

  Color _approvalColor(String s) {
    switch (s) {
      case 'approved': return AppColors.limeGreen;
      case 'rejected': return AppColors.crimson;
      default: return AppColors.savanna;
    }
  }

  Color _approvalBg(String s) {
    switch (s) {
      case 'approved': return AppColors.limeGreen.withOpacity(0.1);
      case 'rejected': return AppColors.crimson.withOpacity(0.08);
      default: return AppColors.savanna.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = campaign.progressPercentage;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.midGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(campaign.category,
                    style: const TextStyle(fontSize: 11, color: AppColors.midGreen, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                // Approval badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _approvalBg(campaign.approvalStatus),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _approvalColor(campaign.approvalStatus).withOpacity(0.3)),
                  ),
                  child: Text(
                    campaign.approvalStatus[0].toUpperCase() + campaign.approvalStatus.substring(1),
                    style: TextStyle(fontSize: 11, color: _approvalColor(campaign.approvalStatus), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── Title ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(campaign.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Progress bar ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_currency(campaign.amountRaised),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                    ),
                    Text('${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.mist, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.cloud,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 100 ? AppColors.savanna : AppColors.limeGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Goal: ${_currency(campaign.goal)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.mist),
                ),
              ],
            ),
          ),

          // ── Meta row ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.mist),
                const SizedBox(width: 4),
                Text(_date(campaign.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.mist),
                ),
              ],
            ),
          ),

          // ── Review notes ─────────────────────
          if (campaign.reviewNotes != null && campaign.approvalStatus == 'rejected')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.crimson.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.crimson, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Review Note: ${campaign.reviewNotes}',
                      style: const TextStyle(fontSize: 11, color: AppColors.crimson),
                    ),
                  ),
                ],
              ),
            ),

          // ── Action buttons ───────────────────
          const SizedBox(height: 12),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cloud)),
            ),
            child: Row(
              children: [
                _ActionBtn(icon: Icons.visibility_rounded,  label: 'View',     color: AppColors.midGreen,    onTap: () => onAction('View')),
                _ActionBtn(icon: Icons.edit_rounded,        label: 'Edit',     color: AppColors.savanna,     onTap: () => onAction('Edit')),
                _ActionBtn(icon: Icons.account_balance_wallet_rounded, label: 'Withdraw', color: AppColors.forestGreen, onTap: () => onAction('Withdraw')),
                _ActionBtn(icon: Icons.delete_outline_rounded, label: 'Delete', color: AppColors.crimson,   onTap: () => onAction('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Pagination({required this.current, required this.total, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PagBtn(icon: Icons.chevron_left_rounded, enabled: onPrev != null, onTap: onPrev),
          Text('Page $current of $total',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
          ),
          _PagBtn(icon: Icons.chevron_right_rounded, enabled: onNext != null, onTap: onNext),
        ],
      ),
    );
  }
}

class _PagBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PagBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? AppColors.midGreen.withOpacity(0.1) : AppColors.cloud,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
          color: enabled ? AppColors.midGreen : AppColors.mist,
          size: 20,
        ),
      ),
    );
  }
}

// ── DELETE DIALOG ─────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final Campaign campaign;
  const _DeleteDialog({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Delete Campaign',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: AppColors.mist, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: '"${campaign.title}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const TextSpan(text: '? This action cannot be undone.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.cloud),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                      style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Delete',
                      style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── LOADING / ERROR / NOT-AUTH screens ────────
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
            CircularProgressIndicator(
              color: AppColors.midGreen,
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text('Loading your campaigns...',
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
              const Text('Welcome Back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please log in to view your campaigns and continue your fundraising journey.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mist, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midGreen,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final bool hasCampaigns;
  final VoidCallback onCreate;

  const _EmptyState({required this.hasFilters, required this.hasCampaigns, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📝', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('No campaigns found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters or search terms.'
                  : !hasCampaigns
                      ? "You haven't created any campaigns yet."
                      : 'No campaigns match your current filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mist, fontSize: 14),
            ),
            if (!hasCampaigns) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Your First Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}