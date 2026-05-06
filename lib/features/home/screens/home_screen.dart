// ═══════════════════════════════════════════════════════════════════════════════
// home_screen.dart  — updated
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/auth_service.dart';
import '../../campaign/screens/create_campaign.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────

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

  static const tierGold1   = Color(0xFFFFD700);
  static const tierGold2   = Color(0xFFFFA500);
  static const tierSilver1 = Color(0xFFE8E8E8);
  static const tierSilver2 = Color(0xFFB0B0B0);
  static const tierBronze1 = Color(0xFFCD7F32);
  static const tierBronze2 = Color(0xFFA0522D);
}

// ─── Tier ────────────────────────────────────────────────────────────────────

enum CampaignTier { gold, silver, bronze, none }

extension CampaignTierExt on CampaignTier {
  List<Color> get colors => switch (this) {
    CampaignTier.gold   => [AppColors.tierGold1, AppColors.tierGold2],
    CampaignTier.silver => [AppColors.tierSilver1, AppColors.tierSilver2],
    CampaignTier.bronze => [AppColors.tierBronze1, AppColors.tierBronze2],
    CampaignTier.none   => [],
  };
  Color get glowColor => switch (this) {
    CampaignTier.gold   => const Color(0xAAFFA500),
    CampaignTier.silver => const Color(0x88B0B0B0),
    CampaignTier.bronze => const Color(0x88A0522D),
    CampaignTier.none   => Colors.transparent,
  };
  static CampaignTier fromMomentum(double s) =>
    s >= 8.0 ? CampaignTier.gold : s >= 6.0 ? CampaignTier.silver : s >= 3.5 ? CampaignTier.bronze : CampaignTier.none;
}

// ─── Medal Badge ─────────────────────────────────────────────────────────────

class TierMedalBadge extends StatelessWidget {
  final CampaignTier tier;
  final double size;
  const TierMedalBadge({super.key, required this.tier, this.size = 28});

  @override
  Widget build(BuildContext context) {
    if (tier == CampaignTier.none) return const SizedBox.shrink();
    final c = tier.colors;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: tier.glowColor, blurRadius: 8, spreadRadius: 1)],
      ),
      child: Center(child: CustomPaint(size: Size(size * 0.5, size * 0.38), painter: _CrownPainter())),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.93)..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    canvas.drawPath(Path()
      ..moveTo(0, h)..lineTo(w, h)
      ..lineTo(w, h * 0.52)..lineTo(w * 0.78, 0)
      ..lineTo(w * 0.60, h * 0.46)..lineTo(w * 0.50, 0)
      ..lineTo(w * 0.40, h * 0.46)..lineTo(w * 0.22, 0)
      ..lineTo(0, h * 0.52)..close(), p);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Model ───────────────────────────────────────────────────────────────────

class Campaign {
  final String id, title, description, category, urgencyLevel;
  final double amountRaised, goal, completionPercentage, momentumScore;
  final int daysRemaining, donorCount;
  final String? featuredImage, creatorName;

  const Campaign({
    required this.id, required this.title, required this.description,
    required this.category, required this.amountRaised, required this.goal,
    required this.completionPercentage, this.momentumScore = 0,
    required this.daysRemaining, required this.donorCount,
    this.featuredImage, this.creatorName, this.urgencyLevel = 'low',
  });

  CampaignTier get tier => CampaignTierExt.fromMomentum(momentumScore);

  Color get urgencyColor => switch (urgencyLevel) {
    'high'   => AppColors.crimson,
    'medium' => AppColors.amber,
    _        => AppColors.midGreen,
  };

