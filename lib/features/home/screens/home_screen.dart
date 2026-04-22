import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════

class AppColors {
  static const forestGreen  = Color(0xFF0B5E35);
  static const midGreen     = Color(0xFF1A8C52);
  static const limeGreen    = Color(0xFF4CC97A);
  static const savanna      = Color(0xFFE8A020);
  static const savannaLight = Color(0xFFFFF0CC);
  static const crimson      = Color(0xFFD93025);
  static const sky          = Color(0xFF1877C5);
  static const amber        = Color(0xFFE8860A);
  static const ink          = Color(0xFF0A1A10);
  static const charcoal     = Color(0xFF1C2E22);
  static const slate        = Color(0xFF3D5445);
  static const mist         = Color(0xFF8FA896);
  static const cloud        = Color(0xFFEBF2EE);
  static const snow         = Color(0xFFF5FAF7);
  static const white        = Color(0xFFFFFFFF);
  static const darkBg       = Color(0xFF060E09);
  static const darkCard     = Color(0xFF0D1A11);
  static const darkBorder   = Color(0xFF1C2E22);
  static const darkMist     = Color(0xFF4D6657);

  // Tier colours
  static const tierGold1   = Color(0xFFFFD700);
  static const tierGold2   = Color(0xFFFFA500);
  static const tierSilver1 = Color(0xFFE8E8E8);
  static const tierSilver2 = Color(0xFFB0B0B0);
  static const tierBronze1 = Color(0xFFCD7F32);
  static const tierBronze2 = Color(0xFFA0522D);
}

class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Poppins');
  static TextStyle display(Color c) => _base.copyWith(fontWeight: FontWeight.w900, fontSize: 26, color: c, letterSpacing: -0.5, height: 1.15);
  static TextStyle title(Color c)   => _base.copyWith(fontWeight: FontWeight.w800, fontSize: 17, color: c, letterSpacing: -0.3);
  static TextStyle titleSm(Color c) => _base.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: c, height: 1.35);
  static TextStyle label(Color c)   => _base.copyWith(fontWeight: FontWeight.w600, fontSize: 12, color: c);
  static TextStyle body(Color c)    => _base.copyWith(fontWeight: FontWeight.w400, fontSize: 13, color: c, height: 1.5);
  static TextStyle caption(Color c) => _base.copyWith(fontWeight: FontWeight.w500, fontSize: 11, color: c);
  static TextStyle mono(Color c)    => _base.copyWith(fontWeight: FontWeight.w800, fontSize: 15, color: c);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIER ENUM
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

  Color get shadowColor {
    switch (this) {
      case CampaignTier.gold:   return const Color(0x99FFA500);
      case CampaignTier.silver: return const Color(0x88B0B0B0);
      case CampaignTier.bronze: return const Color(0x88A0522D);
      case CampaignTier.none:   return Colors.transparent;
    }
  }

  static CampaignTier fromMomentum(double score) {
    if (score >= 8.5) return CampaignTier.gold;
    if (score >= 6.5) return CampaignTier.silver;
    if (score >= 4.0) return CampaignTier.bronze;
    return CampaignTier.none;
  }
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
        if (v['\$numberInt'] != null) return double.parse(v['\$numberInt'].toString());
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
    String? creator = c is Map ? c['username']?.toString() : j['username']?.toString() ?? 'Anonymous';
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
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
    const Campaign(id:'1', title:'Help Mama Wanjiku with Cancer Treatment',
      description:'Mama Wanjiku needs urgent support for chemotherapy at KNH. She is a single mother of three.',
      category:'medical', amountRaised:145000, goal:300000, completionPercentage:48.3,
      daysRemaining:14, donorCount:89, urgencyLevel:'high', momentumScore:8.7, creatorName:'James Kamau'),
    const Campaign(id:'2', title:'Kibera School Desks & Books Drive',
      description:'Providing quality desks and learning materials for 200 students in Kibera primary school.',
      category:'education', amountRaised:67500, goal:120000, completionPercentage:56.3,
      daysRemaining:30, donorCount:156, urgencyLevel:'low', momentumScore:6.8, creatorName:'Faith Otieno'),
    const Campaign(id:'3', title:'Flood Relief — Tana River Families',
      description:'Emergency relief for 500+ families displaced by devastating floods in Tana River County.',
      category:'emergencies', amountRaised:312000, goal:400000, completionPercentage:78.0,
      daysRemaining:7, donorCount:423, urgencyLevel:'high', momentumScore:9.1, creatorName:'Red Cross Kenya'),
    const Campaign(id:'4', title:'Borehole for Turkana Community',
      description:'Clean water access for 3,000 people in remote Turkana through a solar-powered borehole.',
      category:'water', amountRaised:230000, goal:450000, completionPercentage:51.1,
      daysRemaining:45, donorCount:201, urgencyLevel:'medium', momentumScore:5.2, creatorName:'WaterAid Kenya'),
    const Campaign(id:'5', title:'Bursary for 12 Students — Kisumu',
      description:'Scholarship fund for bright students from low-income families in Kisumu.',
      category:'education', amountRaised:88000, goal:150000, completionPercentage:58.7,
      daysRemaining:12, donorCount:67, urgencyLevel:'medium', momentumScore:4.2, creatorName:'Kisumu Youth Fund'),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// CROWN + RIBBON MEDAL WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class TierMedalBadge extends StatelessWidget {
  final CampaignTier tier;
  final double size;
  const TierMedalBadge({super.key, required this.tier, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (tier == CampaignTier.none) return const SizedBox.shrink();
    final colors = tier.colors;
    final shadow = tier.shadowColor;
    final circleSize = size;
    final stripW = size * 0.27;
    final stripH = size * 0.46;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Medal disc with crown ─────────────────────────────────────────────
        Container(
          width: circleSize, height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: shadow, blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 3)),
              BoxShadow(color: Colors.white.withOpacity(0.35), blurRadius: 2, offset: const Offset(-1, -1)),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(circleSize * 0.55, circleSize * 0.42),
              painter: _CrownPainter(),
            ),
          ),
        ),
        // ── Ribbon strips ─────────────────────────────────────────────────────
        Transform.translate(
          offset: const Offset(0, -3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RibbonStrip(width: stripW, height: stripH, color: colors[0]),
              const SizedBox(width: 2),
              _RibbonStrip(width: stripW, height: stripH, color: colors[1]),
            ],
          ),
        ),
      ],
    );
  }
}

