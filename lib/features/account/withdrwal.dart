import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/network/auth_service.dart';

// ─────────────────────────────────────────────
//  APP COLORS
// ─────────────────────────────────────────────
class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen = Color(0xFF1A8C52);
  static const limeGreen = Color(0xFF4CC97A);
  static const savanna = Color(0xFFE8A020);
  static const crimson = Color(0xFFD93025);
  static const amber = Color(0xFFE8860A);
  static const ink = Color(0xFF0D0D0D);
  static const cloud = Color(0xFFEEEEEE);
  static const snow = Color(0xFFF4F6F4);
  static const white = Color(0xFFFFFFFF);
  static const darkBg = Color(0xFF060E09);
  static const darkMist = Color(0xFF4D6657);
  static const mist = Color(0xFF8FA896);
}

// ─────────────────────────────────────────────
//  AUTH STORE  (replace with your provider)
// ─────────────────────────────────────────────
class AuthStore {
  static String? token;
  static String? userId;
  static bool get isAuthenticated => token != null && token!.isNotEmpty;
}

// ─────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────
const double kMinWithdrawal = 100.0;
const int kPerPage = 5;

// ─────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────
class Campaign {
  final String id;
  final String title;
  final double amountRaised;
  final String creatorId;

  Campaign({
    required this.id,
    required this.title,
    required this.amountRaised,
    required this.creatorId,
  });

  factory Campaign.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final creator = j['creator_Id'];
    final creatorId = creator is Map
        ? creator['_id']?.toString() ?? ''
        : creator?.toString() ?? '';
    return Campaign(
      id: j['_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      amountRaised: _d(j['amountRaised']),
      creatorId: creatorId,
    );
  }
}

class BankDetails {
  final String bankName;
  final String accountNumber;
  final String accountName;
  BankDetails(
      {required this.bankName,
      required this.accountNumber,
      required this.accountName});
  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName
      };
}

class Withdrawal {
  final String id;
  final double amount;
  final String method; // 'mobile' | 'bank'
  final String status; // 'pending' | 'completed' | 'failed'
  final String requestedAt;
  final String? mobileNumber;
  final BankDetails? bankDetails;

  Withdrawal({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.requestedAt,
    this.mobileNumber,
    this.bankDetails,
  });

  factory Withdrawal.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    BankDetails? bank;
    if (j['bankDetails'] is Map) {
      final b = j['bankDetails'] as Map<String, dynamic>;
      bank = BankDetails(
        bankName: b['bankName']?.toString() ?? '',
        accountNumber: b['accountNumber']?.toString() ?? '',
        accountName: b['accountName']?.toString() ?? '',
      );
    }
    return Withdrawal(
      id: j['_id']?.toString() ?? DateTime.now().toIso8601String(),
      amount: _d(j['amount']),
      method: j['method']?.toString() ?? 'mobile',
      status: j['status']?.toString() ?? 'pending',
      requestedAt:
          j['requestedAt']?.toString() ?? DateTime.now().toIso8601String(),
      mobileNumber: j['mobileNumber']?.toString(),
      bankDetails: bank,
    );
  }
}

