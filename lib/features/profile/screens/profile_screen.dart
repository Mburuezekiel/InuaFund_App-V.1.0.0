// ═══════════════════════════════════════════════════════════════════════════
// profile_screen.dart  — InuaFund  (enhanced UI)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../core/network/auth_service.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const g900 = Color(0xFF0B5E35);
  static const g600 = Color(0xFF1A8C52);
  static const g400 = Color(0xFF4CC97A);
  static const g500 = Color(0xFF2E9E5B);
  static const amber = Color(0xFFE8A020);
  static const red   = Color(0xFFD93025);
  static const ink   = Color(0xFF0D0D0D);
  static const mist  = Color(0xFF8FA896);
  static const snow  = Color(0xFFF4F7F5);
  static const white = Color(0xFFFFFFFF);
  static const card  = Color(0xFFFFFFFF);
  static const bdr   = Color(0xFFE5E7EB);
  static const sub   = Color(0xFF6B7280);
}

// ── Tiny Models ───────────────────────────────────────────────────────────────
class _Stats {
  final int donations, campaigns, impact, messages;
  const _Stats({this.donations=0,this.campaigns=0,this.impact=0,this.messages=0});
  factory _Stats.fromJson(Map<String,dynamic> j) => _Stats(
    donations: (j['totalDonations'] as num?)?.toInt() ?? 0,
    campaigns: (j['campaignsSupported'] as num?)?.toInt() ?? 0,
    impact:    (j['impactScore'] as num?)?.toInt() ?? 0,
    messages:  (j['unreadMessages'] as num?)?.toInt() ?? 0,
  );
}

class _Act {
  final String type, description, date;
  const _Act(this.type, this.description, this.date);
  factory _Act.fromJson(Map<String,dynamic> j) => _Act(
    j['type']?.toString() ?? 'donation',
    j['description']?.toString() ?? '',
    j['createdAt']?.toString() ?? '',
  );
}