class _RibbonStrip extends StatelessWidget {
  final double width, height;
  final Color color;
  const _RibbonStrip({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.circular(width * 0.4),
      bottomRight: Radius.circular(width * 0.4),
    ),
    child: Container(width: width, height: height, color: color),
  );
}

// Custom painter for a clean crown silhouette
class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Crown shape: base bar + 3 points
    // Base
    path.moveTo(0, h);
    path.lineTo(w, h);
    // Right down-slope
    path.lineTo(w, h * 0.55);
    // Right peak
    path.lineTo(w * 0.78, h * 0.0);
    // Middle-right slope down
    path.lineTo(w * 0.6, h * 0.48);
    // Centre peak
    path.lineTo(w * 0.5, h * 0.0);
    // Middle-left slope down
    path.lineTo(w * 0.4, h * 0.48);
    // Left peak
    path.lineTo(w * 0.22, h * 0.0);
    // Left down-slope
    path.lineTo(0, h * 0.55);
    path.close();

    canvas.drawPath(path, paint);

    // 3 small circle gems on peaks
    final gemPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final gemR = w * 0.07;
    for (final dx in [w * 0.22, w * 0.5, w * 0.78]) {
      canvas.drawCircle(Offset(dx, gemR * 0.8), gemR, gemPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATED DONATE BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class AnimatedDonateButton extends StatefulWidget {
  final VoidCallback? onDonate;
  final bool compact;
  const AnimatedDonateButton({super.key, this.onDonate, this.compact = false});

  @override
  State<AnimatedDonateButton> createState() => _AnimatedDonateButtonState();
}

class _AnimatedDonateButtonState extends State<AnimatedDonateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() async {
    setState(() => _tapped = true);
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onDonate?.call();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _tapped = false);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: widget.compact ? 38 : 46,
          decoration: BoxDecoration(
            gradient: _tapped
                ? const LinearGradient(colors: [Color(0xFF1A8C52), Color(0xFF4CC97A)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight)
                : const LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(widget.compact ? 12 : 14),
            boxShadow: [
              BoxShadow(
                color: AppColors.midGreen.withOpacity(_tapped ? 0.25 : 0.40),
                blurRadius: _tapped ? 8 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: _tapped
                    ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18, key: ValueKey('check'))
                    : const Text('💚', style: TextStyle(fontSize: 15), key: ValueKey('heart')),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _tapped ? 'Donated! 🎉' : 'Donate Now',
                  key: ValueKey(_tapped),
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                    fontSize: 14, color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  int _navIndex = 0;
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

  late PageController _pageCtrl;

  // Stagger animation controller for list cards
  late AnimationController _listStaggerCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.90);
    _listStaggerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _loadAll();
  }

  // ── colors ────────────────────────────────────────────────────────────────
  Color get bg      => _isDark ? AppColors.darkBg    : AppColors.snow;
  Color get surface => _isDark ? AppColors.darkCard   : AppColors.white;
  Color get border  => _isDark ? AppColors.darkBorder : AppColors.cloud;
  Color get txt1    => _isDark ? AppColors.white      : AppColors.ink;
  Color get txt2    => _isDark ? AppColors.darkMist   : AppColors.slate;
  Color get txtHint => _isDark ? const Color(0xFF3D5445) : AppColors.mist;

  static const _categories = [
    {'label':'All',          'emoji':'🌍'},
    {'label':'medical',      'emoji':'🏥'},
    {'label':'education',    'emoji':'📚'},
    {'label':'community',    'emoji':'🤝'},
    {'label':'emergencies',  'emoji':'🚨'},
    {'label':'water',        'emoji':'💧'},
    {'label':'environment',  'emoji':'🌿'},
  ];

  Future<void> _loadAll() async {
    _loadFeatured();
    _loadCampaigns();
  }

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
      _listStaggerCtrl.forward(from: 0);
    }
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final r = await CampaignService.search(q);
    if (mounted) setState(() { _searchResults = r; _searching = false; });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _listStaggerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _kes(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: _isDark ? Brightness.dark : Brightness.light,
    ));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: _searchActive ? _buildSearch() : _buildMain()),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  // ── SEARCH ───────────────────────────────────────────────────────────────────
  Widget _buildSearch() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.midGreen, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.15), blurRadius: 12, offset: const Offset(0,4))],
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: AppColors.midGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: AppTextStyles.body(txt1),
                  decoration: InputDecoration(
                    hintText: 'Search campaigns, causes…',
                    hintStyle: AppTextStyles.body(txtHint),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) { setState(() => _searchQuery = v); _doSearch(v); },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _searchResults = []; }); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.close_rounded, color: txt2, size: 18),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () { setState(() { _searchActive = false; _searchQuery = ''; _searchResults = []; }); _searchCtrl.clear(); },
          child: Container(
            height: 52, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: Center(child: Text('Cancel', style: AppTextStyles.label(AppColors.midGreen))),
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
                      itemBuilder: (_, i) => _SearchCard(
                        c: _searchResults[i], surface: surface, border: border,
                        txt1: txt1, txt2: txt2, kes: _kes),
                    ),
    ),
  ]);

  Widget _searchHints() {
    final tags = ['medical', 'education', 'water', 'emergencies', 'community', 'borehole'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Popular searches', style: AppTextStyles.title(txt1)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: tags.map((t) => GestureDetector(
          onTap: () { _searchCtrl.text = t; setState(() => _searchQuery = t); _doSearch(t); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.midGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.midGreen.withOpacity(0.25)),
            ),
            child: Text(t, style: AppTextStyles.label(AppColors.midGreen)),
          ),
        )).toList()),
      ]),
    );
  }

  Widget _noResults() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 56, color: txtHint),
      const SizedBox(height: 14),
      Text('No campaigns found', style: AppTextStyles.title(txt1)),
      const SizedBox(height: 6),
      Text('Try a different keyword', style: AppTextStyles.body(txt2)),
    ]),
  );

  // ── MAIN CONTENT ─────────────────────────────────────────────────────────────
  Widget _buildMain() => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: _topBar()),
      SliverToBoxAdapter(child: _searchBar()),
      SliverToBoxAdapter(child: _statsRibbon()),
      SliverToBoxAdapter(child: _sectionLabel('Featured Campaigns')),
      SliverToBoxAdapter(child: _featuredCarousel()),
      SliverToBoxAdapter(child: _categoryRow()),
      SliverToBoxAdapter(child: _sectionLabel('Active Campaigns')),
      if (_loadingCampaigns)
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _SkeletonCard(surface: surface, border: border), childCount: 3))
      else if (_campaigns.isEmpty)
        SliverToBoxAdapter(child: _emptyState())
      else
        SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _StaggeredCard(
            index: i,
            controller: _listStaggerCtrl,
            child: _CampaignCard(
              c: _campaigns[i], isDark: _isDark,
              surface: surface, border: border,
              txt1: txt1, txt2: txt2, txtHint: txtHint, kes: _kes,
            ),
          ),
          childCount: _campaigns.length,
        )),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ],
  );

  // ── Top bar ──────────────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,3))],
          ),
          child: const Center(child: Text('IF', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white))),
        ),
        const SizedBox(width: 8),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Inua', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.forestGreen)),
          TextSpan(text: 'Fund', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, fontSize: 18, color: txt2)),
        ])),
      ]),
      const Spacer(),
      _IconBtn(icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        surface: surface, border: border, iconColor: txt1,
        onTap: () => setState(() => _isDark = !_isDark)),
      const SizedBox(width: 8),
      Stack(children: [
        _IconBtn(icon: Icons.notifications_outlined, surface: surface, border: border, iconColor: txt1, onTap: () {}),
        Positioned(top: 9, right: 9,
          child: Container(width: 8, height: 8,
            decoration: BoxDecoration(
              color: AppColors.crimson, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.crimson.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
            ))),
      ]),
      const SizedBox(width: 8),
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('E', style: TextStyle(fontFamily:'Poppins', fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white))),
      ),
    ]),
  );

  // ── Search bar ───────────────────────────────────────────────────────────────
  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: GestureDetector(
      onTap: () => setState(() => _searchActive = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0,3))],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: txtHint, size: 20),
          const SizedBox(width: 10),
          Text('Search campaigns, causes…', style: AppTextStyles.body(txtHint)),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(color: AppColors.forestGreen, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 15),
          ),
        ]),
      ),
    ),
  );

  // ── Stats ribbon ─────────────────────────────────────────────────────────────
  Widget _statsRibbon() {
    final totalRaised = _campaigns.fold<double>(0, (s, c) => s + c.amountRaised);
    final totalDonors = _campaigns.fold<int>(0, (s, c) => s + c.donorCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.forestGreen, AppColors.midGreen, AppColors.limeGreen],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.forestGreen.withOpacity(0.45), blurRadius: 22, offset: const Offset(0,8))],
        ),
        child: Row(children: [
          _StatChip(icon: '🎯', label: 'Campaigns', value: _campaigns.isEmpty ? '—' : _campaigns.length.toString()),
          _Vline(),
          _StatChip(icon: '📈', label: 'Raised', value: _kes(totalRaised)),
          _Vline(),
          _StatChip(icon: '❤️', label: 'Donors',
            value: totalDonors > 1000 ? '${(totalDonors/1000).toStringAsFixed(1)}K' : totalDonors.toString()),
        ]),
      ),
    );
  }

  // ── Featured carousel ────────────────────────────────────────────────────────
  Widget _featuredCarousel() => Column(children: [
    SizedBox(
      height: 250,
      child: _loadingFeatured
          ? _featuredShimmer()
          : _featured.isEmpty ? const SizedBox()
          : PageView.builder(
              controller: _pageCtrl,
              itemCount: _featured.length,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemBuilder: (_, i) => _FeaturedCard(c: _featured[i], kes: _kes),
            ),
    ),
    if (!_loadingFeatured && _featured.isNotEmpty) ...[
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_featured.length, (i) =>
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _carouselPage == i ? 24 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: _carouselPage == i ? AppColors.midGreen : border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )),
    ],
  ]);

  Widget _featuredShimmer() => ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    itemCount: 2,
    itemBuilder: (_, __) => _ShimmerBox(w: 300, h: 230, radius: 24, surface: surface, border: border),
  );

  // ── Category chips ───────────────────────────────────────────────────────────
  Widget _categoryRow() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final sel = _selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () { setState(() => _selectedCategory = cat['label'] as String); _loadCampaigns(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.forestGreen : surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel ? AppColors.forestGreen : border),
                boxShadow: sel
                    ? [BoxShadow(color: AppColors.forestGreen.withOpacity(0.35), blurRadius: 10, offset: const Offset(0,4))]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cat['emoji'] as String, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(cat['label'] as String, style: AppTextStyles.label(sel ? AppColors.white : txt2)),
              ]),
            ),
          );
        },
      ),
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
    child: Column(children: [
      const Text('🌿', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('No campaigns yet', style: AppTextStyles.title(txt1), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('Be the first to start a campaign in this category', style: AppTextStyles.body(txt2), textAlign: TextAlign.center),
    ]),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(label, style: AppTextStyles.title(txt1)),
    ]),
  );

  // ── Bottom nav ───────────────────────────────────────────────────────────────
  Widget _buildNav() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    decoration: BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: border, width: 0.8)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.5 : 0.07), blurRadius: 20, offset: const Offset(0,-4))],
    ),
    child: SafeArea(
      child: SizedBox(
        height: 64,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavBtn(icon: Icons.home_rounded,            label: 'Home',    idx: 0, cur: _navIndex, txt2: txt2, onTap: (i) => setState(() => _navIndex = i)),
          _NavBtn(icon: Icons.explore_outlined,        label: 'Explore', idx: 1, cur: _navIndex, txt2: txt2, onTap: (i) => setState(() => _navIndex = i)),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.5), blurRadius: 16, offset: const Offset(0,5))],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
          _NavBtn(icon: Icons.notifications_outlined, label: 'Alerts',  idx: 3, cur: _navIndex, txt2: txt2, onTap: (i) => setState(() => _navIndex = i)),
          _NavBtn(icon: Icons.person_outline_rounded, label: 'Profile', idx: 4, cur: _navIndex, txt2: txt2, onTap: (i) => setState(() => _navIndex = i)),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGGERED LIST ANIMATION WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _StaggeredCard extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _StaggeredCard({required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.12).clamp(0.0, 0.8);
    final end   = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, __) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURED CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _FeaturedCard extends StatelessWidget {
  final Campaign c;
  final String Function(double) kes;
  const _FeaturedCard({required this.c, required this.kes});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: c.categoryGradient[0].withOpacity(0.4), blurRadius: 22, offset: const Offset(0,10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          // Background
          if (c.featuredImage != null)
            Positioned.fill(child: Image.network(c.featuredImage!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientBg(c.categoryGradient)))
          else
            Positioned.fill(child: _gradientBg(c.categoryGradient)),
          // Dark scrim
          Positioned.fill(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.78), Colors.black.withOpacity(0.08)],
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
              ),
            ),
          )),
          // Kenyan-pattern accent top bar
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.savanna, AppColors.limeGreen, AppColors.savanna]),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Badges + tier medal
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c.urgencyLevel == 'high') ...[
                  _Pill(label: '🔥 URGENT', bg: AppColors.crimson.withOpacity(0.9)),
                  const SizedBox(width: 6),
                ],
                if (c.momentumScore > 7)
                  _Pill(label: '⚡ Trending', bg: AppColors.amber.withOpacity(0.9)),
                const Spacer(),
                // Tier medal badge
                if (c.tier != CampaignTier.none)
                  TierMedalBadge(tier: c.tier, size: 30),
              ]),
              const Spacer(),
              // Creator
              if (c.creatorName != null)
                Row(children: [
                  const Icon(Icons.person_outline_rounded, color: Colors.white60, size: 12),
                  const SizedBox(width: 4),
                  Text('by ${c.creatorName}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white60)),
                ]),
              const SizedBox(height: 4),
              // Title
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white, height: 1.3)),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value: val,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(AppColors.savanna),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Amounts row
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kes(c.amountRaised), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  Text('of ${kes(c.goal)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white60)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${c.completionPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.savanna)),
                  Text('${c.daysRemaining}d left',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white60)),
                ]),
              ]),
              const SizedBox(height: 12),
              // ── DONATE BUTTON inside featured card ──────────────────────────
              const AnimatedDonateButton(compact: true),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _gradientBg(List<Color> colors) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPAIGN LIST CARD  —  donate button INSIDE the card