// ─────────────────────────────────────────────
//  API SERVICE
// ─────────────────────────────────────────────
class WithdrawalService {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthStore.token != null)
          'Authorization': 'Bearer ${AuthStore.token}',
      };

  static Future<Campaign> fetchCampaign(String id) async {
    final res =
        await http.get(Uri.parse('$_base/campaigns/$id'), headers: _headers);
    _checkStatus(res);
    final body = json.decode(res.body);

    // Handle different API response shapes
    Map<String, dynamic>? campaignData;

    if (body['status'] == 'success' || body['success'] == true) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        // Could be { data: { campaign: {...} } } or { data: {...} }
        campaignData = (data['campaign'] as Map<String, dynamic>?) ?? data;
      } else if (data is List && data.isNotEmpty) {
        campaignData = data[0] as Map<String, dynamic>;
      }
    }

    // Some APIs return the campaign directly at root
    if (campaignData == null && body['_id'] != null) {
      campaignData = body as Map<String, dynamic>;
    }

    if (campaignData != null) return Campaign.fromJson(campaignData);
    throw Exception(body['message'] ?? 'Failed to fetch campaign');
  }

  static Future<List<Withdrawal>> fetchWithdrawals(String campaignId) async {
    final res = await http.get(
      Uri.parse('$_base/campaigns/$campaignId/withdrawals'),
      headers: _headers,
    );
    _checkStatus(res);
    final body = json.decode(res.body);
    if (body['status'] == 'success') {
      final list = body['data']?['withdrawals'] as List? ?? [];
      final withdrawals = list.map((e) => Withdrawal.fromJson(e)).toList();
      withdrawals.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return withdrawals;
    }
    return [];
  }

  static Future<Withdrawal> submitWithdrawal({
    required String campaignId,
    required double amount,
    required String method,
    String? mobileNumber,
    BankDetails? bankDetails,
  }) async {
    final payload = <String, dynamic>{
      'campaignId': campaignId,
      'amount': amount,
      'method': method,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
      if (bankDetails != null) 'bankDetails': bankDetails.toJson(),
    };
    final res = await http.post(
      Uri.parse('$_base/campaigns/withdrawals'),
      headers: _headers,
      body: json.encode(payload),
    );
    _checkStatus(res);
    final body = json.decode(res.body);
    if ((res.statusCode == 200 || res.statusCode == 201) &&
        body['status'] == 'success') {
      final w = body['data']?['withdrawal'];
      if (w != null) return Withdrawal.fromJson(w);
      // Construct a local pending withdrawal if API doesn't return one
      return Withdrawal(
        id: DateTime.now().toIso8601String(),
        amount: amount,
        method: method,
        status: 'pending',
        requestedAt: DateTime.now().toIso8601String(),
        mobileNumber: mobileNumber,
        bankDetails: bankDetails,
      );
    }
    throw Exception(body['message'] ?? 'Failed to submit withdrawal');
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode == 401)
      throw Exception('Your session has expired. Please log in again.');
    if (res.statusCode == 403)
      throw Exception("You don't have permission for this campaign.");
    if (res.statusCode == 404) throw Exception('Campaign not found.');
    if (res.statusCode >= 400) {
      final body = json.decode(res.body);
      throw Exception(body['message'] ?? 'Server error ${res.statusCode}');
    }
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _kes(double v) =>
    'KES ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

