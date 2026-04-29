// explore_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

// ── Re-use AppColors & Campaign model from home_screen.dart ──────────────────
// (paste or import from home_screen.dart in your project)

class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF4F6F4);
  static const white       = Color(0xFFFFFFFF);
  static const crimson     = Color(0xFFD93025);
  static const amber       = Color(0xFFE8860A);
  static const mist        = Color(0xFF8FA896);
  static const darkMist    = Color(0xFF4D6657);
}

// ── Lightweight Campaign model ───────────────────────────────────────────────
class _Camp {
  final String id, title, category;
  final double raised, goal, pct;
  final int days, donors;
  final String? image, creator, urgency;

  const _Camp({
    required this.id, required this.title, required this.category,
    required this.raised, required this.goal, required this.pct,
    required this.days, required this.donors,
    this.image, this.creator, this.urgency,
  });

  factory _Camp.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is Map) { final i = v['\$numberInt']; if (i != null) return double.parse(i.toString()); }
      return double.tryParse(v.toString()) ?? 0;
    }
    final raised = n(j['amountRaised'] ?? j['currentAmount']);
    final goal   = n(j['goal']);
    final pct    = goal > 0 ? (raised / goal * 100).clamp(0.0, 100.0) : 0.0;
    int days = 0;
    if (j['endDate'] != null) {
      try { days = DateTime.parse(j['endDate'].toString()).difference(DateTime.now()).inDays.clamp(0, 9999); } catch (_) {}
    }
    final c = j['creator_Id'] ?? j['creator'];
    return _Camp(
      id: j['_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      category: j['category']?.toString() ?? 'General',
      raised: raised, goal: goal, pct: pct, days: days,
      donors: n(j['donorCount'] ?? j['donorsCount']).toInt(),
      image: j['featuredImage']?.toString(),
      creator: c is Map ? c['username']?.toString() : j['username']?.toString(),
      urgency: j['urgencyLevel']?.toString() ?? 'low',
    );
  }

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
}

// ── API ───────────────────────────────────────────────────────────────────────
class _Api {
  static const _base = 'https://api.inuafund.co.ke/api';
  static const _h    = {'Accept': 'application/json'};