// ═══════════════════════════════════════════════════════════════════════════════

class _CampaignCard extends StatelessWidget {
  final Campaign c;
  final bool isDark;
  final Color surface, border, txt1, txt2, txtHint;
  final String Function(double) kes;
  const _CampaignCard({required this.c, required this.isDark, required this.surface,
    required this.border, required this.txt1, required this.txt2, required this.txtHint, required this.kes});

  @override
  Widget build(BuildContext context) {
    final progress = (c.completionPercentage / 100).clamp(0.0, 1.0);
    final urgent = c.daysRemaining <= 7;
    final barColor = urgent ? c.urgencyColor : AppColors.midGreen;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgent ? c.urgencyColor.withOpacity(0.35) : border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.05), blurRadius: 14, offset: const Offset(0,4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top accent strip
          Container(height: 4,
            decoration: BoxDecoration(gradient: LinearGradient(colors: c.categoryGradient))),

          // Campaign image
          if (c.featuredImage != null)
            SizedBox(height: 130, width: double.infinity,
              child: Image.network(c.featuredImage!, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null ? child
                    : Container(height: 130, color: AppColors.midGreen.withOpacity(0.08)),
                errorBuilder: (_, __, ___) => Container(height: 70,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: c.categoryGradient.map((e) => e.withOpacity(0.15)).toList()))))),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title + category pill + tier medal
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm(txt1))),
                const SizedBox(width: 8),
                // Category pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.categoryGradient[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c.category, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: c.categoryGradient[0])),
                ),
                // Tier medal next to pill
                if (c.tier != CampaignTier.none) ...[
                  const SizedBox(width: 6),
                  TierMedalBadge(tier: c.tier, size: 26),
                ],
              ]),

              // Creator
              if (c.creatorName != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: txtHint),
                  const SizedBox(width: 4),
                  Text('by ${c.creatorName}', style: AppTextStyles.caption(txtHint)),
                ]),
              ],

              const SizedBox(height: 14),

              // Progress bar — animated
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: val,
                    backgroundColor: border,
                    valueColor: AlwaysStoppedAnimation(barColor),
                    minHeight: 8,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Raised / days
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kes(c.amountRaised), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.forestGreen)),
                  Text('of ${kes(c.goal)}', style: AppTextStyles.caption(txt2)),
                ]),
                const Spacer(),
                _urgencyBadge(urgent),
              ]),

              const SizedBox(height: 8),

              // Donors + percentage
              Row(children: [
                Icon(Icons.people_outline_rounded, size: 13, color: txtHint),
                const SizedBox(width: 4),
                Text('${c.donorCount} donors', style: AppTextStyles.caption(txtHint)),
                const Spacer(),
                Text('${c.completionPercentage.toStringAsFixed(0)}% funded',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.midGreen)),
              ]),

              const SizedBox(height: 14),

              // ── DONATE BUTTON — inside the card, not a separate strip ───────
              const SizedBox(width: double.infinity, child: AnimatedDonateButton()),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _urgencyBadge(bool urgent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: urgent ? c.urgencyColor.withOpacity(0.1) : AppColors.cloud.withOpacity(0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: urgent ? c.urgencyColor.withOpacity(0.3) : Colors.transparent),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(urgent ? Icons.local_fire_department_rounded : Icons.schedule_rounded,
        size: 12, color: urgent ? c.urgencyColor : AppColors.mist),
      const SizedBox(width: 4),
      Text('${c.daysRemaining}d left',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700,
          color: urgent ? c.urgencyColor : AppColors.mist)),
    ]),
  );
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
      Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.categoryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(_emoji(c.category), style: const TextStyle(fontSize: 22))),
          ),
          if (c.tier != CampaignTier.none)
            Positioned(bottom: -6, right: -6,
              child: TierMedalBadge(tier: c.tier, size: 20)),
        ],
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.titleSm(txt1)),
        const SizedBox(height: 3),
        Text(c.category, style: AppTextStyles.caption(AppColors.midGreen)),
      ])),
      const SizedBox(width: 10),
      Text(kes(c.goal), style: AppTextStyles.mono(AppColors.forestGreen)),
    ]),
  );

  String _emoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'medical':     return '🏥';
      case 'education':   return '📚';
      case 'water':       return '💧';
      case 'emergencies': return '🚨';
      case 'community':   return '🤝';
      case 'environment': return '🌿';
      default:            return '🌍';
    }
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
  late AnimationController _ac;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      height: 160,
      decoration: BoxDecoration(
        color: widget.surface.withOpacity(0.4 + _anim.value * 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.border),
      ),
    ),
  );
}

class _ShimmerBox extends StatefulWidget {
  final double w, h, radius;
  final Color surface, border;
  const _ShimmerBox({required this.w, required this.h, required this.radius, required this.surface, required this.border});
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.w, height: widget.h,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: widget.surface.withOpacity(0.4 + _anim.value * 0.4),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.border),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SMALL SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color surface, border, iconColor;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.surface, required this.border, required this.iconColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42, height: 42,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Icon(icon, color: iconColor, size: 20),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  const _Pill({required this.label, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _StatChip extends StatelessWidget {
  final String icon, label, value;
  const _StatChip({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500)),
    ]),
  );
}

class _Vline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 42, color: Colors.white.withOpacity(0.2));
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final Color txt2;
  final void Function(int) onTap;
  const _NavBtn({required this.icon, required this.label, required this.idx, required this.cur, required this.txt2, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, key: ValueKey(active), size: 24,
              color: active ? AppColors.forestGreen : txt2),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? AppColors.forestGreen : txt2,
          )),
        ]),
      ),
    );
  }
}