  List<Color> get gradient => switch (category.toLowerCase()) {
    'medical'     => [const Color(0xFF0B5E35), const Color(0xFF1A8C52)],
    'education'   => [const Color(0xFF1565C0), const Color(0xFF1877C5)],
    'emergencies' => [const Color(0xFFB71C1C), const Color(0xFFD93025)],
    'water'       => [const Color(0xFF006064), const Color(0xFF00838F)],
    'environment' => [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
    'community'   => [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
    _             => [AppColors.forestGreen, AppColors.midGreen],
  };

  IconData get icon => switch (category.toLowerCase()) {
    'medical'     => Icons.favorite_rounded,
    'education'   => Icons.school_rounded,
    'emergencies' => Icons.warning_amber_rounded,
    'water'       => Icons.water_drop_rounded,
    'environment' => Icons.eco_rounded,
    'community'   => Icons.people_rounded,
    _             => Icons.volunteer_activism_rounded,
  };

  factory Campaign.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is Map) {
        final i = v['\$numberInt']; if (i != null) return double.parse(i.toString());
        final d = v['\$numberDouble']; if (d != null) return double.parse(d.toString());
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
}

// ─── Service ─────────────────────────────────────────────────────────────────

class CampaignService {
  static const _base = 'https://api.inuafund.co.ke/api';
  static const _h    = {'Accept': 'application/json'};

  static Future<List<Campaign>> fetchFeatured() async {
    try {
      final r = await http.get(Uri.parse('$_base/campaigns/featured'), headers: _h).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        return ((d is Map ? d['data'] : d) as List? ?? []).map((e) => Campaign.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Campaign>> fetchAll({String? category}) async {
    try {
      final uri = Uri.parse('$_base/campaigns').replace(queryParameters: {
        'status': 'approved',
        if (category != null && category != 'All') 'category': category,
        'limit': '20',
      });
      final r = await http.get(uri, headers: _h).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        return ((d is Map ? (d['data'] ?? d['campaigns']) : d) as List? ?? [])
            .map((e) => Campaign.fromJson(e)).where((c) => c.title.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Campaign>> search(String q) async {
    try {
      final r = await http.get(
        Uri.parse('$_base/campaigns?search=${Uri.encodeComponent(q)}'), headers: _h,
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        return ((d is Map ? d['data'] : d) as List? ?? []).map((e) => Campaign.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }
}

// ─── Category data ────────────────────────────────────────────────────────────
const _kCategories = [
  {'label': 'All',         'icon': Icons.apps_rounded},
  {'label': 'business',    'icon': Icons.business_rounded},
  {'label': 'community',   'icon': Icons.people_rounded},
  {'label': 'education',   'icon': Icons.school_rounded},
  {'label': 'agriculture', 'icon': Icons.local_florist_rounded},
  {'label': 'animals',     'icon': Icons.pets_rounded},
  {'label': 'arts',        'icon': Icons.palette_rounded},
  {'label': 'competitions','icon': Icons.emoji_events_rounded},
  {'label': 'creative',    'icon': Icons.lightbulb_rounded},
  {'label': 'emergencies', 'icon': Icons.warning_amber_rounded},
  {'label': 'environment', 'icon': Icons.eco_rounded},
  {'label': 'events',      'icon': Icons.event_rounded},
  {'label': 'faith',       'icon': Icons.church_rounded},
  {'label': 'family',      'icon': Icons.family_restroom_rounded},
  {'label': 'medical',     'icon': Icons.favorite_rounded},
  {'label': 'memorial',    'icon': Icons.local_florist_rounded},
  {'label': 'non-profit',  'icon': Icons.volunteer_activism_rounded},
  {'label': 'technology',  'icon': Icons.devices_rounded},
  {'label': 'travel',      'icon': Icons.flight_rounded},
  {'label': 'volunteer',   'icon': Icons.handshake_rounded},
  {'label': 'water',       'icon': Icons.water_drop_rounded},
  {'label': 'wishes',      'icon': Icons.star_rounded},
];

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  String _selectedCategory = 'All';
  int _carouselPage = 0;

  List<Campaign> _featured = [];
  List<Campaign> _campaigns = [];
  bool _loadingFeatured = true;
  bool _loadingCampaigns = true;
  bool _hasError = false;

  bool _searchActive = false;
  String _searchQuery = '';
  List<Campaign> _searchResults = [];
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  late final PageController _pageCtrl;
  late final AnimationController _listCtrl;
  Timer? _autoScrollTimer;

  Color get bg      => AppColors.snow;
  Color get surface => AppColors.white;
  Color get border  => AppColors.cloud;
  Color get txt1    => AppColors.ink;
  Color get txt2    => const Color(0xFF6B7280);
  Color get txtHint => const Color(0xFFB0B8BF);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadFeatured();
    _loadCampaigns();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_featured.isNotEmpty && !_loadingFeatured) {
        final nextPage = (_carouselPage + 1) % _featured.length;
        _pageCtrl.animateToPage(nextPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> _loadFeatured() async {
    setState(() { _loadingFeatured = true; });
    final d = await CampaignService.fetchFeatured();
    if (mounted) {
      setState(() { _featured = d; _loadingFeatured = false; });
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() { _loadingCampaigns = true; _hasError = false; });
    final d = await CampaignService.fetchAll(category: _selectedCategory);
    if (mounted) {
      setState(() { _campaigns = d; _loadingCampaigns = false; _hasError = d.isEmpty; });
      _listCtrl.forward(from: 0);
    }
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final r = await CampaignService.search(q);
    if (mounted) setState(() { _searchResults = r; _searching = false; });
  }

  void _openCreate() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      _showAuthSheet();
      return;
    }
    final user = auth.user!;
    Navigator.push(context, _slideRoute(StartCampaignScreen(
      isDark: false, authToken: auth.token,
      userId: user.id, username: user.username,
      userEmail: user.email, userPhone: user.phoneNumber,
    )));
  }

  void _openCampaign(Campaign c) {
    context.push('/campaigns/${c.id}');
  }

  void _showAuthSheet() => showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    builder: (_) => _AuthSheet(
      surface: surface, border: border, txt1: txt1, txt2: txt2,
      onLogin: () { Navigator.pop(context); context.push('/login'); }),
  );

  void _onNav(int idx) {
    if (idx == 0) { setState(() => _navIndex = 0); return; }
    setState(() => _navIndex = idx);
    switch (idx) {
      case 1: context.push('/explore');
      case 3: context.push('/alerts');
      case 4: context.push('/profile');
    }
  }

  void _onCategoryTap(String label) {
    setState(() => _selectedCategory = label);
    _loadCampaigns();
  }

  @override
  void dispose() { _pageCtrl.dispose(); _listCtrl.dispose(); _searchCtrl.dispose(); _autoScrollTimer?.cancel(); super.dispose(); }

  String _kes(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: _searchActive ? _buildSearch() : _buildMain()),
      // ── No floating FAB — it lives inside the BottomAppBar ──
      // bottomNavigationBar: _searchActive ? null : _buildNav(),
    );
  }

  // ── Search View ───────────────────────────────────────────────────────────
  Widget _buildSearch() => Column(children: [
    // Uniform search bar — single flat container, no bar-in-bar
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.midGreen, width: 1.6),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: AppColors.midGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt1),
                decoration: InputDecoration(
                  hintText: 'Search campaigns, causes…',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txtHint),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) { setState(() => _searchQuery = v); _doSearch(v); },
              )),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _searchResults = []; }); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, color: txt2, size: 18),
                  ),
                )
              else
                const SizedBox(width: 14),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            setState(() { _searchActive = false; _searchQuery = ''; _searchResults = []; });
            _searchCtrl.clear();
          },
          child: const Text('Cancel',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.midGreen)),
        ),
      ]),
    ),
    const SizedBox(height: 12),
    Expanded(
      child: _searching
          ? const Center(child: CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 2))
          : _searchQuery.length < 2
              ? _searchHints()
              : _searchResults.isEmpty
                  ? _noResults()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _openCampaign(_searchResults[i]),
                        child: _SearchCard(
                          c: _searchResults[i], surface: surface,
                          border: border, txt1: txt1, txt2: txt2, kes: _kes),
                      ),
                    ),
    ),
  ]);

  Widget _searchHints() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Popular searches', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: txt1)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: ['medical', 'education', 'water', 'emergencies', 'community', 'borehole'].map((t) =>
        GestureDetector(
          onTap: () { _searchCtrl.text = t; setState(() => _searchQuery = t); _doSearch(t); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.midGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.midGreen.withOpacity(0.2)),
            ),
            child: Text(t, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.midGreen)),
          ),
        ),
      ).toList()),
    ]),
  );

  Widget _noResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.search_off_rounded, size: 48, color: txtHint),
    const SizedBox(height: 10),
    Text('No results found', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: txt1)),
    const SizedBox(height: 4),
    Text('Try another keyword', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2)),
  ]));

  // ── Main Scroll View ──────────────────────────────────────────────────────
  Widget _buildMain() => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: _topBar()),
      SliverToBoxAdapter(child: _searchBar()),
      SliverToBoxAdapter(child: _sectionLabel('Featured campaigns')),
      SliverToBoxAdapter(child: _featuredCarousel()),
      // ── Browse by Category section ──
      SliverToBoxAdapter(child: _sectionLabel('Browse by Category')),
      SliverToBoxAdapter(child: _categoryGrid()),
      SliverToBoxAdapter(child: _campaignsHeader()),
      if (_loadingCampaigns)
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _Skeleton(surface: surface, border: border), childCount: 4))
      else if (_campaigns.isEmpty)
        SliverToBoxAdapter(child: _emptyState())
      else
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _StaggerItem(
            index: i, ctrl: _listCtrl,
            child: GestureDetector(
              onTap: () => _openCampaign(_campaigns[i]),
              child: _CampaignCard(
                c: _campaigns[i], surface: surface, border: border,
                txt1: txt1, txt2: txt2, txtHint: txtHint, kes: _kes),
            ),
          ),
          childCount: _campaigns.length,
        )),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ],
  );

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _topBar() {
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.username ?? auth.user?.fullName ?? 'Guest';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
          const SizedBox(height: 1),
          Row(children: [
            Text(name, style: TextStyle(fontFamily: 'Poppins', fontSize: 18, color: txt1, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Text('👋', style: TextStyle(fontSize: 16)),
          ]),
        ])),
        Stack(clipBehavior: Clip.none, children: [
          _IconBtn(icon: Icons.notifications_outlined, onTap: () => _onNav(3), surface: surface, border: border, color: txt1),
          Positioned(top: 8, right: 8,
            child: Container(width: 8, height: 8,
              decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle,
                border: Border.all(color: surface, width: 1.2)))),
        ]),
      ]),
    );
  }

  // ── Uniform Search Bar (tap-to-open) ─────────────────────────────────────
  // Single flat container — no nested pill or second bar inside.
  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: GestureDetector(
      onTap: () => setState(() => _searchActive = true),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: txtHint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Search campaigns, causes…',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txtHint)),
          ),
          // Filter icon pill — right-aligned, no extra container border
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.midGreen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tune_rounded, color: AppColors.midGreen, size: 14),
                const SizedBox(width: 4),
                const Text('Filter',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.midGreen)),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );

  // ── Section Label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
    child: Row(children: [
      Container(width: 3, height: 17,
        decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
        fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16, color: txt1, letterSpacing: -0.2)),
      if (trailing != null) ...[const Spacer(), trailing],
    ]),
  );

  // ── Featured Carousel ─────────────────────────────────────────────────────
  Widget _featuredCarousel() => Column(children: [
    SizedBox(
      height: 200,
      child: _loadingFeatured
          ? _shimmer()
          : _featured.isEmpty
              ? const SizedBox()
              : PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _featured.length,
                  onPageChanged: (i) => setState(() => _carouselPage = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openCampaign(_featured[i]),
                    child: _FeaturedCard(c: _featured[i], kes: _kes, txt2: txt2),
                  ),
                ),
    ),
    if (!_loadingFeatured && _featured.isNotEmpty) ...[
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_featured.length, (i) =>
        AnimatedContainer(
          duration: const Duration(milliseconds: 260), curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _carouselPage == i ? 20 : 6, height: 6,
          decoration: BoxDecoration(
            color: _carouselPage == i ? AppColors.midGreen : border,
            borderRadius: BorderRadius.circular(4)),
        ),
      )),
    ],
  ]);

  Widget _shimmer() => ListView.builder(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
    itemCount: 2, itemBuilder: (_, __) => _ShimmerBox(w: 280, h: 180, r: 16, surface: surface));

 // ── Browse by Category – horizontal oval chips ──────────────────────────
  // ── Browse by Category – staggered 3-row oval chips ─────────────────────