// ── API ───────────────────────────────────────────────────────────────────────
class _Api {
  static const _base = 'https://api.inuafund.co.ke/api';
  static Future<Map<String,dynamic>> _get(String url, String tok) async {
    final r = await http.get(Uri.parse(url),
      headers: {'Authorization':'Bearer $tok','Accept':'application/json'})
      .timeout(const Duration(seconds:12));
    return jsonDecode(r.body) as Map<String,dynamic>;
  }
  static Future<UserModel> profile(String tok) async {
    final d = await _get('$_base/users/profile', tok);
    return UserModel.fromJson({...d,'token':tok});
  }
  static Future<_Stats> stats(String tok) async {
    try { return _Stats.fromJson(await _get('$_base/users/stats', tok)); }
    catch(_) { return const _Stats(); }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  UserModel? _user;
  _Stats _stats = const _Stats();
  bool _loading = true;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      if (mounted) setState(() => _loading = false);
      _fadeCtrl.forward();
      _slideCtrl.forward();
      return;
    }
    try {
      final u = await _Api.profile(auth.token);
      final s = await _Api.stats(auth.token);
      if (mounted) {
        setState(() { _user = u; _stats = s; _loading = false; });
        _fadeCtrl.forward();
        _slideCtrl.forward();
      }
    } catch(_) {
      if (mounted) {
        setState(() { _user = auth.user; _loading = false; });
        _fadeCtrl.forward();
        _slideCtrl.forward();
      }
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _LogoutDialog());
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (mounted) {
      setState(() { _user = null; });
      _fadeCtrl.reset();
      _slideCtrl.reset();
      await Future.delayed(const Duration(milliseconds: 80));
      _fadeCtrl.forward();
      _slideCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.snow,
      body: SafeArea(
        child: _loading
            ? _skeleton()
            : FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _content(),
                ),
              ),
      ),
    );
  }

  // ── Skeleton ─────────────────────────────────────────────────────────────
  Widget _skeleton() => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: Column(children: [
      _skBox(h: 60, mx: 20, r: 0),
      const SizedBox(height: 16),
      _skBox(h: 240, mx: 20, r: 24),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2),
          itemCount: 4,
          itemBuilder: (_, __) => _skBox(h: 60, r: 14),
        ),
      ),
      const SizedBox(height: 20),
      _skBox(h: 420, mx: 20, r: 16),
    ]),
  );

  Widget _skBox({double h=20, double mx=0, double r=8}) => _Shimmer(
    child: Container(
      height: h,
      margin: EdgeInsets.symmetric(horizontal: mx),
      decoration: BoxDecoration(color: _C.bdr, borderRadius: BorderRadius.circular(r)),
    ),
  );

  // ── Full Content ──────────────────────────────────────────────────────────
  Widget _content() {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated && _user != null;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _topBar()),
        SliverToBoxAdapter(
          child: isLoggedIn ? _profileCard() : _guestCard(),
        ),
        if (isLoggedIn) ...[
          SliverToBoxAdapter(child: _statsRow()),
          SliverToBoxAdapter(child: _quickActions()),
          SliverToBoxAdapter(child: _settingsList()),
        ] else
          SliverToBoxAdapter(child: _guestActions()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: Stack(alignment: Alignment.center, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.bdr),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _C.ink),
          ),
        ),
      ),
      const Text('My Profile',
        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink)),
    ]),
  );

  // ── Guest Card ────────────────────────────────────────────────────────────
  Widget _guestCard() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.g900, _C.g500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _C.g900.withOpacity(0.30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        // Decorative circles
        Positioned(right: -30, top: -30,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
        Positioned(left: -20, bottom: -20,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 18),
            const Text('Welcome to InuaFund',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Sign in to manage your campaigns,\ntrack donations & make an impact.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.5)),
          ]),
        ),
      ]),
    ),
  );

  // ── Guest Actions ─────────────────────────────────────────────────────────
  Widget _guestActions() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(children: [
      // Sign In button
      GestureDetector(
        onTap: () => context.push('/login'),
        child: Container(
          height: 54, width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.g900, _C.g400]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _C.g600.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.login_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Sign In', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      // Register button
      GestureDetector(
        onTap: () => context.push('/register'),
        child: Container(
          height: 54, width: double.infinity,
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.bdr),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_add_rounded, color: _C.g600, size: 18),
            SizedBox(width: 10),
            Text('Create Account', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: _C.g600)),
          ]),
        ),
      ),
      const SizedBox(height: 32),
      // Feature teasers
      _featureTeaser(Icons.campaign_rounded, 'Create & manage campaigns', _C.g600),
      const SizedBox(height: 10),
      _featureTeaser(Icons.volunteer_activism_rounded, 'Track your donations & impact', _C.amber),
      const SizedBox(height: 10),
      _featureTeaser(Icons.bar_chart_rounded, 'View detailed impact reports', const Color(0xFF6A1B9A)),
    ]),
  );

  Widget _featureTeaser(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: _C.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.bdr),
    ),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 14),
      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: _C.ink)),
    ]),
  );

  // ── Profile Card ──────────────────────────────────────────────────────────
  Widget _profileCard() {
    final u = _user; if (u == null) return const SizedBox.shrink();
    final name = u.fullName.isNotEmpty ? u.fullName : u.username;
    final init = name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.bdr),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          // ── Gradient header ──
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.g900, _C.g500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Stack(children: [
              Positioned(right: -24, top: -24,
                child: Container(width: 130, height: 130,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
              Positioned(left: 40, bottom: -36,
                child: Container(width: 90, height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
              // Membership badge
              Positioned(top: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.30)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(u.role[0].toUpperCase() + u.role.substring(1),
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
                  ]),
                )),
            ]),
          ),
          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Transform.translate(
                offset: const Offset(0, -44),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // Avatar with ring
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_C.g400, _C.g900]),
                      boxShadow: [BoxShadow(color: _C.g900.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.white),
                      child: ClipOval(child: u.profileImage?.isNotEmpty == true
                        ? Image.network(u.profileImage!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initAvatar(init))
                        : _initAvatar(init)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 48),
                    Text(name,
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17, color: _C.ink, height: 1.2)),
                    Row(children: [
                      Text('@${u.username}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _C.g600, fontWeight: FontWeight.w600)),
                      if (u.emailVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 13, color: _C.g600),
                      ],
                    ]),
                  ])),
                  GestureDetector(
                    onTap: _showEditSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.g600.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.g600.withOpacity(0.30)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded, size: 13, color: _C.g600),
                        SizedBox(width: 5),
                        Text('Edit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _C.g600)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (u.bio?.isNotEmpty == true) ...[
                    Text(u.bio!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.sub, height: 1.5)),
                    const SizedBox(height: 10),
                  ],
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (u.location?.isNotEmpty == true) _tag(Icons.location_on_rounded, u.location!),
                    if (u.occupation?.isNotEmpty == true) _tag(Icons.work_rounded, u.occupation!),
                  ]),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: u.email));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Email copied'),
                        backgroundColor: _C.g600,
                        duration: Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _C.snow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.bdr),
                      ),
                      child: Row(children: [
                        const Icon(Icons.email_outlined, size: 15, color: _C.g600),
                        const SizedBox(width: 8),
                        Expanded(child: Text(u.email,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.ink),
                          overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.copy_rounded, size: 14, color: _C.mist),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _initAvatar(String i) => Container(
    color: _C.g900,
    child: Center(child: Text(i,
      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white))),
  );

  Widget _tag(IconData icon, String label, [Color c = _C.sub]) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.22)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: c), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11, color: c)),
    ]),
  );

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _statsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      _statChip('${_stats.donations}', 'Donations', Icons.volunteer_activism_rounded, _C.amber),
      const SizedBox(width: 10),
      _statChip('${_stats.campaigns}', 'Campaigns', Icons.campaign_rounded, _C.g600),
      const SizedBox(width: 10),
      _statChip('${_stats.impact}', 'Impact', Icons.bar_chart_rounded, const Color(0xFF6A1B9A)),
    ]),
  );

  Widget _statChip(String value, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 7),
        Text(value, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _C.sub, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _quickActions() {
    final items = [
      {'label': 'My Campaigns',  'icon': Icons.campaign_rounded,           'color': _C.g600,              'route': '/profile/my-campaigns'},
      {'label': 'Favourites',    'icon': Icons.favorite_rounded,            'color': _C.red,               'route': '/favorites'},
      {'label': 'My Donations',  'icon': Icons.volunteer_activism_rounded,  'color': _C.amber,             'route': '/profile/my-donations'},
      {'label': 'Impact Report', 'icon': Icons.bar_chart_rounded,           'color': const Color(0xFF6A1B9A), 'route': '/impact/report'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Quick Actions'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final a = items[i];
            return GestureDetector(
              onTap: () => context.push(a['route'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.bdr),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                ),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a['label'] as String,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _C.ink))),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  // ── Settings List ─────────────────────────────────────────────────────────
  Widget _settingsList() {
    final u = _user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Account'),
        const SizedBox(height: 10),
        _settingsCard([
          _sRow(Icons.message_rounded,    'Messages',
            trailing: _stats.messages > 0 ? _badge(_stats.messages) : null, onTap: () {}),
          _sRow(Icons.person_rounded,     'Edit Profile',    onTap: _showEditSheet),
          _sRow(Icons.email_rounded,      'Email Verified',  trailing: _chip(u?.emailVerified ?? false)),
          _sRow(Icons.shield_rounded,     '2-Factor Auth',   trailing: _chip(u?.twoFactorEnabled ?? false)),
          _sRow(Icons.lock_reset_rounded, 'Change Password', onTap: () => context.push('/forgot-password')),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('Appearance'),
        const SizedBox(height: 10),
        _settingsCard([
          _sRow(Icons.notifications_rounded, 'Notifications', onTap: () => context.push('/notifications')),
          _sRow(Icons.color_lens_rounded,    'Theme',         onTap: () {}),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('Support'),
        const SizedBox(height: 10),
        _settingsCard([
          _sRow(Icons.help_rounded,        'Help & FAQ',     onTap: () {}),
          _sRow(Icons.share_rounded,       'Share App',      onTap: _shareApp),
          _sRow(Icons.privacy_tip_rounded, 'Privacy Policy', onTap: () {}),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('More'),
        const SizedBox(height: 10),
        _settingsCard([
          _sRow(Icons.info_outline_rounded, 'About App',    onTap: () {}),
          _sRow(Icons.info_outline_rounded, 'App Version',
            trailing: const Text('1.0.0', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _C.mist))),
        ]),
        const SizedBox(height: 20),
        // Sign Out
        GestureDetector(
          onTap: _logout,
          child: Container(
            height: 54, width: double.infinity,
            decoration: BoxDecoration(
              color: _C.red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.red.withOpacity(0.22)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_rounded, color: _C.red, size: 18),
              SizedBox(width: 10),
              Text('Sign Out', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: _C.red)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _settingsCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _C.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _C.bdr),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
    ),
    child: Column(
      children: rows.indexed.map((e) => Column(children: [
        e.$2,
        if (e.$1 < rows.length - 1) const Divider(color: _C.bdr, height: 1, indent: 52),
      ])).toList(),
    ),
  );

  Widget _sRow(IconData icon, String label, {Widget? trailing, VoidCallback? onTap}) =>
    _SettingsRow(icon: icon, label: label, trailing: trailing, onTap: onTap);

  Widget _chip(bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: active ? _C.g600.withOpacity(0.10) : _C.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(active ? 'Active' : 'Off',
      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11,
        color: active ? _C.g600 : _C.red)),
  );

  Widget _badge(int n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(20)),
    child: Text('$n', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
  );

  Widget _sectionLabel(String t) => Row(children: [
    Container(width: 4, height: 17,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.g600, _C.g400], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(3),
      )),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink, letterSpacing: -0.2)),
  ]);

  void _shareApp() {
    Clipboard.setData(const ClipboardData(text: 'https://inuafund.co.ke'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link copied!'), backgroundColor: _C.g600, duration: Duration(seconds: 2)));
  }

  void _showEditSheet() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EditSheet(user: _user, onSaved: () { _load(); Navigator.pop(context); }),
  );
}

extension on BuildContext {
  void pushAndRemoveUntil(BuildContext context, String s, bool Function(_) param2) {}
}

class _ {}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS ROW
// ════════════════════════════════════════════════════════════════════════════
class _SettingsRow extends StatelessWidget {
  final IconData icon; final String label; final Widget? trailing; final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _C.g600.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _C.g600)),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: _C.ink))),
        trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: _C.mist, size: 18)
          : const SizedBox.shrink()),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// EDIT PROFILE SHEET
