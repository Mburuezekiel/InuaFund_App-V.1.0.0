// ═══════════════════════════════════════════════════════════════════════════════
// profile_screen.dart
// Full ProfileScreen — reads user from AuthProvider (auth_service.dart)
// Matches InuaFund design language: Poppins, forest-green palette, dark mode
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../core/network/auth_service.dart'; // AuthProvider, UserModel, AppColors

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL COLOUR ALIASES (mirrors home_screen.dart AppColors)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const savanna     = Color(0xFFE8A020);
  static const crimson     = Color(0xFFD93025);
  static const amber       = Color(0xFFE8860A);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF7F7F7);
  static const white       = Color(0xFFFFFFFF);
  static const darkBg      = Color(0xFF060E09);
  static const darkCard    = Color(0xFF0D1A11);
  static const darkBorder  = Color(0xFF1C2E22);
  static const darkMist    = Color(0xFF4D6657);
  static const mist        = Color(0xFF8FA896);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE API (mirrors profileService.ts)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStats {
  final int donations;
  final int campaigns;
  final int impact;
  final int unreadMessages;
  const _ProfileStats({
    this.donations = 0, this.campaigns = 0,
    this.impact = 0, this.unreadMessages = 0,
  });
  factory _ProfileStats.fromJson(Map<String, dynamic> j) => _ProfileStats(
    donations:      (j['totalDonations'] as num?)?.toInt()   ?? 0,
    campaigns:      (j['campaignsSupported'] as num?)?.toInt() ?? 0,
    impact:         (j['impactScore'] as num?)?.toInt()       ?? 0,
    unreadMessages: (j['unreadMessages'] as num?)?.toInt()    ?? 0,
  );
}

class _Activity {
  final String type, description, date;
  const _Activity({required this.type, required this.description, required this.date});
  factory _Activity.fromJson(Map<String, dynamic> j) => _Activity(
    type:        j['type']?.toString()        ?? 'donation',
    description: j['description']?.toString() ?? '',
    date:        j['createdAt']?.toString()   ?? '',
  );
}

class _ProfileApi {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<Map<String, dynamic>> _get(String url, String token) async {
    final res = await http.get(Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<UserModel> fetchProfile(String token) async {
    final data = await _get('$_base/users/profile', token);
    return UserModel.fromJson({...data, 'token': token});
  }

  static Future<_ProfileStats> fetchStats(String token) async {
    try {
      final data = await _get('$_base/users/stats', token);
      return _ProfileStats.fromJson(data);
    } catch (_) { return const _ProfileStats(); }
  }

  static Future<List<_Activity>> fetchActivity(String token) async {
    try {
      final data = await _get('$_base/activity?limit=5', token);
      final list = (data['activities'] ?? data['data'] ?? []) as List;
      return list.map((e) => _Activity.fromJson(e)).toList();
    } catch (_) { return []; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final bool isDark;
  const ProfileScreen({super.key, this.isDark = false});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late bool _isDark;
  int _tab = 0; // 0=overview 1=activity 2=achievements 3=settings

  UserModel? _profile;
  _ProfileStats _stats = const _ProfileStats();
  List<_Activity> _activities = [];
  bool _loadingProfile = true;
  bool _loadingStats   = true;
  bool _loadingActivity = true;
  String? _error;

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final AnimationController _tabAnim;

  // ── theme helpers ──────────────────────────────────────────────────────────
  Color get bg      => _isDark ? _C.darkBg    : _C.snow;
  Color get surface => _isDark ? _C.darkCard  : _C.white;
  Color get border  => _isDark ? _C.darkBorder : _C.cloud;
  Color get txt1    => _isDark ? _C.white      : _C.ink;
  Color get txt2    => _isDark ? _C.darkMist   : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDark;
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
    _tabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..value = 1.0;
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() { _loadingProfile = false; _error = 'Not logged in'; });
      return;
    }
    final token = auth.token;

    // profile
    _ProfileApi.fetchProfile(token).then((p) {
      if (mounted) setState(() { _profile = p; _loadingProfile = false; _headerAnim.forward(); });
    }).catchError((_) {
      if (mounted) setState(() { _loadingProfile = false; _profile = auth.user; _headerAnim.forward(); });
    });

    // stats
    _ProfileApi.fetchStats(token).then((s) {
      if (mounted) setState(() { _stats = s; _loadingStats = false; });
    });

    // activity
    _ProfileApi.fetchActivity(token).then((a) {
      if (mounted) setState(() { _activities = a; _loadingActivity = false; });
    });
  }