  static Future<List<_Camp>> fetch({String? category, String? search, int page = 1}) async {
    final q = <String, String>{
      'status': 'approved', 'limit': '20', 'page': '$page',
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    try {
      final r = await http.get(Uri.parse('$_base/campaigns').replace(queryParameters: q), headers: _h)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        final list = (d is Map ? (d['data'] ?? d['campaigns']) : d) as List? ?? [];
        return list.map((e) => _Camp.fromJson(e)).where((c) => c.title.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }
}

// ── Categories ────────────────────────────────────────────────────────────────
const _kCats = [
  {'label': 'All',         'icon': Icons.apps_rounded,               'color': Color(0xFF1A8C52)},
  {'label': 'medical',     'icon': Icons.favorite_rounded,           'color': Color(0xFFD93025)},
  {'label': 'education',   'icon': Icons.school_rounded,             'color': Color(0xFF1565C0)},
  {'label': 'emergencies', 'icon': Icons.warning_amber_rounded,      'color': Color(0xFFE8860A)},
  {'label': 'environment', 'icon': Icons.eco_rounded,                'color': Color(0xFF2E7D32)},
  {'label': 'community',   'icon': Icons.people_rounded,             'color': Color(0xFF6A1B9A)},
  {'label': 'water',       'icon': Icons.water_drop_rounded,         'color': Color(0xFF006064)},
  {'label': 'technology',  'icon': Icons.devices_rounded,            'color': Color(0xFF1976D2)},
  {'label': 'agriculture', 'icon': Icons.local_florist_rounded,      'color': Color(0xFF388E3C)},
  {'label': 'animals',     'icon': Icons.pets_rounded,               'color': Color(0xFFF57C00)},
  {'label': 'arts',        'icon': Icons.palette_rounded,            'color': Color(0xFFAD1457)},
  {'label': 'business',    'icon': Icons.business_rounded,           'color': Color(0xFF455A64)},
  {'label': 'competitions','icon': Icons.emoji_events_rounded,       'color': Color(0xFFF9A825)},
  {'label': 'faith',       'icon': Icons.church_rounded,             'color': Color(0xFF5D4037)},
  {'label': 'travel',      'icon': Icons.flight_rounded,             'color': Color(0xFF0288D1)},
  {'label': 'volunteer',   'icon': Icons.handshake_rounded,          'color': Color(0xFF00897B)},
  {'label': 'wishes',      'icon': Icons.star_rounded,               'color': Color(0xFFFFB300)},
  {'label': 'nonprofit',   'icon': Icons.volunteer_activism_rounded, 'color': Color(0xFF43A047)},
  {'label': 'family',      'icon': Icons.family_restroom_rounded,    'color': Color(0xFFE91E63)},
  {'label': 'memorial',    'icon': Icons.local_florist_rounded,      'color': Color(0xFF78909C)},
  {'label': 'events',      'icon': Icons.event_rounded,              'color': Color(0xFF8E24AA)},
  {'label': 'creative',    'icon': Icons.lightbulb_rounded,          'color': Color(0xFFFF6F00)},
];

// ═══════════════════════════════════════════════════════════════════════════════
// ExploreScreen
// ═══════════════════════════════════════════════════════════════════════════════
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  // State
  String _cat = 'All';
  String _searchQ = '';
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<_Camp> _camps = [];
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  // View toggle: grid / list
  bool _gridView = true;

  // Sort options
  String _sort = 'recent';

  // Animations
  late final AnimationController _headerCtrl;
  late final AnimationController _listCtrl;
  late final Animation<double> _headerSlide;
  late final Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _listCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerSlide = Tween<double>(begin: -30, end: 0).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn);
    _headerCtrl.forward();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) { setState(() { _loading = true; _camps = []; _page = 1; _hasMore = true; }); }
    final data = await _Api.fetch(category: _cat == 'All' ? null : _cat, search: _searchQ, page: _page);
    if (!mounted) return;
    setState(() {
      _camps = _sorted(data);
      _loading = false;
      _hasMore = data.length == 20;
    });
    _listCtrl.forward(from: 0);
  }

  Future<void> _loadMore() async {
    setState(() { _loadingMore = true; _page++; });
    final data = await _Api.fetch(category: _cat == 'All' ? null : _cat, search: _searchQ, page: _page);
    if (!mounted) return;
    setState(() { _camps = _sorted([..._camps, ...data]); _loadingMore = false; _hasMore = data.length == 20; });
  }

  List<_Camp> _sorted(List<_Camp> list) => switch (_sort) {
    'pct'     => [...list]..sort((a, b) => b.pct.compareTo(a.pct)),
    'donors'  => [...list]..sort((a, b) => b.donors.compareTo(a.donors)),
    'urgent'  => [...list]..sort((a, b) => a.days.compareTo(b.days)),
    _         => list,
  };

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () { setState(() => _searchQ = v); _load(); });
  }

  void _onCat(String c) { setState(() => _cat = c); _load(); }

  String _kes(double v) {
    if (v >= 1e6) return 'KES ${(v/1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return 'KES ${(v/1e3).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  @override
  void dispose() {
    _headerCtrl.dispose(); _listCtrl.dispose();
    _searchCtrl.dispose(); _scrollCtrl.dispose(); _debounce?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarBrightness: Brightness.light));
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        _buildSearch(),
        _buildCategoryChips(),
        _buildSortBar(),
        Expanded(child: _buildBody()),
      ])),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() => AnimatedBuilder(
    animation: _headerCtrl,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, _headerSlide.value),
      child: Opacity(opacity: _headerFade.value,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cloud),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Explore Impactful Campaigns', style: TextStyle(
                fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800,
                color: AppColors.ink, letterSpacing: -0.5)),
              Text('${_camps.length > 0 ? _camps.length : "..."} campaigns found',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.mist)),
            ])),
            // View toggle
            _ToggleBtn(
              icon: _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              onTap: () => setState(() => _gridView = !_gridView),
            ),
          ]),
        ),
      ),
    ),
  );

  // ── Search ────────────────────────────────────────────────────────────────
  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cloud),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, color: AppColors.mist, size: 20),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.ink),
          decoration: const InputDecoration(
            hintText: 'Search campaigns, causes…',
            hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.mist),
            border: InputBorder.none, isDense: true,
          ),
        )),
        if (_searchQ.isNotEmpty)
          GestureDetector(
            onTap: () { _searchCtrl.clear(); setState(() => _searchQ = ''); _load(); },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.close_rounded, size: 18, color: AppColors.mist)),
          )
        else
          const SizedBox(width: 14),
      ]),
    ),
  );

  // ── Category Chips ────────────────────────────────────────────────────────
  Widget _buildCategoryChips() => SizedBox(
    height: 52,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      itemCount: _kCats.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final cat = _kCats[i];
        final label = cat['label'] as String;
        final icon  = cat['icon'] as IconData;
        final color = cat['color'] as Color;
        final sel   = _cat == label;
        return GestureDetector(
          onTap: () => _onCat(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? color : AppColors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: sel ? color : AppColors.cloud, width: sel ? 0 : 1),
              boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,3))] :
                              [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: sel ? Colors.white : AppColors.mist),
              const SizedBox(width: 5),
              Text(_cap(label), style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11,
                color: sel ? Colors.white : AppColors.darkMist)),
            ]),
          ),
        );
      },
    ),
  );

  // ── Sort Bar ──────────────────────────────────────────────────────────────
  Widget _buildSortBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
    child: Row(children: [
      const Text('Sort:', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.mist, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      ...[('recent', 'Recent'), ('pct', '% Funded'), ('donors', 'Donors'), ('urgent', 'Urgent')].map((s) {
        final sel = _sort == s.$1;
        return GestureDetector(
          onTap: () { setState(() => _sort = s.$1); _load(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? AppColors.midGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? AppColors.midGreen : AppColors.cloud),
            ),
            child: Text(s.$2, style: TextStyle(
              fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : AppColors.mist)),
          ),
        );
      }),
    ]),
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_camps.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: AppColors.midGreen,
      onRefresh: () => _load(),
      child: _gridView ? _buildGrid() : _buildList(),
    );
  }

  Widget _buildGrid() => GridView.builder(
    controller: _scrollCtrl,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
    itemCount: _camps.length + (_loadingMore ? 2 : 0),
    itemBuilder: (_, i) {
      if (i >= _camps.length) return _ShimmerCard();
      return _StaggerCard(index: i, ctrl: _listCtrl, child: _GridCard(c: _camps[i], kes: _kes, onTap: () => context.push('/campaigns/${_camps[i].id}')));
    },
  );

  Widget _buildList() => ListView.builder(
    controller: _scrollCtrl,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    itemCount: _camps.length + (_loadingMore ? 1 : 0),
    itemBuilder: (_, i) {
      if (i >= _camps.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 2)));
      return _StaggerCard(index: i, ctrl: _listCtrl, child: _ListCard(c: _camps[i], kes: _kes, onTap: () => context.push('/campaigns/${_camps[i].id}')));
    },
  );

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🌿', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 14),
    const Text('No campaigns found', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
    const SizedBox(height: 6),
    const Text('Try a different category or keyword', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.mist)),
    const SizedBox(height: 20),
    GestureDetector(
      onTap: () { setState(() { _cat = 'All'; _searchQ = ''; _searchCtrl.clear(); }); _load(); },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(50)),
        child: const Text('Clear filters', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white))),
    ),
  ]));

  Widget _buildShimmer() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
    itemCount: 6, itemBuilder: (_, __) => _ShimmerCard(),
  );

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Grid Card ─────────────────────────────────────────────────────────────────
class _GridCard extends StatefulWidget {
  final _Camp c; final String Function(double) kes; final VoidCallback onTap;
  const _GridCard({required this.c, required this.kes, required this.onTap});
  @override State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  late final Animation<double> _scale  = Tween<double>(begin: 1, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final progress = (c.pct / 100).clamp(0.0, 1.0);
    final urgent = c.days <= 7 && c.days > 0;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: urgent ? AppColors.crimson.withOpacity(0.2) : AppColors.cloud),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0,3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Image / gradient
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(children: [
                SizedBox(height: 120, width: double.infinity,
                  child: c.image != null
                    ? Image.network(c.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _GradBox(colors: c.gradient))
                    : _GradBox(colors: c.gradient)),
                // Overlay
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.5, 1])))),
                // Category pill
                Positioned(top: 8, left: 8, child: _Pill(label: c.category, color: c.gradient[0])),
                if (urgent) Positioned(top: 8, right: 8, child: _Pill(label: 'URGENT', color: AppColors.crimson)),
                // Icon
                Positioned(bottom: 8, right: 8,
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(c.icon, color: Colors.white, size: 16))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12,
                    color: AppColors.ink, height: 1.3)),
                const SizedBox(height: 8),
                // Progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: v, minHeight: 5,
                        backgroundColor: AppColors.cloud,
                        valueColor: AlwaysStoppedAnimation(urgent ? AppColors.crimson : AppColors.midGreen))),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(widget.kes(c.raised), style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                        fontSize: 11, color: urgent ? AppColors.crimson : AppColors.midGreen)),
                      const Spacer(),
                      Text('${c.pct.toStringAsFixed(0)}%',
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 10, color: AppColors.mist)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people_outline_rounded, size: 11, color: AppColors.mist),
                  const SizedBox(width: 3),
                  Text('${c.donors}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.mist)),
                  const Spacer(),
                  const Icon(Icons.access_time_rounded, size: 11, color: AppColors.mist),
                  const SizedBox(width: 3),
                  Text('${c.days}d', style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                    color: urgent ? AppColors.crimson : AppColors.mist)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── List Card ─────────────────────────────────────────────────────────────────
class _ListCard extends StatelessWidget {
  final _Camp c; final String Function(double) kes; final VoidCallback onTap;
  const _ListCard({required this.c, required this.kes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (c.pct / 100).clamp(0.0, 1.0);
    final urgent = c.days <= 7 && c.days > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: urgent ? AppColors.crimson.withOpacity(0.2) : AppColors.cloud),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          // Thumbnail
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 76, height: 76,
              child: c.image != null
                ? Image.network(c.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _GradBox(colors: c.gradient))
                : _GradBox(colors: c.gradient, icon: c.icon))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Pill(label: c.category, color: c.gradient[0], small: true),
              if (urgent) ...[const SizedBox(width: 4), _Pill(label: 'URGENT', color: AppColors.crimson, small: true)],
            ]),
            const SizedBox(height: 5),
            Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink, height: 1.3)),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: AppColors.cloud,
                  valueColor: AlwaysStoppedAnimation(urgent ? AppColors.crimson : AppColors.midGreen)))),
            const SizedBox(height: 6),
            Row(children: [
              Text(kes(c.raised), style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12,
                color: urgent ? AppColors.crimson : AppColors.midGreen)),
              Text(' / ${kes(c.goal)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.mist)),
              const Spacer(),
              Text('${c.days}d left', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11,
                color: urgent ? AppColors.crimson : AppColors.mist)),
            ]),
          ])),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mist, size: 20),
        ])),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _GradBox extends StatelessWidget {
  final List<Color> colors; final IconData? icon;
  const _GradBox({required this.colors, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: icon != null ? Center(child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 28)) : null,
  );
}

class _Pill extends StatelessWidget {
  final String label; final Color color; final bool small;
  const _Pill({required this.label, required this.color, this.small = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 2 : 4),
    decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
    child: Text(label.toUpperCase(), style: TextStyle(
      fontFamily: 'Poppins', fontWeight: FontWeight.w700,
      fontSize: small ? 8 : 9, color: Colors.white, letterSpacing: 0.3)),
  );
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cloud),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))]),
      child: Icon(icon, size: 20, color: AppColors.ink)),
  );
}

class _ShimmerCard extends StatefulWidget {
  @override State<_ShimmerCard> createState() => _ShimmerCardState();
}
class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _ac,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.5 + _ac.value * 0.4),
        borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cloud)),
    ));
}

class _StaggerCard extends StatelessWidget {
  final int index; final AnimationController ctrl; final Widget child;
  const _StaggerCard({required this.index, required this.ctrl, required this.child});
  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.65);
    final end   = (start + 0.35).clamp(0.0, 1.0);
    final anim  = CurvedAnimation(parent: ctrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(animation: anim, builder: (_, __) => Opacity(opacity: anim.value,
      child: Transform.translate(offset: Offset(0, 20 * (1 - anim.value)), child: child)));
  }
}