// ════════════════════════════════════════════════════════════════════════════
class _EditSheet extends StatefulWidget {
  final UserModel? user; final VoidCallback onSaved;
  const _EditSheet({required this.user, required this.onSaved});
  @override State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name  = TextEditingController(text: widget.user?.fullName ?? '');
  late final _bio   = TextEditingController(text: widget.user?.bio ?? '');
  late final _loc   = TextEditingController(text: widget.user?.location ?? '');
  late final _occ   = TextEditingController(text: widget.user?.occupation ?? '');
  late final _phone = TextEditingController(text: widget.user?.phoneNumber ?? '');
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      const s = FlutterSecureStorage();
      final tok = await s.read(key: 'jwt_token') ?? '';
      await http.put(
        Uri.parse('https://api.inuafund.co.ke/api/users/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $tok'},
        body: jsonEncode({'fullName': _name.text, 'bio': _bio.text, 'location': _loc.text,
          'occupation': _occ.text, 'phone': _phone.text}),
      ).timeout(const Duration(seconds: 12));
      widget.onSaved();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check connection.'), backgroundColor: _C.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() { _name.dispose(); _bio.dispose(); _loc.dispose(); _occ.dispose(); _phone.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + pad),
      decoration: const BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _C.bdr, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('Edit Profile',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: _C.ink)),
        const SizedBox(height: 22),
        _field('Full Name',  _name,  'Jane Doe'),
        const SizedBox(height: 12),
        _field('Bio',        _bio,   'Tell us about yourself…', max: 3),
        const SizedBox(height: 12),
        _field('Location',   _loc,   'Nairobi, Kenya'),
        const SizedBox(height: 12),
        _field('Occupation', _occ,   'Software Engineer'),
        const SizedBox(height: 12),
        _field('Phone',      _phone, '+254 700 000 000', kb: TextInputType.phone),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 54, width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.g900, _C.g400]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _C.g600.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Center(child: _saving
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save Changes',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
          ),
        ),
      ])),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {int max=1, TextInputType? kb}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _C.sub)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: _C.snow, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.bdr)),
        child: TextField(
          controller: ctrl, maxLines: max, keyboardType: kb,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.mist),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    ]);
}