String _date(String iso) {
  try {
    final d = DateTime.parse(iso);
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso;
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class WithdrawalScreen extends StatefulWidget {
  final String campaignId;
  const WithdrawalScreen({super.key, required this.campaignId});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen>
    with TickerProviderStateMixin {
  // ── Data state ──
  Campaign? _campaign;
  bool _loading = true;
  String? _error;
  bool _isCampaignOwner = false;

  List<Withdrawal> _withdrawals = [];
  bool _loadingHistory = true;
  String? _historyError;

  // ── Form state ──
  final _amountCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();

  String _method = ''; // 'mobile' | 'bank' | ''
  bool _submitting = false;
  String? _successMsg;
  String? _errorMsg;

  // ── Pagination ──
  int _page = 1;

  // ── Animation ──
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        context.go('/login');
      } else {
        // Sync AuthStore
        AuthStore.token = auth.token;
        AuthStore.userId = auth.user?.id;
        _init();
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _amountCtrl.dispose();
    _mobileCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNumCtrl.dispose();
    _accNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchCampaign();
  }

  Future<void> _fetchCampaign() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await WithdrawalService.fetchCampaign(widget.campaignId);
      final isOwner = c.creatorId.isNotEmpty &&
          AuthStore.userId != null &&
          c.creatorId == AuthStore.userId;
      setState(() {
        _campaign = c;
        _isCampaignOwner = isOwner;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
      if (isOwner) _fetchHistory();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final list = await WithdrawalService.fetchWithdrawals(widget.campaignId);
      setState(() {
        _withdrawals = list;
        _loadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _loadingHistory = false;
      });
    }
  }

  double get _totalWithdrawn => _withdrawals
      .where((w) => w.status == 'completed')
      .fold(0.0, (s, w) => s + w.amount);

  double get _withdrawableBalance => _campaign != null
      ? (_campaign!.amountRaised - _totalWithdrawn).clamp(0, double.infinity)
      : 0.0;

  List<Withdrawal> get _paginated {
    final start = (_page - 1) * kPerPage;
    return _withdrawals.sublist(start.clamp(0, _withdrawals.length),
        (start + kPerPage).clamp(0, _withdrawals.length));
  }

  int get _totalPages => (_withdrawals.length / kPerPage).ceil().clamp(1, 9999);

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    // ── Validation ──
    if (amount <= 0) {
      _showError('Please enter a valid withdrawal amount.');
      return;
    }
    if (amount < kMinWithdrawal) {
      _showError('Minimum withdrawal is ${_kes(kMinWithdrawal)}.');
      return;
    }
    if (amount > _withdrawableBalance) {
      _showError(
          'Amount exceeds available balance (${_kes(_withdrawableBalance)}).');
      return;
    }
    if (_method.isEmpty) {
      _showError('Please select a withdrawal method.');
      return;
    }
    if (_method == 'mobile') {
      final phone = _mobileCtrl.text.trim();
      if (!RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
        _showError('Enter a valid 10-digit mobile number starting with 0.');
        return;
      }
    }
    if (_method == 'bank') {
      if (_bankNameCtrl.text.trim().isEmpty ||
          _accNumCtrl.text.trim().isEmpty ||
          _accNameCtrl.text.trim().isEmpty) {
        _showError('Please fill in all bank details.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _successMsg = null;
      _errorMsg = null;
    });
    try {
      final newW = await WithdrawalService.submitWithdrawal(
        campaignId: widget.campaignId,
        amount: amount,
        method: _method,
        mobileNumber: _method == 'mobile' ? _mobileCtrl.text.trim() : null,
        bankDetails: _method == 'bank'
            ? BankDetails(
                bankName: _bankNameCtrl.text.trim(),
                accountNumber: _accNumCtrl.text.trim(),
                accountName: _accNameCtrl.text.trim(),
              )
            : null,
      );

      setState(() {
        _withdrawals = [newW, ..._withdrawals]
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        _successMsg =
            'Withdrawal request submitted! You will be notified once processed.';
        _submitting = false;
      });
      _clearForm();
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _successMsg = null);
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _submitting = false;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _errorMsg = null);
      });
    }
  }

  void _clearForm() {
    _amountCtrl.clear();
    _mobileCtrl.clear();
    _bankNameCtrl.clear();
    _accNumCtrl.clear();
    _accNameCtrl.clear();
    setState(() => _method = '');
  }

  void _showError(String msg) {
    setState(() => _errorMsg = msg);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMsg = null);
    });
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated)
      return const _LoadingScreen(message: 'Verifying authentication...');
    if (_loading)
      return const _LoadingScreen(message: 'Loading withdrawal page...');
    if (_error != null || _campaign == null) {
      return _ErrorScreen(
          error: _error ?? 'Campaign not found.', onBack: () => context.pop());
    }
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              // ── BACK + TITLE ──
              SliverToBoxAdapter(
                  child: _PageHeader(
                title: _campaign!.title,
                onBack: () => context.pop(),
              )),

              // ── CAMPAIGN RAISED CARD ──
              SliverToBoxAdapter(child: _RaisedCard(campaign: _campaign!)),

              // ── BALANCE CARDS ──
              SliverToBoxAdapter(
                  child: _BalanceRow(
                available: _withdrawableBalance,
                withdrawn: _totalWithdrawn,
              )),

              // ── FEEDBACK BANNERS ──
              if (_successMsg != null)
                SliverToBoxAdapter(
                    child: _Banner(message: _successMsg!, isError: false)),
              if (_errorMsg != null)
                SliverToBoxAdapter(
                    child: _Banner(message: _errorMsg!, isError: true)),

              // ── WITHDRAWAL FORM ──
              SliverToBoxAdapter(
                  child: _WithdrawalForm(
                amountCtrl: _amountCtrl,
                mobileCtrl: _mobileCtrl,
                bankNameCtrl: _bankNameCtrl,
                accNumCtrl: _accNumCtrl,
                accNameCtrl: _accNameCtrl,
                method: _method,
                onMethodChanged: (v) => setState(() => _method = v),
                onSubmit: _submit,
                submitting: _submitting,
                enabled: _isCampaignOwner && _withdrawableBalance > 0,
                withdrawableBalance: _withdrawableBalance,
                minWithdrawal: kMinWithdrawal,
              )),

              // ── HISTORY HEADER ──
              SliverToBoxAdapter(child: _HistoryHeader()),

              // ── HISTORY CONTENT ──
              SliverToBoxAdapter(
                  child: _loadingHistory
                      ? const _SectionLoader()
                      : _historyError != null
                          ? _Banner(message: _historyError!, isError: true)
                          : _withdrawals.isEmpty
                              ? const _EmptyHistory()
                              : _HistorySection(
                                  withdrawals: _paginated,
                                  page: _page,
                                  totalPages: _totalPages,
                                  onPageChanged: (p) =>
                                      setState(() => _page = p),
                                )),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.midGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.midGreen, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Withdraw Funds',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.mist),
              children: [
                const TextSpan(text: 'From campaign: '),
                TextSpan(
                  text: '"$title"',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaisedCard extends StatelessWidget {
  final Campaign campaign;
  const _RaisedCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 12)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.midGreen, AppColors.forestGreen]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Raised',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mist,
                      fontWeight: FontWeight.w500)),
              Text(
                _kes(campaign.amountRaised),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final double available;
  final double withdrawn;
  const _BalanceRow({required this.available, required this.withdrawn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
              child: _BalanceCard(
            icon: Icons.trending_up_rounded,
            label: 'Available Balance',
            value: _kes(available),
            iconColor: AppColors.midGreen,
            bgColor: AppColors.limeGreen.withOpacity(0.1),
            borderColor: AppColors.limeGreen.withOpacity(0.3),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _BalanceCard(
            icon: Icons.payments_rounded,
            label: 'Total Withdrawn',
            value: _kes(withdrawn),
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFF2563EB).withOpacity(0.07),
            borderColor: const Color(0xFF2563EB).withOpacity(0.2),
          )),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: iconColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.crimson.withOpacity(0.07)
            : AppColors.limeGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isError ? AppColors.crimson : AppColors.midGreen,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.cancel_rounded : Icons.check_circle_rounded,
            color: isError ? AppColors.crimson : AppColors.midGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError ? AppColors.crimson : AppColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WITHDRAWAL FORM
// ─────────────────────────────────────────────
class _WithdrawalForm extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController accNumCtrl;
  final TextEditingController accNameCtrl;
  final String method;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSubmit;
  final bool submitting;
  final bool enabled;
  final double withdrawableBalance;
  final double minWithdrawal;

  const _WithdrawalForm({
    required this.amountCtrl,
    required this.mobileCtrl,
    required this.bankNameCtrl,
    required this.accNumCtrl,
    required this.accNameCtrl,
    required this.method,
    required this.onMethodChanged,
    required this.onSubmit,
    required this.submitting,
    required this.enabled,
    required this.withdrawableBalance,
    required this.minWithdrawal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Amount ──
          _FieldLabel(
              icon: Icons.wallet_rounded, text: 'Withdrawal Amount (KES)'),
          const SizedBox(height: 4),
          Text(
            'Minimum: ${_kes(minWithdrawal)}',
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.mist,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            enabled: enabled && !submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
            decoration: _inputDeco('e.g. 5000', prefix: 'KES '),
          ),

          const SizedBox(height: 20),

          // ── Method ──
          _FieldLabel(
              icon: Icons.compare_arrows_rounded,
              text: 'Choose Withdrawal Method'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _MethodCard(
                icon: Icons.smartphone_rounded,
                label: 'Mobile Money',
                selected: method == 'mobile',
                iconBgColor: AppColors.midGreen,
                enabled: enabled && !submitting,
                onTap: () => onMethodChanged('mobile'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _MethodCard(
                icon: Icons.account_balance_rounded,
                label: 'Bank Transfer',
                selected: method == 'bank',
                iconBgColor: const Color(0xFF2563EB),
                enabled: enabled && !submitting,
                onTap: () => onMethodChanged('bank'),
              )),
            ],
          ),

          // ── Mobile fields ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: method == 'mobile' && enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(
                            icon: Icons.phone_android_rounded,
                            text: 'Mobile Number'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: mobileCtrl,
                          enabled: !submitting,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.ink),
                          decoration: _inputDeco('e.g. 0712345678'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Bank fields ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: method == 'bank' && enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(
                            icon: Icons.account_balance_rounded,
                            text: 'Bank Name'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: bankNameCtrl,
                          enabled: !submitting,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.ink),
                          decoration: _inputDeco('e.g. Equity Bank'),
                        ),
                        const SizedBox(height: 14),
                        _FieldLabel(
                            icon: Icons.numbers_rounded,
                            text: 'Account Number'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: accNumCtrl,
                          enabled: !submitting,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.ink),
                          decoration: _inputDeco('e.g. 1234567890'),
                        ),
                        const SizedBox(height: 14),
                        _FieldLabel(
                            icon: Icons.person_rounded, text: 'Account Name'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: accNameCtrl,
                          enabled: !submitting,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.ink),
                          decoration: _inputDeco('e.g. John Doe'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // ── Submit button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (enabled && !submitting) ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.midGreen,
                disabledBackgroundColor: AppColors.mist.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Processing...',
                            style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wallet_rounded,
                            color: AppColors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Withdraw Funds',
                            style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    ),
            ),
          ),

          if (!enabled && withdrawableBalance <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.mist),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No available balance to withdraw.',
                      style: TextStyle(fontSize: 12, color: AppColors.mist),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mist, fontSize: 13),
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: AppColors.mist, fontSize: 14, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: AppColors.snow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.midGreen, width: 1.5),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FieldLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.mist),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color iconBgColor;
  final bool enabled;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.iconBgColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.midGreen : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.midGreen : AppColors.cloud,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.midGreen.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [
                  BoxShadow(
                      color: AppColors.ink.withOpacity(0.04), blurRadius: 6)
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.white.withOpacity(0.2)
                    : iconBgColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: selected ? AppColors.white : iconBgColor, size: 22),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.cloud, height: 1),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WITHDRAWAL HISTORY