  void _switchTab(int idx) {
    _tabAnim.reverse().then((_) {
      setState(() => _tab = idx);
      _tabAnim.forward();
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Log out?',
        message: 'You will be signed out of your account.',
        surface: surface, border: border, txt1: txt1, txt2: txt2,
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _tabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: _isDark ? Brightness.dark : Brightness.light,
    ));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: _body()),
      ),
    );
  }

  // ── BODY ───────────────────────────────────────────────────────────────────
  Widget _body() {
    if (_loadingProfile) return _loadingView();
    if (_error != null && _profile == null) return _errorView();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _topBar()),
        SliverToBoxAdapter(child: _profileHeader()),
        SliverToBoxAdapter(child: _metricsRow()),
        SliverToBoxAdapter(child: _tabBar()),
        SliverToBoxAdapter(child: FadeTransition(opacity: _tabAnim, child: _tabContent())),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ── LOADING ────────────────────────────────────────────────────────────────
  Widget _loadingView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_C.forestGreen.withOpacity(0.15), _C.limeGreen.withOpacity(0.15)]),
      ),
      child: const Center(child: CircularProgressIndicator(color: _C.midGreen, strokeWidth: 2.5)),
    ),
    const SizedBox(height: 20),
    Text('Loading your profile…', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: txt2)),
  ]));

  Widget _errorView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: _C.crimson),
    const SizedBox(height: 12),
    Text('Could not load profile', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: txt1)),
    const SizedBox(height: 6),
    Text(_error ?? '', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2)),
    const SizedBox(height: 20),
    _GreenButton(label: 'Retry', onTap: _load),
  ]));

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
          child: Icon(Icons.arrow_back_ios_new_rounded, color: txt1, size: 16),
        ),
      ),
      const SizedBox(width: 14),
      Text('My Profile', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 20, color: txt1, letterSpacing: -0.4)),
      const Spacer(),
      // Dark mode toggle
      GestureDetector(
        onTap: () => setState(() => _isDark = !_isDark),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Icon(_isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: txt1, size: 18),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _logout,
        child: Container(
          height: 42, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _C.crimson.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.crimson.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.logout_rounded, color: _C.crimson, size: 16),
            const SizedBox(width: 6),
            const Text('Logout', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _C.crimson)),
          ]),
        ),
      ),
    ]),
  );

  // ── PROFILE HEADER ─────────────────────────────────────────────────────────
  Widget _profileHeader() {
    final u = _profile ?? context.read<AuthProvider>().user;
    if (u == null) return const SizedBox.shrink();
    final initials = (u.fullName.isNotEmpty ? u.fullName[0] : u.username.isNotEmpty ? u.username[0] : '?').toUpperCase();

    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.3 : 0.07), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Stack(children: [
              // decorative bg gradient arc
              Positioned(top: 0, left: 0, right: 0, height: 90,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_C.forestGreen, _C.midGreen, _C.limeGreen.withOpacity(0.6)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Avatar row
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      // Avatar
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _C.white, width: 3),
                          boxShadow: [BoxShadow(color: _C.forestGreen.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4))],
                        ),
                        child: ClipOval(child: u.profileImage != null && u.profileImage!.isNotEmpty
                          ? Image.network(u.profileImage!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initAvatar(initials))
                          : _initAvatar(initials)),
                      ),
                      // Role badge
                      if (u.role == 'admin')
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: _C.savanna, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 1.5)),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                          )),
                      // Edit overlay
                      Positioned.fill(child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(40),
                          onTap: () => _showEditSheet(context),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                          ),
                        ),
                      )),
                    ]),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 52), // push below gradient band
                      Text(u.fullName.isNotEmpty ? u.fullName : u.username,
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: txt1, height: 1.2)),
                      const SizedBox(height: 2),
                      Text('@${u.username}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.midGreen, fontWeight: FontWeight.w600)),
                    ])),
                    // Edit button
                    GestureDetector(
                      onTap: () => _showEditSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _C.midGreen.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _C.midGreen.withOpacity(0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, size: 13, color: _C.midGreen),
                          const SizedBox(width: 5),
                          const Text('Edit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _C.midGreen)),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 14),
                  // Bio
                  if (u.bio != null && u.bio!.isNotEmpty) ...[
                    Text(u.bio!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2, height: 1.5)),
                    const SizedBox(height: 10),
                  ],

                  // Tags row
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (u.location != null) _Tag(icon: Icons.location_on_rounded, label: u.location!),
                    if (u.occupation != null) _Tag(icon: Icons.work_rounded, label: u.occupation!),
                    if (u.emailVerified) _Tag(icon: Icons.verified_rounded, label: 'Verified', color: _C.midGreen),
                    _Tag(icon: Icons.person_rounded, label: u.role[0].toUpperCase() + u.role.substring(1)),
                  ]),

                  const SizedBox(height: 14),
                  // Email chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _isDark ? _C.darkBorder : _C.snow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(children: [
                      Icon(Icons.email_outlined, size: 15, color: _C.midGreen),
                      const SizedBox(width: 8),
                      Expanded(child: Text(u.email,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt1),
                        overflow: TextOverflow.ellipsis)),
                      Icon(Icons.copy_rounded, size: 14, color: txt2),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _initAvatar(String i) => Container(
    color: _C.forestGreen,
    child: Center(child: Text(i, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 30, color: Colors.white))),
  );

  // ── METRICS ────────────────────────────────────────────────────────────────
  Widget _metricsRow() {
    final items = [
      {'label': 'Donated',    'value': 'KES ${_stats.donations >= 1000 ? '${(_stats.donations/1000).toStringAsFixed(0)}K' : _stats.donations}', 'icon': Icons.volunteer_activism_rounded, 'color': _C.midGreen},
      {'label': 'Campaigns',  'value': _stats.campaigns.toString(),  'icon': Icons.campaign_rounded,        'color': _C.savanna},
      {'label': 'Impact',     'value': _stats.impact.toString(),     'icon': Icons.trending_up_rounded,     'color': const Color(0xFF6A1B9A)},
      {'label': 'Messages',   'value': _stats.unreadMessages.toString(), 'icon': Icons.message_rounded,     'color': _C.amber},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _loadingStats
        ? _shimmer(height: 90)
        : Row(children: items.map((m) => Expanded(child: _MetricCard(
            label:  m['label'] as String,
            value:  m['value'] as String,
            icon:   m['icon'] as IconData,
            color:  m['color'] as Color,
            surface: surface, border: border, txt1: txt1, txt2: txt2,
          ))).toList()),
    );
  }

  // ── TAB BAR ────────────────────────────────────────────────────────────────
  static const _tabs = [
    {'label': 'Overview',    'icon': Icons.dashboard_rounded},
    {'label': 'Activity',    'icon': Icons.history_rounded},
    {'label': 'Achievements','icon': Icons.emoji_events_rounded},
    {'label': 'Settings',    'icon': Icons.settings_rounded},
  ];

  Widget _tabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Container(
      height: 48,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(children: List.generate(_tabs.length, (i) {
        final sel = i == _tab;
        return Expanded(child: GestureDetector(
          onTap: () => _switchTab(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: sel ? _C.midGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_tabs[i]['icon'] as IconData, size: 14, color: sel ? Colors.white : txt2),
              const SizedBox(height: 2),
              Text(_tabs[i]['label'] as String,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 9,
                  color: sel ? Colors.white : txt2)),
            ]),
          ),
        ));
      })),
    ),
  );

  // ── TAB CONTENT ────────────────────────────────────────────────────────────
  Widget _tabContent() {
    switch (_tab) {
      case 0: return _overviewTab();
      case 1: return _activityTab();
      case 2: return _achievementsTab();
      case 3: return _settingsTab();
      default: return const SizedBox.shrink();
    }
  }

  // ──────────────────────────────────── OVERVIEW ────────────────────────────
  Widget _overviewTab() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Quick actions
      _sectionTitle('Quick Actions'),
      const SizedBox(height: 12),
      _quickActions(),
      const SizedBox(height: 24),
      // Two-factor & email status
      _sectionTitle('Account Security'),
      const SizedBox(height: 12),
      _securityCard(),
    ]),
  );

  Widget _quickActions() {
    final u = _profile;
    final actions = [
      {'label': 'My Campaigns',  'icon': Icons.campaign_rounded,            'color': _C.midGreen,             'route': '/account/settings/my-campaigns'},
      {'label': 'My Donations',  'icon': Icons.volunteer_activism_rounded,  'color': _C.savanna,              'route': '/account/donations'},
      {'label': 'Impact Report', 'icon': Icons.bar_chart_rounded,           'color': const Color(0xFF6A1B9A), 'route': '/impact/report'},
      {'label': 'Favourites',    'icon': Icons.favorite_rounded,            'color': _C.crimson,              'route': '/favorites'},
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.8),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, a['route'] as String),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.2 : 0.04), blurRadius: 8)],
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (a['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(a['label'] as String,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: txt1))),
            ]),
          ),
        );
      },
    );
  }

  Widget _securityCard() {
    final u = _profile ?? context.read<AuthProvider>().user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(children: [
        _SecurityRow(
          icon: Icons.email_rounded,
          label: 'Email Verified',
          trailing: _StatusChip(active: u?.emailVerified ?? false),
        ),
        _divider(),
        _SecurityRow(
          icon: Icons.shield_rounded,
          label: '2-Factor Auth',
          trailing: _StatusChip(active: u?.twoFactorEnabled ?? false),
        ),
        _divider(),
        _SecurityRow(
          icon: Icons.lock_reset_rounded,
          label: 'Change Password',
          trailing: Icon(Icons.chevron_right_rounded, color: txt2),
          onTap: () => Navigator.pushNamed(context, '/forgot-password'),
        ),
      ]),
    );
  }

  Widget _divider() => Divider(color: border, height: 1, thickness: 1);

  // ──────────────────────────────────── ACTIVITY ────────────────────────────
  Widget _activityTab() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Recent Activity'),
      const SizedBox(height: 12),
      if (_loadingActivity) _shimmer(height: 200)
      else if (_activities.isEmpty) _emptyActivity()
      else ..._activities.asMap().entries.map((e) => _ActivityItem(
          activity: e.value, index: e.key,
          surface: surface, border: border, txt1: txt1, txt2: txt2,
        )).toList(),
    ]),
  );

  Widget _emptyActivity() => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
    child: Column(children: [
      Icon(Icons.history_toggle_off_rounded, size: 48, color: txt2.withOpacity(0.5)),
      const SizedBox(height: 12),
      Text('No activity yet', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt1)),
      const SizedBox(height: 4),
      Text('Your donations and interactions will show here.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2), textAlign: TextAlign.center),
    ]),
  );

  // ──────────────────────────────── ACHIEVEMENTS ────────────────────────────
  Widget _achievementsTab() {
    final badges = [
      {'title': 'First Donation',    'icon': Icons.star_rounded,             'color': _C.savanna,              'earned': true},
      {'title': 'Campaign Starter',  'icon': Icons.emoji_events_rounded,     'color': _C.midGreen,             'earned': _stats.campaigns > 0},
      {'title': 'Impact Builder',    'icon': Icons.bolt_rounded,             'color': const Color(0xFF6A1B9A), 'earned': _stats.impact >= 10},
      {'title': 'Community Hero',    'icon': Icons.people_alt_rounded,       'color': _C.amber,                'earned': _stats.campaigns >= 3},
      {'title': 'Top Donor',         'icon': Icons.volunteer_activism_rounded,'color': _C.crimson,             'earned': _stats.donations >= 50000},
      {'title': 'Verified Member',   'icon': Icons.verified_rounded,         'color': _C.midGreen,             'earned': _profile?.emailVerified ?? false},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Your Badges'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5),
          itemCount: badges.length,
          itemBuilder: (_, i) {
            final b = badges[i];
            final earned = b['earned'] as bool;
            return _AchievementBadge(
              title: b['title'] as String,
              icon:  b['icon'] as IconData,
              color: b['color'] as Color,
              earned: earned,
              surface: surface, border: border, txt1: txt1, txt2: txt2,
            );
          },
        ),
      ]),
    );
  }

  // ──────────────────────────────────── SETTINGS ────────────────────────────
  Widget _settingsTab() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Account'),
      const SizedBox(height: 12),
      _settingsGroup([
        _SettingsRow(icon: Icons.person_rounded,       label: 'Edit Profile',           trailing: const _Chevron(), onTap: () => _showEditSheet(context)),
        _SettingsRow(icon: Icons.notifications_rounded, label: 'Notifications',          trailing: const _Chevron(), onTap: () => Navigator.pushNamed(context, '/notifications')),
        _SettingsRow(icon: Icons.lock_rounded,         label: 'Privacy & Security',     trailing: const _Chevron(), onTap: () {}),
        _SettingsRow(icon: Icons.payment_rounded,      label: 'Payment Methods',        trailing: const _Chevron(), onTap: () {}),
      ]),
      const SizedBox(height: 20),
      _sectionTitle('Appearance'),
      const SizedBox(height: 12),
      _settingsGroup([
        _SettingsRow(
          icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: 'Dark Mode',
          trailing: _Toggle(value: _isDark, onChanged: (v) => setState(() => _isDark = v)),
        ),
      ]),
      const SizedBox(height: 20),
      _sectionTitle('Support'),
      const SizedBox(height: 12),
      _settingsGroup([
        _SettingsRow(icon: Icons.help_rounded,       label: 'Help & FAQ',    trailing: const _Chevron(), onTap: () {}),
        _SettingsRow(icon: Icons.share_rounded,      label: 'Share App',     trailing: const _Chevron(), onTap: _shareApp),
        _SettingsRow(icon: Icons.privacy_tip_rounded, label: 'Privacy Policy', trailing: const _Chevron(), onTap: () {}),
      ]),
      const SizedBox(height: 20),
      // Danger zone
      GestureDetector(
        onTap: _logout,
        child: Container(
          height: 52, width: double.infinity,
          decoration: BoxDecoration(
            color: _C.crimson.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.crimson.withOpacity(0.25)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: _C.crimson, size: 18),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: _C.crimson)),
          ]),
        ),
      ),
    ]),
  );

  Widget _settingsGroup(List<Widget> rows) => Container(
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
    child: Column(children: rows.indexed.map((e) {
      final isLast = e.$1 == rows.length - 1;
      return Column(children: [
        e.$2,
        if (!isLast) Divider(color: border, height: 1, indent: 52),
      ]);
    }).toList()),
  );

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Row(children: [
    Container(width: 4, height: 18, decoration: BoxDecoration(color: _C.midGreen, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 8),
    Text(t, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: txt1, letterSpacing: -0.2)),
  ]);

  Widget _shimmer({required double height}) => Container(
    height: height, margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: surface.withOpacity(0.6), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border)),
  );

  void _shareApp() {
    Clipboard.setData(const ClipboardData(text: 'https://inuafund.co.ke'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied!'), backgroundColor: _C.midGreen, duration: Duration(seconds: 2)));
  }

  void _showEditSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        user: _profile ?? context.read<AuthProvider>().user,
        surface: surface, border: border, txt1: txt1, txt2: txt2,
        onSaved: () { _load(); Navigator.pop(ctx); },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Tag({required this.icon, required this.label, this.color = const Color(0xFF6B7280)});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11, color: color)),
    ]),
  );
}

