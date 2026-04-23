// ═══════════════════════════════════════════════════════════════════════════════
// home_screen.dart
// Full HomeScreen — nav items wired, FAB navigates to StartCampaignScreen,
// auth token/user passed from AuthProvider
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/network/auth_service.dart';
import '../../campaign/screens/create_campaign.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════

class AppColors {
  static const forestGreen  = Color(0xFF0B5E35);
  static const midGreen     = Color(0xFF1A8C52);
  static const limeGreen    = Color(0xFF4CC97A);
  static const savanna      = Color(0xFFE8A020);
  static const crimson      = Color(0xFFD93025);
  static const amber        = Color(0xFFE8860A);
  static const ink          = Color(0xFF0D0D0D);
  static const mist         = Color(0xFF8FA896);
  static const cloud        = Color(0xFFEEEEEE);
  static const snow         = Color(0xFFF7F7F7);
  static const white        = Color(0xFFFFFFFF);
  static const darkBg       = Color(0xFF060E09);
  static const darkCard     = Color(0xFF0D1A11);
  static const darkBorder   = Color(0xFF1C2E22);
  static const darkMist     = Color(0xFF4D6657);

  static const tierGold1   = Color(0xFFFFD700);
  static const tierGold2   = Color(0xFFFFA500);
  static const tierSilver1 = Color(0xFFE8E8E8);
  static const tierSilver2 = Color(0xFFB0B0B0);
  static const tierBronze1 = Color(0xFFCD7F32);
  static const tierBronze2 = Color(0xFFA0522D);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIER
// ═══════════════════════════════════════════════════════════════════════════════

enum CampaignTier { gold, silver, bronze, none }

extension CampaignTierExt on CampaignTier {
  List<Color> get colors {
    switch (this) {
      case CampaignTier.gold:   return [AppColors.tierGold1, AppColors.tierGold2];
      case CampaignTier.silver: return [AppColors.tierSilver1, AppColors.tierSilver2];
      case CampaignTier.bronze: return [AppColors.tierBronze1, AppColors.tierBronze2];
      case CampaignTier.none:   return [];
    }
  }
  Color get glowColor {
    switch (this) {
      case CampaignTier.gold:   return const Color(0xAAFFA500);
      case CampaignTier.silver: return const Color(0x88B0B0B0);
      case CampaignTier.bronze: return const Color(0x88A0522D);
      case CampaignTier.none:   return Colors.transparent;
    }
  }
  static CampaignTier fromMomentum(double score) {
    if (score >= 8.0) return CampaignTier.gold;
    if (score >= 6.0) return CampaignTier.silver;
    if (score >= 3.5) return CampaignTier.bronze;
    return CampaignTier.none;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CROWN + RIBBON MEDAL
// ═══════════════════════════════════════════════════════════════════════════════

class TierMedalBadge extends StatelessWidget {
  final CampaignTier tier;
  final double size;
  const TierMedalBadge({super.key, required this.tier, this.size = 36});

  @override
  Widget build(BuildContext context) {
    if (tier == CampaignTier.none) return const SizedBox.shrink();
    final colors = tier.colors;
    final glow   = tier.glowColor;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: glow, blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 3))],
        ),
        child: Center(child: CustomPaint(size: Size(size * 0.54, size * 0.40), painter: _CrownPainter())),
      ),
      Transform.translate(
        offset: const Offset(0, -2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Strip(w: size * 0.26, h: size * 0.42, color: colors[0]),
          const SizedBox(width: 2),
          _Strip(w: size * 0.26, h: size * 0.42, color: colors[1]),
        ]),
      ),
    ]);
  }
}