// ─────────────────────────────────────────────
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: const [
          Icon(Icons.history_rounded, color: AppColors.forestGreen, size: 22),
          SizedBox(width: 8),
          Text(
            'Withdrawal History',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: const [
          Icon(Icons.savings_rounded, size: 48, color: AppColors.cloud),
          SizedBox(height: 12),
          Text(
            'No past withdrawals for this campaign.',
            style: TextStyle(fontSize: 13, color: AppColors.mist),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<Withdrawal> withdrawals;
  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _HistorySection({
    required this.withdrawals,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Table header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: _TH('AMOUNT')),
                Expanded(flex: 2, child: _TH('METHOD')),
                Expanded(flex: 2, child: _TH('STATUS')),
                Expanded(flex: 2, child: _TH('DATE')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cloud),

          // ── Rows ──
          ...withdrawals.asMap().entries.map((e) {
            final i = e.key;
            final w = e.value;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(
                            _kes(w.amount),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink),
                          )),
                      Expanded(
                          flex: 2,
                          child: Text(
                            w.method == 'mobile'
                                ? 'Mobile Money'
                                : 'Bank Transfer',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.ink),
                          )),
                      Expanded(flex: 2, child: _StatusBadge(status: w.status)),
                      Expanded(
                          flex: 2,
                          child: Text(
                            _date(w.requestedAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.mist),
                          )),
                    ],
                  ),
                ),
                if (i < withdrawals.length - 1)
                  const Divider(
                      height: 1,
                      color: AppColors.cloud,
                      indent: 16,
                      endIndent: 16),
              ],
            );
          }),

          // ── Pagination ──
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PagBtn(
                    icon: Icons.chevron_left_rounded,
                    enabled: page > 1,
                    onTap: () => onPageChanged(page - 1),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                      totalPages,
                      (i) => _PageNumBtn(
                            num: i + 1,
                            selected: page == i + 1,
                            onTap: () => onPageChanged(i + 1),
                          )),
                  const SizedBox(width: 8),
                  _PagBtn(
                    icon: Icons.chevron_right_rounded,
                    enabled: page < totalPages,
                    onTap: () => onPageChanged(page + 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.mist,
          letterSpacing: 0.5));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _bg {
    switch (status) {
      case 'completed':
        return AppColors.limeGreen.withOpacity(0.12);
      case 'pending':
        return AppColors.savanna.withOpacity(0.12);
      case 'failed':
        return AppColors.crimson.withOpacity(0.1);
      default:
        return AppColors.cloud;
    }
  }

  Color get _fg {
    switch (status) {
      case 'completed':
        return AppColors.forestGreen;
      case 'pending':
        return AppColors.amber;
      case 'failed':
        return AppColors.crimson;
      default:
        return AppColors.mist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fg),
      ),
    );
  }
}