Widget _categoryGrid() {
  // Split categories into 3 rows as evenly as possible
  final int total = _kCategories.length;
  final int rowSize = (total / 3).ceil();

  final List<List<Map<String, dynamic>>> rows = [
    _kCategories.sublist(0, rowSize).cast<Map<String, dynamic>>(),
    _kCategories.sublist(rowSize, (rowSize * 2).clamp(0, total)).cast<Map<String, dynamic>>(),
    _kCategories.sublist((rowSize * 2).clamp(0, total), total).cast<Map<String, dynamic>>(),
  ];

  // Offsets to create the staggered / non-linear feel
  final List<double> rowOffsets = [0, 24, 10];

  Widget buildChip(Map<String, dynamic> cat) {
    final label = cat['label'] as String;
    final icon  = cat['icon'] as IconData;
    final sel   = _selectedCategory == label;

    return GestureDetector(
      onTap: () => _onCategoryTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.midGreen : surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: sel ? AppColors.midGreen : border,
            width: sel ? 1.5 : 1,
          ),
          boxShadow: sel
              ? [BoxShadow(
                  color: AppColors.midGreen.withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )]
              : [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: sel ? Colors.white : txt2),
            const SizedBox(width: 5),
            Text(
              _capFirst(label),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: sel ? Colors.white : txt2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return SizedBox(
    height: 130, // enough for 3 rows + spacing + offsets
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(rows.length, (rowIndex) {
          return Padding(
            padding: EdgeInsets.only(
              top: rowIndex == 0 ? 0 : 8,
              left: rowOffsets[rowIndex], // stagger each row
            ),
            child: Row(
              children: rows[rowIndex].map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: buildChip(cat),
                );
              }).toList(),
            ),
          );
        }),
      ),
    ),
  );
}

  String _capFirst(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ── Campaigns Header ──────────────────────────────────────────────────────
  Widget _campaignsHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Row(children: [
      Container(width: 3, height: 17,
        decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Expanded(child: Text(
        _selectedCategory == 'All' ? 'Active campaigns' : '${_capFirst(_selectedCategory)} campaigns',
        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16, color: txt1),
      )),
      GestureDetector(
        onTap: () => _onNav(1),
        child: const Text('See all',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.midGreen)),
      ),
    ]),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
    child: Column(children: [
      const Text('🌿', style: TextStyle(fontSize: 44)),
      const SizedBox(height: 12),
      Text('No campaigns yet', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: txt1), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('Be the first in this category', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2), textAlign: TextAlign.center),
    ]),
  );


} // ← closes _HomeScreenState