class _Strip extends StatelessWidget {
  final double w, h; final Color color;
  const _Strip({required this.w, required this.h, required this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(w * 0.45), bottomRight: Radius.circular(w * 0.45)),
    child: Container(width: w, height: h, color: color),
  );
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.93)..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    final path = Path()
      ..moveTo(0, h)..lineTo(w, h)
      ..lineTo(w, h * 0.52)..lineTo(w * 0.78, 0)
      ..lineTo(w * 0.60, h * 0.46)..lineTo(w * 0.50, 0)
      ..lineTo(w * 0.40, h * 0.46)..lineTo(w * 0.22, 0)
      ..lineTo(0, h * 0.52)..close();
    canvas.drawPath(path, paint);
    final gem = Paint()..color = Colors.white.withOpacity(0.45)..style = PaintingStyle.fill;
    for (final dx in [w * 0.22, w * 0.50, w * 0.78]) {
      canvas.drawCircle(Offset(dx, w * 0.07 * 0.9), w * 0.07, gem);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class Campaign {
  final String id, title, description, category;
  final double amountRaised, goal, completionPercentage, momentumScore;
  final int daysRemaining, donorCount;
  final String? featuredImage, creatorName;
  final String urgencyLevel;

  const Campaign({
    required this.id, required this.title, required this.description,
    required this.category, required this.amountRaised, required this.goal,
    required this.completionPercentage, this.momentumScore = 0,
    required this.daysRemaining, required this.donorCount,
    this.featuredImage, this.creatorName, this.urgencyLevel = 'low',
  });

  CampaignTier get tier => CampaignTierExt.fromMomentum(momentumScore);

  factory Campaign.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is Map) {
        if (v['\$numberInt']    != null) return double.parse(v['\$numberInt'].toString());
        if (v['\$numberDouble'] != null) return double.parse(v['\$numberDouble'].toString());
      }
      return double.tryParse(v.toString()) ?? 0;
    }
    final raised = n(j['amountRaised'] ?? j['currentAmount']);
    final goal   = n(j['goal']);
    final pct    = goal > 0 ? (raised / goal * 100).clamp(0.0, 100.0) : 0.0;
    int days = 0;
    if (j['daysRemaining'] != null) {
      days = n(j['daysRemaining']).toInt();
    } else if (j['endDate'] != null) {
      try { days = DateTime.parse(j['endDate'].toString()).difference(DateTime.now()).inDays.clamp(0, 9999); } catch (_) {}
    }
    final c = j['creator_Id'] ?? j['creator'];
    final creator = c is Map ? c['username']?.toString() : j['username']?.toString() ?? 'Anonymous';
    return Campaign(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      category: j['category']?.toString() ?? 'General',
      amountRaised: raised, goal: goal,
      completionPercentage: pct.toDouble(),
      momentumScore: n(j['momentumScore']),
      daysRemaining: days,
      donorCount: n(j['donorCount'] ?? j['donorsCount']).toInt(),
      featuredImage: j['featuredImage']?.toString(),
      creatorName: creator,
      urgencyLevel: j['urgencyLevel']?.toString() ?? 'low',
    );
  }

  Color get urgencyColor {
    switch (urgencyLevel) {
      case 'high':   return AppColors.crimson;
      case 'medium': return AppColors.amber;
      default:       return AppColors.midGreen;
    }
  }

  List<Color> get categoryGradient {
    switch (category.toLowerCase()) {
      case 'medical':     return [const Color(0xFF0B5E35), const Color(0xFF1A8C52)];
      case 'education':   return [const Color(0xFF1565C0), const Color(0xFF1877C5)];
      case 'emergencies': return [const Color(0xFFB71C1C), const Color(0xFFD93025)];
      case 'water':       return [const Color(0xFF006064), const Color(0xFF00838F)];
      case 'environment': return [const Color(0xFF1B5E20), const Color(0xFF2E7D32)];
      case 'community':   return [const Color(0xFF4A148C), const Color(0xFF6A1B9A)];
      default:            return [AppColors.forestGreen, AppColors.midGreen];
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'medical':     return Icons.favorite_rounded;
      case 'education':   return Icons.school_rounded;
      case 'emergencies': return Icons.warning_amber_rounded;
      case 'water':       return Icons.water_drop_rounded;
      case 'environment': return Icons.eco_rounded;
      case 'community':   return Icons.people_rounded;
      default:            return Icons.volunteer_activism_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPAIGN SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class CampaignService {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<List<Campaign>> fetchFeatured() async {
    try {
      final res = await http.get(Uri.parse('$_base/campaigns/featured'),
          headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data is Map ? data['data'] : data) as List? ?? [];
        return list.map((e) => Campaign.fromJson(e)).toList();
      }
    } catch (_) {}
    return _mock();
  }

  static Future<List<Campaign>> fetchAll({String? category}) async {
    try {
      final uri = Uri.parse('$_base/campaigns').replace(queryParameters: {
        'status': 'approved',
        if (category != null && category != 'All') 'category': category,
        'limit': '20',
      });
      final res = await http.get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data is Map ? (data['data'] ?? data['campaigns']) : data) as List? ?? [];
        return list.map((e) => Campaign.fromJson(e)).where((c) => c.title.isNotEmpty).toList();
      }
    } catch (_) {}
    return _mock();
  }

  static Future<List<Campaign>> search(String q) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/campaigns?search=${Uri.encodeComponent(q)}'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data is Map ? data['data'] : data) as List? ?? [];
        return list.map((e) => Campaign.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static List<Campaign> _mock() => [
    const Campaign(id: '1', title: 'Help Mama Wanjiku with Cancer Treatment',
      description: 'Mama Wanjiku needs urgent support for chemotherapy at KNH.',
      category: 'medical', amountRaised: 145000, goal: 300000,
      completionPercentage: 48.3, daysRemaining: 14, donorCount: 89,
      urgencyLevel: 'high', momentumScore: 9.1, creatorName: 'James Kamau'),
    const Campaign(id: '2', title: 'Flood Relief — Tana River Families',
      description: 'Emergency relief for 500+ families displaced by floods.',
      category: 'emergencies', amountRaised: 312000, goal: 400000,
      completionPercentage: 78.0, daysRemaining: 7, donorCount: 423,
      urgencyLevel: 'high', momentumScore: 8.5, creatorName: 'Red Cross Kenya'),
    const Campaign(id: '3', title: 'Kibera School Desks & Books Drive',
      description: 'Quality desks and learning materials for 200 students.',
      category: 'education', amountRaised: 67500, goal: 120000,
      completionPercentage: 56.3, daysRemaining: 30, donorCount: 156,
      urgencyLevel: 'low', momentumScore: 6.2, creatorName: 'Faith Otieno'),
    const Campaign(id: '4', title: 'Borehole for Turkana Community',
      description: 'Clean water access for 3,000 people via solar borehole.',
      category: 'water', amountRaised: 230000, goal: 450000,
      completionPercentage: 51.1, daysRemaining: 45, donorCount: 201,
      urgencyLevel: 'medium', momentumScore: 5.0, creatorName: 'WaterAid Kenya'),
    const Campaign(id: '5', title: 'Bursary for 12 Students — Kisumu',
      description: 'Scholarship fund for bright students in Kisumu.',
      category: 'education', amountRaised: 88000, goal: 150000,
      completionPercentage: 58.7, daysRemaining: 12, donorCount: 67,
      urgencyLevel: 'medium', momentumScore: 3.8, creatorName: 'Kisumu Youth Fund'),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATED DONATE BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _AnimatedDonateButton extends StatefulWidget {
  const _AnimatedDonateButton();
  @override State<_AnimatedDonateButton> createState() => _AnimatedDonateButtonState();
}

class _AnimatedDonateButtonState extends State<_AnimatedDonateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _tap() async {
    await _ctrl.forward(); await _ctrl.reverse();
    if (mounted) setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: GestureDetector(
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _done ? [const Color(0xFF1A8C52), const Color(0xFF4CC97A)]
                          : [AppColors.forestGreen, AppColors.limeGreen],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(_done ? 0.22 : 0.38), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: _done
                ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18, key: ValueKey('ok'))
                : const Text('💚', style: TextStyle(fontSize: 15), key: ValueKey('h')),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(_done ? 'Donated! 🎉' : 'Donate Now',
              key: ValueKey(_done),
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
          ),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isDark = false;
  int  _navIndex = 0;
  String _selectedCategory = 'All';
  int _carouselPage = 0;

  List<Campaign> _featured = [];
  List<Campaign> _campaigns = [];
  bool _loadingFeatured = true;
  bool _loadingCampaigns = true;

  bool _searchActive = false;
  String _searchQuery = '';
  List<Campaign> _searchResults = [];
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  late final PageController _pageCtrl;
  late final AnimationController _listCtrl;

  Color get bg      => _isDark ? AppColors.darkBg    : AppColors.snow;
  Color get surface => _isDark ? AppColors.darkCard   : AppColors.white;
  Color get border  => _isDark ? AppColors.darkBorder : AppColors.cloud;
  Color get txt1    => _isDark ? AppColors.white      : AppColors.ink;
  Color get txt2    => _isDark ? AppColors.darkMist   : const Color(0xFF6B7280);
  Color get txtHint => _isDark ? AppColors.darkMist   : const Color(0xFFB0B8BF);

  static const _categories = [
    {'label': 'All',         'icon': Icons.apps_rounded},
    {'label': 'medical',     'icon': Icons.favorite_rounded},
    {'label': 'education',   'icon': Icons.school_rounded},
    {'label': 'community',   'icon': Icons.people_rounded},
    {'label': 'emergencies', 'icon': Icons.warning_amber_rounded},
    {'label': 'water',       'icon': Icons.water_drop_rounded},
    {'label': 'environment', 'icon': Icons.eco_rounded},
  ];

  // ── Nav route map ──────────────────────────────────────────────────────────
  // Each nav index maps to a named route or an action.
  // 0 = Home (stay), 1 = Explore, 2 = FAB/Create, 3 = Alerts, 4 = Profile
  static const _navRoutes = {
    1: '/explore',
    3: '/alerts',
    4: '/profile',
  };

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.90);
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _loadAll();
  }

  Future<void> _loadAll() async { _loadFeatured(); _loadCampaigns(); }

  Future<void> _loadFeatured() async {
    setState(() => _loadingFeatured = true);
    final d = await CampaignService.fetchFeatured();
    if (mounted) setState(() { _featured = d.take(3).toList(); _loadingFeatured = false; });
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loadingCampaigns = true);
    final d = await CampaignService.fetchAll(category: _selectedCategory);
    if (mounted) {
      setState(() { _campaigns = d; _loadingCampaigns = false; });
      _listCtrl.forward(from: 0);
    }
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final r = await CampaignService.search(q);
    if (mounted) setState(() { _searchResults = r; _searching = false; });
  }

  // ── Navigate to StartCampaignScreen — pulls user from AuthProvider ─────────
  void _openCreateCampaign() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      _showAuthRequired();
      return;
    }
    final user = auth.user!;
    Navigator.push(
      context,
      _campaignRoute(StartCampaignScreen(
        isDark:     _isDark,
        authToken:  auth.token,
        userId:     user.id,
        username:   user.username,
        userEmail:  user.email,
        userPhone:  user.phoneNumber,
      )),
    );
  }

  void _showAuthRequired() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthRequiredSheet(surface: surface, border: border, txt1: txt1, txt2: txt2,
        onLogin: () { Navigator.pop(context); Navigator.pushNamed(context, '/login'); }),
    );
  }

  // ── Handle bottom nav taps ─────────────────────────────────────────────────
  void _onNavTap(int idx) {
  if (idx == 0) { setState(() => _navIndex = 0); return; }
  
  switch (idx) {
    case 1: context.push('/explore'); break;   // ⚠️ add GoRoute for this
    case 3: context.push('/alerts');  break;
    case 4: context.push('/profile'); break;
  }
  setState(() => _navIndex = idx);
}

  @override
  void dispose() { _pageCtrl.dispose(); _listCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  String _kes(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  // ── Greeting based on time of day ──────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
        body: SafeArea(child: _searchActive ? _buildSearch() : _buildMain()),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  // ── SEARCH VIEW ─────────────────────────────────────────────────────────────
  Widget _buildSearch() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.midGreen, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: AppColors.midGreen, size: 19),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _searchCtrl, autofocus: true,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt1),
                decoration: InputDecoration(
                  hintText: 'Search campaigns, causes…',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txtHint),
                  border: InputBorder.none,
                ),
                onChanged: (v) { setState(() => _searchQuery = v); _doSearch(v); },
              )),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _searchResults = []; }); },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.close_rounded, color: txt2, size: 18)),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () { setState(() { _searchActive = false; _searchQuery = ''; _searchResults = []; }); _searchCtrl.clear(); },
          child: Container(
            height: 50, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
            child: const Center(child: Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.midGreen))),
          ),
        ),
      ]),
    ),
    const SizedBox(height: 16),
    Expanded(
      child: _searching
          ? const Center(child: CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 2.5))
          : _searchQuery.length < 2
              ? _searchHints()
              : _searchResults.isEmpty
                  ? _noResults()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) => _SearchCard(c: _searchResults[i], surface: surface, border: border, txt1: txt1, txt2: txt2, kes: _kes)),
    ),
  ]);

  Widget _searchHints() {
    final tags = ['medical', 'education', 'water', 'emergencies', 'community', 'borehole'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Popular searches', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: txt1)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: tags.map((t) => GestureDetector(
          onTap: () { _searchCtrl.text = t; setState(() => _searchQuery = t); _doSearch(t); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.midGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.midGreen.withOpacity(0.25)),
            ),
            child: Text(t, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.midGreen)),
          ),
        )).toList()),
      ]),
    );
  }

  Widget _noResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.search_off_rounded, size: 54, color: txtHint),
    const SizedBox(height: 12),
    Text('No campaigns found', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: txt1)),
    const SizedBox(height: 6),
    Text('Try a different keyword', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2)),
  ]));

  // ── MAIN SCROLL VIEW ────────────────────────────────────────────────────────
  Widget _buildMain() => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: _topBar()),
      SliverToBoxAdapter(child: _searchBar()),
      SliverToBoxAdapter(child: _statsRow()),
      SliverToBoxAdapter(child: _sectionLabel('Featured campaigns')),
      SliverToBoxAdapter(child: _featuredCarousel()),
      SliverToBoxAdapter(child: _sectionLabel('Browse by category')),
      SliverToBoxAdapter(child: _categoryChips()),
      SliverToBoxAdapter(child: _activeCampaignsHeader()),
      if (_loadingCampaigns)
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _SkeletonCard(surface: surface, border: border), childCount: 3))
      else if (_campaigns.isEmpty)
        SliverToBoxAdapter(child: _emptyState())
      else
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _StaggerItem(
            index: i, ctrl: _listCtrl,
            child: _ActiveCampaignCard(c: _campaigns[i], isDark: _isDark,
              surface: surface, border: border, txt1: txt1, txt2: txt2, txtHint: txtHint, kes: _kes),
          ),
          childCount: _campaigns.length,
        )),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ],
  );

  // ── Top bar — reads user name from AuthProvider ─────────────────────────────
  Widget _topBar() {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.username ?? auth.user?.fullName ?? 'there';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2, fontWeight: FontWeight.w400)),
          const SizedBox(height: 2),
          Text('Karibu, $displayName 👋',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 24, color: txt1, letterSpacing: -0.5, height: 1.15)),
          const SizedBox(height: 3),
          Text('What cause will you support today?', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2)),
        ])),
        const SizedBox(width: 12),
        _RoundedIconBtn(icon: Icons.search_rounded, surface: surface, border: border, iconColor: txt1,
          onTap: () => setState(() => _searchActive = true)),
        const SizedBox(width: 8),
        // Dark mode toggle
        _RoundedIconBtn(
          icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          surface: surface, border: border, iconColor: txt1,
          onTap: () => setState(() => _isDark = !_isDark),
        ),
        const SizedBox(width: 8),
        Stack(clipBehavior: Clip.none, children: [
          _RoundedIconBtn(icon: Icons.notifications_outlined, surface: surface, border: border, iconColor: txt1,
            onTap: () => _onNavTap(3)),
          Positioned(top: 8, right: 8,
            child: Container(width: 9, height: 9,
              decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle, border: Border.all(color: surface, width: 1.5)))),
        ]),
      ]),
    );
  }

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: GestureDetector(
      onTap: () => setState(() => _searchActive = true),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: txtHint, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text('Search campaigns, causes...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txtHint))),
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text('Filter', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
            ]),
          ),
        ]),
      ),
    ),
  );

  Widget _statsRow() {
    final totalRaised = _campaigns.fold<double>(0, (s, c) => s + c.amountRaised);
    final totalDonors = _campaigns.fold<int>(0, (s, c) => s + c.donorCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(children: [
        _StatCard(value: _campaigns.isEmpty ? '—' : _campaigns.length.toString(), label: 'Campaigns', surface: surface, border: border, txt1: txt1, txt2: txt2),
        const SizedBox(width: 10),
        _StatCard(value: _kes(totalRaised), label: 'Total raised', surface: surface, border: border, txt1: txt1, txt2: txt2),
        const SizedBox(width: 10),
        _StatCard(
          value: totalDonors >= 1000 ? '${(totalDonors / 1000).toStringAsFixed(1)}K' : totalDonors.toString(),
          label: 'Donors', surface: surface, border: border, txt1: txt1, txt2: txt2),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17, color: txt1, letterSpacing: -0.2)),
    ]),
  );

  Widget _featuredCarousel() => Column(children: [
    SizedBox(
      height: 330,
      child: _loadingFeatured
          ? _shimmerCarousel()
          : _featured.isEmpty ? const SizedBox()
          : PageView.builder(
              controller: _pageCtrl,
              itemCount: _featured.length,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemBuilder: (_, i) => _FeaturedCard(c: _featured[i], kes: _kes, surface: surface, border: border, txt1: txt1, txt2: txt2),
            ),
    ),
    if (!_loadingFeatured && _featured.isNotEmpty) ...[
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_featured.length, (i) =>
        AnimatedContainer(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _carouselPage == i ? 24 : 7, height: 7,
          decoration: BoxDecoration(color: _carouselPage == i ? AppColors.midGreen : border, borderRadius: BorderRadius.circular(4)),
        ),
      )),
    ],
  ]);

  Widget _shimmerCarousel() => ListView.builder(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10),
    itemCount: 2,
    itemBuilder: (_, __) => _ShimmerBox(w: 300, h: 310, r: 22, surface: surface));

  Widget _categoryChips() => SizedBox(
    height: 40,
    child: ListView.builder(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final cat = _categories[i];
        final sel = _selectedCategory == cat['label'];
        return GestureDetector(
          onTap: () { setState(() => _selectedCategory = cat['label'] as String); _loadCampaigns(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: sel ? AppColors.midGreen : surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? AppColors.midGreen : border, width: 1.2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (sel)
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
              else ...[
                Icon(cat['icon'] as IconData, size: 13, color: txt2),
                const SizedBox(width: 5),
              ],
              Text(cat['label'] as String,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13,
                  color: sel ? Colors.white : txt2)),
            ]),
          ),
        );
      },
    ),
  );

  Widget _activeCampaignsHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Text('Active campaigns', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17, color: txt1, letterSpacing: -0.2)),
      const Spacer(),
      GestureDetector(
        onTap: () => _onNavTap(1), // goes to Explore
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.midGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.midGreen.withOpacity(0.2)),
          ),
          child: const Text('See all', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.midGreen)),
        ),
      ),
    ]),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
    child: Column(children: [
      const Text('🌿', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('No campaigns yet', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: txt1), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('Be the first in this category', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2), textAlign: TextAlign.center),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV — fully wired
  // 0 Home · 1 Explore · FAB Create · 3 Alerts · 4 Profile
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNav() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    decoration: BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: border, width: 0.8)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.45 : 0.06), blurRadius: 18, offset: const Offset(0, -4))],
    ),
    child: SafeArea(
      child: SizedBox(
        height: 64,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          // 0 — Home
          _NavItem(icon: Icons.home_rounded, label: 'Home', idx: 0,
            cur: _navIndex, txt2: txt2, onTap: _onNavTap),

          // 1 — Explore
          _NavItem(icon: Icons.explore_rounded, label: 'Explore', idx: 1,
            cur: _navIndex, txt2: txt2, onTap: _onNavTap),

          // FAB — Create Campaign (idx 2, wired to StartCampaignScreen)
          GestureDetector(
            onTap: _openCreateCampaign,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.forestGreen, AppColors.limeGreen],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 5))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),

          // 3 — Alerts
          _NavItem(icon: Icons.notifications_outlined, label: 'Alerts', idx: 3,
            cur: _navIndex, txt2: txt2, onTap: _onNavTap),

          // 4 — Profile
          _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', idx: 4,
            cur: _navIndex, txt2: txt2, onTap: _onNavTap),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH REQUIRED BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _AuthRequiredSheet extends StatelessWidget {
  final Color surface, border, txt1, txt2;
  final VoidCallback onLogin;
  const _AuthRequiredSheet({required this.surface, required this.border, required this.txt1, required this.txt2, required this.onLogin});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 24),
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.forestGreen.withOpacity(0.15), AppColors.limeGreen.withOpacity(0.15)])),
        child: const Icon(Icons.lock_outline_rounded, color: AppColors.midGreen, size: 36)),
      const SizedBox(height: 20),
      Text('Sign in to Create', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 20, color: txt1)),
      const SizedBox(height: 8),
      Text('You need an account to start a campaign.\nIt only takes a minute!',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: txt2, height: 1.5)),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: onLogin,
        child: Container(
          height: 52, width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: const Center(child: Text('Sign In / Register', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(height: 50, width: double.infinity, alignment: Alignment.center,
          child: Text('Not now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: txt2))),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURED CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _FeaturedCard extends StatelessWidget {
  final Campaign c;
  final String Function(double) kes;
  final Color surface, border, txt1, txt2;
  const _FeaturedCard({required this.c, required this.kes, required this.surface, required this.border, required this.txt1, required this.txt2});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        SizedBox(height: 170, child: Stack(children: [
          Positioned.fill(child: c.featuredImage != null
              ? Image.network(c.featuredImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _gradBg())
              : _gradBg()),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
          Positioned(top: 14, left: 14, child: Row(children: [
            if (c.urgencyLevel == 'high') ...[const _BadgePill(label: 'URGENT', bg: AppColors.crimson), const SizedBox(width: 6)],
            _BadgePill(label: c.category.toUpperCase(), bg: AppColors.midGreen),
          ])),
          if (c.tier != CampaignTier.none)
            Positioned(top: 10, right: 14, child: TierMedalBadge(tier: c.tier, size: 36)),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.creatorName != null) Text('by ${c.creatorName}', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
            const SizedBox(height: 4),
            Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16, color: txt1, height: 1.3)),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
              builder: (_, val, __) => ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.midGreen)))),
            const SizedBox(height: 10),
            Row(children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: kes(c.amountRaised), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.midGreen)),
                TextSpan(text: ' / ${kes(c.goal)}', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
              ])),
              const Spacer(),
              Text('${c.completionPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.savanna)),
            ]),
            const SizedBox(height: 6),
            Text('${c.donorCount} donors · ${c.daysRemaining} days left', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
            const SizedBox(height: 14),
            const SizedBox(width: double.infinity, child: _AnimatedDonateButton()),
          ]),
        ),
      ]),
    );
  }
  Widget _gradBg() => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: c.categoryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE CAMPAIGN CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveCampaignCard extends StatelessWidget {
  final Campaign c;
  final bool isDark;
  final Color surface, border, txt1, txt2, txtHint;
  final String Function(double) kes;
  const _ActiveCampaignCard({required this.c, required this.isDark, required this.surface,
    required this.border, required this.txt1, required this.txt2, required this.txtHint, required this.kes});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    final urgent   = c.daysRemaining <= 7;
    final barColor = urgent ? c.urgencyColor : AppColors.midGreen;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: urgent ? c.urgencyColor.withOpacity(0.30) : border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.22 : 0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: c.categoryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: c.featuredImage != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: Image.network(c.featuredImage!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbIcon()))
                    : _thumbIcon(),
              ),
              if (c.tier != CampaignTier.none)
                Positioned(bottom: -6, left: -4, child: TierMedalBadge(tier: c.tier, size: 24)),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: c.categoryGradient[0].withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(c.category.toUpperCase(),
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 10, color: c.categoryGradient[0])),
                ),
                if (urgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                    child: const Text('EMERGENCY', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 10, color: AppColors.crimson)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: txt1, height: 1.3)),
              const SizedBox(height: 4),
              if (c.creatorName != null)
                Text('by ${c.creatorName}', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 950), curve: Curves.easeOutCubic,
              builder: (_, val, __) => ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: val, minHeight: 7, backgroundColor: border,
                  valueColor: AlwaysStoppedAnimation(barColor)))),
            const SizedBox(height: 10),
            Row(children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: kes(c.amountRaised), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.midGreen)),
                TextSpan(text: ' / ${kes(c.goal)}', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
              ])),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgent ? AppColors.crimson.withOpacity(0.10) : border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: urgent ? AppColors.crimson.withOpacity(0.25) : Colors.transparent),
                ),
                child: Text('${c.daysRemaining}d left',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11,
                    color: urgent ? AppColors.crimson : txtHint)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${c.donorCount} donors · ${c.completionPercentage.toStringAsFixed(0)}% funded',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
            const SizedBox(height: 14),
            const SizedBox(width: double.infinity, child: _AnimatedDonateButton()),
          ]),
        ),
      ]),
    );
  }
  Widget _thumbIcon() => Center(child: Icon(c.categoryIcon, color: Colors.white.withOpacity(0.85), size: 32));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH RESULT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchCard extends StatelessWidget {
  final Campaign c;
  final Color surface, border, txt1, txt2;
  final String Function(double) kes;
  const _SearchCard({required this.c, required this.surface, required this.border,
    required this.txt1, required this.txt2, required this.kes});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
    child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(gradient: LinearGradient(colors: c.categoryGradient), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Icon(c.categoryIcon, color: Colors.white, size: 24))),
        if (c.tier != CampaignTier.none)
          Positioned(bottom: -5, right: -5, child: TierMedalBadge(tier: c.tier, size: 20)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt1)),
        const SizedBox(height: 3),
        Text(c.category, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.midGreen)),
      ])),
      const SizedBox(width: 10),
      Text(kes(c.goal), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.forestGreen)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGGER ANIMATION