// ════════════════════════════════════════════════════════════════════════════
// LOGOUT DIALOG
// ════════════════════════════════════════════════════════════════════════════
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _C.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60,
        decoration: BoxDecoration(color: _C.red.withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.logout_rounded, color: _C.red, size: 26)),
      const SizedBox(height: 14),
      const Text('Sign out?',
        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: _C.ink)),
      const SizedBox(height: 6),
      const Text('You will be signed out of your account.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _C.sub), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(height: 48,
            decoration: BoxDecoration(border: Border.all(color: _C.bdr), borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('Cancel',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: _C.sub)))),
        )),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, true),
          child: Container(height: 48,
            decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _C.red.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Center(child: Text('Sign Out',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)))),
        )),
      ]),
    ])),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SHIMMER WRAPPER
// ════════════════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});
  @override State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, child) => ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        colors: [_C.bdr, _C.bdr, Colors.white.withOpacity(0.8), _C.bdr, _C.bdr],
        transform: _SlideGradient(_ac.value),
      ).createShader(rect),
      child: child,
    ),
    child: widget.child,
  );
}

class _SlideGradient extends GradientTransform {
  final double t;
  const _SlideGradient(this.t);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
    Matrix4.translationValues(bounds.width * (2 * t - 1), 0, 0);
}