// ─── Nav Arch Painter — draws the arch/loop cutout outline ───────────────────

class _NavArchPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  const _NavArchPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 32.0; // circle radius + margin

    // Fill path: rectangle with circular arch cutout at top
    final fillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, r * 0.7)
      ..arcToPoint(Offset(w, r * 0.7),
          radius: const Radius.circular(r + 4),
          clockwise: false)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = color);

    // Draw only the curved top border
    final borderPath = Path()
      ..moveTo(0, r * 0.7)
      ..arcToPoint(Offset(w, r * 0.7),
          radius: const Radius.circular(r + 4),
          clockwise: false);

    canvas.drawPath(
      borderPath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _NavArchPainter old) =>
      old.color != color || old.borderColor != borderColor;
}

// ─── Auth Sheet ───────────────────────────────────────────────────────────────

class _AuthSheet extends StatelessWidget {
  final Color surface, border, txt1, txt2;
  final VoidCallback onLogin;
  const _AuthSheet({required this.surface, required this.border, required this.txt1, required this.txt2, required this.onLogin});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 22),
      Container(width: 68, height: 68,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.midGreen.withOpacity(0.08)),
        child: const Icon(Icons.lock_outline_rounded, color: AppColors.midGreen, size: 32)),
      const SizedBox(height: 18),
      Text('Sign in to create', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18, color: txt1)),
      const SizedBox(height: 6),
      Text('You need an account to start a campaign.', textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forestGreen, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            elevation: 0),
          child: const Text('Sign in / Register',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
        )),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Not now',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13, color: txt2))),
    ]),
  );
}