// ═══════════════════════════════════════════════════════════════════════════════

class _StaggerItem extends StatelessWidget {
  final int index;
  final AnimationController ctrl;
  final Widget child;
  const _StaggerItem({required this.index, required this.ctrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.10).clamp(0.0, 0.75);
    final end   = (start + 0.38).clamp(0.0, 1.0);
    final anim  = CurvedAnimation(parent: ctrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - anim.value)), child: child)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SKELETON / SHIMMER
// ═══════════════════════════════════════════════════════════════════════════════

class _SkeletonCard extends StatefulWidget {
  final Color surface, border;
  const _SkeletonCard({required this.surface, required this.border});
  @override State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14), height: 120,
      decoration: BoxDecoration(
        color: widget.surface.withOpacity(0.5 + _anim.value * 0.35),
        borderRadius: BorderRadius.circular(18), border: Border.all(color: widget.border)),
    ),
  );
}

class _ShimmerBox extends StatefulWidget {
  final double w, h, r; final Color surface;
  const _ShimmerBox({required this.w, required this.h, required this.r, required this.surface});
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.w, height: widget.h, margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: widget.surface.withOpacity(0.5 + _anim.value * 0.35),
        borderRadius: BorderRadius.circular(widget.r)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _RoundedIconBtn extends StatelessWidget {
  final IconData icon; final Color surface, border, iconColor; final VoidCallback onTap;
  const _RoundedIconBtn({required this.icon, required this.surface, required this.border, required this.iconColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Icon(icon, color: iconColor, size: 20),
    ),
  );
}

class _BadgePill extends StatelessWidget {
  final String label; final Color bg;
  const _BadgePill({required this.label, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white, letterSpacing: 0.2)),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label; final Color surface, border, txt1, txt2;
  const _StatCard({required this.value, required this.label, required this.surface, required this.border, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 17, color: txt1, letterSpacing: -0.3)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2, fontWeight: FontWeight.w500)),
    ]),
  ));
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final int idx, cur; final Color txt2;
  final void Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.idx, required this.cur, required this.txt2, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, key: ValueKey(active), size: 24,
              color: active ? AppColors.forestGreen : txt2)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? AppColors.forestGreen : txt2)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE TRANSITION HELPER (shared between files)
// ═══════════════════════════════════════════════════════════════════════════════

PageRoute<T> _campaignRoute<T>(Widget screen) => PageRouteBuilder(
  pageBuilder: (_, animation, __) => screen,
  transitionDuration: const Duration(milliseconds: 400),
  transitionsBuilder: (_, animation, __, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: curved, child: child));
  },
);