class _PagBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PagBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:
              enabled ? AppColors.midGreen.withOpacity(0.1) : AppColors.cloud,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? AppColors.midGreen : AppColors.mist),
      ),
    );
  }
}

class _PageNumBtn extends StatelessWidget {
  final int num;
  final bool selected;
  final VoidCallback onTap;
  const _PageNumBtn(
      {required this.num, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.midGreen : AppColors.cloud,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$num',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.midGreen, strokeWidth: 2.5)),
      );
}

// ─────────────────────────────────────────────
//  LOADING / ERROR SCREENS
// ─────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  final String message;
  const _LoadingScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.midGreen, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    color: AppColors.mist,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onBack;
  const _ErrorScreen({required this.error, required this.onBack});

  bool get _isAuth =>
      error.toLowerCase().contains('auth') ||
      error.toLowerCase().contains('session') ||
      error.toLowerCase().contains('log in');

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
              Icon(
                _isAuth ? Icons.lock_rounded : Icons.warning_amber_rounded,
                size: 64,
                color: _isAuth ? AppColors.savanna : AppColors.crimson,
              ),
              const SizedBox(height: 16),
              Text(
                _isAuth ? 'Authentication Required' : 'Something went wrong',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isAuth ? AppColors.savanna : AppColors.crimson)
                      .withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error,
                    style: TextStyle(
                        color: _isAuth ? AppColors.amber : AppColors.crimson,
                        fontSize: 12)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isAuth ? () => context.go('/login') : onBack,
                icon: Icon(
                    _isAuth ? Icons.login_rounded : Icons.arrow_back_rounded),
                label: Text(_isAuth ? 'Go to Login' : 'Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midGreen,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