// ─── Featured Card ────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Campaign c;
  final String Function(double) kes;
  final Color txt2;
  const _FeaturedCard({required this.c, required this.kes, required this.txt2});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Positioned.fill(
          child: c.featuredImage != null
              ? Image.network(c.featuredImage!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _grad())
              : _grad(),
        ),
        Positioned.fill(child: Container(decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.3, 1.0]),
        ))),
        Positioned(left: 14, right: 14, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (c.urgencyLevel == 'high') ...[
              _Pill(label: 'URGENT', bg: AppColors.crimson), const SizedBox(width: 6),
            ],
            _Pill(label: c.category.toUpperCase(), bg: AppColors.midGreen.withOpacity(0.9)),
          ]),
          const SizedBox(height: 6),
          Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white, height: 1.2)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.limeGreen)))),
          const SizedBox(height: 6),
          Row(children: [
            Text(kes(c.amountRaised), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.limeGreen)),
            Text(' / ${kes(c.goal)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white60)),
            const Spacer(),
            Text('${c.daysRemaining}d left', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white70)),
          ]),
        ])),
        if (c.tier != CampaignTier.none)
          Positioned(top: 12, right: 12, child: TierMedalBadge(tier: c.tier, size: 30)),
      ]),
    );
  }

  Widget _grad() => Container(decoration: BoxDecoration(
    gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)));
}