class _MetricCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  final Color surface, border, txt1, txt2;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color,
    required this.surface, required this.border, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Column(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 14, color: txt1, letterSpacing: -0.3)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: txt2, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _SecurityRow extends StatelessWidget {
  final IconData icon; final String label; final Widget trailing;
  final VoidCallback? onTap;
  const _SecurityRow({required this.icon, required this.label, required this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 18, color: _C.midGreen),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D0D0D)))),
        trailing,
      ]),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: active ? _C.midGreen.withOpacity(0.10) : const Color(0xFFD93025).withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(active ? 'Active' : 'Off',
      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11,
        color: active ? _C.midGreen : _C.crimson)),
  );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon; final String label; final Widget trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, required this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _C.midGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _C.midGreen),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D0D0D)))),
        trailing,
      ]),
    ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron();
  @override Widget build(BuildContext context) =>
    const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FA896), size: 18);
}

class _Toggle extends StatelessWidget {
  final bool value; final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44, height: 24,
      decoration: BoxDecoration(
        color: value ? _C.midGreen : const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 20, height: 20,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        ),
      ),
    ),
  );
}

class _ActivityItem extends StatelessWidget {
  final _Activity activity; final int index;
  final Color surface, border, txt1, txt2;
  const _ActivityItem({required this.activity, required this.index,
    required this.surface, required this.border, required this.txt1, required this.txt2});

  IconData get _icon {
    switch (activity.type) {
      case 'donation': return Icons.volunteer_activism_rounded;
      case 'campaign': return Icons.campaign_rounded;
      case 'comment':  return Icons.comment_rounded;
      default:         return Icons.circle_rounded;
    }
  }
  Color get _color {
    switch (activity.type) {
      case 'donation': return _C.midGreen;
      case 'campaign': return _C.savanna;
      case 'comment':  return const Color(0xFF1565C0);
      default:         return _C.mist;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: _color.withOpacity(0.10), shape: BoxShape.circle),
        child: Icon(_icon, size: 18, color: _color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(activity.description, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: txt1), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (activity.date.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(_relativeDate(activity.date), style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2)),
        ],
      ])),
    ]),
  );

  String _relativeDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) { return ''; }
  }
}

class _AchievementBadge extends StatelessWidget {
  final String title; final IconData icon; final Color color; final bool earned;
  final Color surface, border, txt1, txt2;
  const _AchievementBadge({required this.title, required this.icon, required this.color,
    required this.earned, required this.surface, required this.border, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: earned ? 1.0 : 0.4,
    duration: const Duration(milliseconds: 300),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? color.withOpacity(0.08) : surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: earned ? color.withOpacity(0.30) : border, width: earned ? 1.5 : 1),
        boxShadow: earned ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0,3))] : [],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 11, color: txt1), maxLines: 2),
          const SizedBox(height: 2),
          Text(earned ? '✓ Earned' : 'Locked', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: earned ? color : txt2)),
        ])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final UserModel? user;
  final Color surface, border, txt1, txt2;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.user, required this.surface, required this.border,
    required this.txt1, required this.txt2, required this.onSaved});
  @override State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _bio      = TextEditingController(text: widget.user?.bio ?? '');
  late final TextEditingController _location = TextEditingController(text: widget.user?.location ?? '');
  late final TextEditingController _occ      = TextEditingController(text: widget.user?.occupation ?? '');
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token') ?? '';
      final body = jsonEncode({'bio': _bio.text, 'location': _location.text, 'occupation': _occ.text});
      await http.put(
        Uri.parse('https://api.inuafund.co.ke/api/users/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: body,
      ).timeout(const Duration(seconds: 12));
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection.'), backgroundColor: _C.crimson));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() { _bio.dispose(); _location.dispose(); _occ.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + padding),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Edit Profile', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: widget.txt1)),
        const SizedBox(height: 24),
        _Field(label: 'Bio', ctrl: _bio, hint: 'Tell us about yourself…', maxLines: 3,
          txt1: widget.txt1, txt2: widget.txt2, border: widget.border),
        const SizedBox(height: 14),
        _Field(label: 'Location', ctrl: _location, hint: 'Nairobi, Kenya',
          txt1: widget.txt1, txt2: widget.txt2, border: widget.border),
        const SizedBox(height: 14),
        _Field(label: 'Occupation', ctrl: _occ, hint: 'Software Engineer',
          txt1: widget.txt1, txt2: widget.txt2, border: widget.border),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 52, width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.forestGreen, _C.limeGreen]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _C.midGreen.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Center(child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save Changes', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
          ),
        ),
      ])),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, hint; final TextEditingController ctrl;
  final int maxLines; final Color txt1, txt2, border;
  const _Field({required this.label, required this.ctrl, required this.hint,
    this.maxLines = 1, required this.txt1, required this.txt2, required this.border});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: txt2)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(
        color: border.withOpacity(0.3), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl, maxLines: maxLines,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2.withOpacity(0.6)),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, message;
  final Color surface, border, txt1, txt2;
  const _ConfirmDialog({required this.title, required this.message,
    required this.surface, required this.border, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60,
          decoration: BoxDecoration(color: _C.crimson.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.logout_rounded, color: _C.crimson, size: 28)),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: txt1)),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(height: 46, decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt2)))),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(height: 46, decoration: BoxDecoration(color: _C.crimson, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Sign Out', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)))),
          )),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GREEN CTA BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GreenButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _GreenButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46, padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.forestGreen, _C.limeGreen]),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white))),
    ),
  );
}