// ─── Campaign Card ────────────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  final Campaign c;
  final Color surface, border, txt1, txt2, txtHint;
  final String Function(double) kes;
  const _CampaignCard({required this.c, required this.surface, required this.border,
    required this.txt1, required this.txt2, required this.txtHint, required this.kes});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    final urgent   = c.daysRemaining <= 7;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgent ? c.urgencyColor.withOpacity(0.25) : border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: c.featuredImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.network(c.featuredImage!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Icon(c.icon, color: Colors.white.withOpacity(0.85), size: 28))))
                  : Center(child: Icon(c.icon, color: Colors.white.withOpacity(0.85), size: 28)),
            ),
            if (c.tier != CampaignTier.none)
              Positioned(bottom: -5, left: -4, child: TierMedalBadge(tier: c.tier, size: 22)),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.gradient[0].withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
                child: Text(c.category.toUpperCase(),
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 9, color: c.gradient[0])),
              ),
              if (urgent) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                  child: const Text('URGENT',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 9, color: AppColors.crimson)),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: txt1, height: 1.3)),
            if (c.creatorName != null) ...[
              const SizedBox(height: 3),
              Text('by ${c.creatorName}', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2)),
            ],
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: border,
                  valueColor: AlwaysStoppedAnimation(urgent ? c.urgencyColor : AppColors.midGreen)))),
            const SizedBox(height: 6),
            Row(children: [
              Text(kes(c.amountRaised),
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.midGreen)),
              Text(' / ${kes(c.goal)}', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2)),
              const Spacer(),
              Text('${c.daysRemaining}d left',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11,
                  color: urgent ? AppColors.crimson : txtHint)),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ─── Search Card ──────────────────────────────────────────────────────────────

class _SearchCard extends StatelessWidget {
  final Campaign c;
  final Color surface, border, txt1, txt2;
  final String Function(double) kes;
  const _SearchCard({required this.c, required this.surface, required this.border,
    required this.txt1, required this.txt2, required this.kes});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
    child: Row(children: [
      Container(width: 46, height: 46,
        decoration: BoxDecoration(gradient: LinearGradient(colors: c.gradient), borderRadius: BorderRadius.circular(10)),
        child: Center(child: Icon(c.icon, color: Colors.white, size: 22))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: txt1)),
        Text(c.category,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.midGreen)),
      ])),
      const SizedBox(width: 8),
      Text(kes(c.goal),
        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.forestGreen)),
    ]),
  );
}

// ─── Stagger Animation ────────────────────────────────────────────────────────

class _StaggerItem extends StatelessWidget {
  final int index; final AnimationController ctrl; final Widget child;
  const _StaggerItem({required this.index, required this.ctrl, required this.child});
  @override
  Widget build(BuildContext context) {
    final start = (index * 0.09).clamp(0.0, 0.72);
    final end   = (start + 0.36).clamp(0.0, 1.0);
    final anim  = CurvedAnimation(parent: ctrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - anim.value)), child: child)),
    );
  }
}

// ─── Skeleton / Shimmer ───────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  final Color surface, border;
  const _Skeleton({required this.surface, required this.border});
  @override State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  late final Animation<double> _a = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (_, __) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12), height: 96,
    decoration: BoxDecoration(
      color: widget.surface.withOpacity(0.4 + _a.value * 0.4),
      borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.border)),
  ));
}

class _ShimmerBox extends StatefulWidget {
  final double w, h, r; final Color surface;
  const _ShimmerBox({required this.w, required this.h, required this.r, required this.surface});
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  late final Animation<double> _a = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (_, __) => Container(
    width: widget.w, height: widget.h, margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(color: widget.surface.withOpacity(0.4 + _a.value * 0.4),
      borderRadius: BorderRadius.circular(widget.r)),
  ));
}

// ─── Small Reusable Widgets ───────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color surface, border, color;
  const _IconBtn({required this.icon, required this.onTap, required this.surface, required this.border, required this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: border)),
      child: Icon(icon, color: color, size: 20)),
  );
}

class _Pill extends StatelessWidget {
  final String label; final Color bg;
  const _Pill({required this.label, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
    child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white, letterSpacing: 0.2)),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final int idx, cur; final Color txt2;
  final void Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.idx,
    required this.cur, required this.txt2, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: active ? AppColors.forestGreen : txt2),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? AppColors.forestGreen : txt2)),
      ]),
    );
  }
}

// ─── Page Transition ──────────────────────────────────────────────────────────

PageRoute<T> _slideRoute<T>(Widget screen) => PageRouteBuilder(
  pageBuilder: (_, a, __) => screen,
  transitionDuration: const Duration(milliseconds: 380),
  transitionsBuilder: (_, a, __, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(c),
      child: FadeTransition(opacity: c, child: child));
  },
);