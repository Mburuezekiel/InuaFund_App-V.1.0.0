// single_campaign_screen.dart — InuaFund v2 · Senior UI/UX · Compact
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../donation/screens/donation_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _fg   = Color(0xFF0B5E35);
const _mg   = Color(0xFF1A8C52);
const _lime = Color(0xFF4CC97A);
const _red  = Color(0xFFD93025);
const _amb  = Color(0xFFE8860A);
const _ink  = Color(0xFF0D0D0D);
const _mist = Color(0xFF8FA896);
const _snow = Color(0xFFF4F6F4);
const _card = Color(0xFFFFFFFF);
const _bdr  = Color(0xFFE5EBE7);
const _g1   = Color(0xFFFFD700);
const _g2   = Color(0xFFFFA500);

// ── Tier ──────────────────────────────────────────────────────────────────────
enum Tier { gold, silver, bronze, none }
extension TierX on Tier {
  List<Color> get cols => switch (this) {
    Tier.gold   => [_g1, _g2],
    Tier.silver => [const Color(0xFFE8E8E8), const Color(0xFFB0B0B0)],
    Tier.bronze => [const Color(0xFFCD7F32), const Color(0xFFA0522D)],
    Tier.none   => [_bdr, _mist],
  };
  Color get glow => switch (this) {
    Tier.gold   => const Color(0x55FFA500),
    Tier.silver => const Color(0x44B0B0B0),
    Tier.bronze => const Color(0x44A0522D),
    Tier.none   => Colors.transparent,
  };
  static Tier of(double s) => s >= 8 ? Tier.gold : s >= 6 ? Tier.silver : s >= 3.5 ? Tier.bronze : Tier.none;
}

// ── Model ─────────────────────────────────────────────────────────────────────
class Campaign {
  final String id, title, desc, cat, currency, status;
  final double raised, goal, pct, momentum;
  final int donors, days;
  final String? img, creator, email, phone, type, loc, end, start,
      approval, timeStatus, urgency;
  final List<String> gallery;
  final List<Map<String, dynamic>> recentDonors, updates;
  
  final dynamic featuredImage;

  const Campaign({
    required this.id, required this.title, required this.desc,
    required this.cat, required this.currency, required this.status,
    required this.raised, required this.goal, required this.pct,
    required this.donors, required this.days,
    this.momentum = 0, this.img,this.featuredImage, this.creator, this.email, this.phone,
    this.type, this.loc, this.end, this.start, this.approval,
    this.timeStatus, this.urgency = 'low',
    this.gallery = const [], this.recentDonors = const [], this.updates = const [],
  });

  bool get canDonate => approval == 'approved' && timeStatus == 'ongoing';
  bool get urgent    => days <= 7;
  Tier get tier      => TierX.of(momentum);

  List<Color> get grad => switch (cat.toLowerCase()) {
    'medical'     => [const Color(0xFF0B5E35), const Color(0xFF1A8C52)],
    'education'   => [const Color(0xFF1565C0), const Color(0xFF1877C5)],
    'emergencies' => [const Color(0xFFB71C1C), _red],
    'water'       => [const Color(0xFF006064), const Color(0xFF00838F)],
    'environment' => [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
    'community'   => [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
    _             => [_fg, _mg],
  };

  IconData get icon => switch (cat.toLowerCase()) {
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
      if (v is num) return v.toDouble();
      if (v is Map) return double.tryParse((v['\$numberInt'] ?? v['\$numberDouble'] ?? '0').toString()) ?? 0;
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }
    final raised = n(j['amountRaised']), goal = n(j['goal']);
    final now = DateTime.now();
    final endDt   = j['endDate']   != null ? DateTime.tryParse(j['endDate'].toString()) : null;
    final startDt = j['startDate'] != null ? DateTime.tryParse(j['startDate'].toString()) : null;
    String ts = 'ongoing';
    if (endDt != null && now.isAfter(endDt)) ts = 'ended';
    else if (startDt != null && now.isBefore(startDt)) ts = 'upcoming';
    final cr = j['creator'];
    return Campaign(
      id: j['_id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      desc: j['description']?.toString() ?? '',
      cat: j['category']?.toString() ?? 'General',
      currency: j['currency']?.toString() ?? 'KES',
      status: j['status']?.toString() ?? 'active',
      raised: raised, goal: goal,
      pct: goal > 0 ? (raised / goal * 100).clamp(0, 100) : 0,
      momentum: n(j['momentumScore']),
      donors: n(j['donorsCount'] ?? j['donorCount']).toInt(),
      days: n(j['daysRemaining']).toInt(),
      img: j['featuredImage']?.toString(),
      creator: cr is Map ? cr['username']?.toString() : j['username']?.toString(),
      email: j['contactEmail']?.toString(),
      phone: j['contactPhone']?.toString(),
      type: j['campaignType']?.toString(),
      loc: j['location']?.toString(),
      end:   endDt   != null ? '${endDt.day}/${endDt.month}/${endDt.year}' : null,
      start: startDt != null ? '${startDt.day}/${startDt.month}/${startDt.year}' : null,
      approval: j['approvalStatus']?.toString() ?? 'pending',
      timeStatus: ts, urgency: j['urgencyLevel']?.toString() ?? 'low',
      featuredImage: j['featuredImage']?.toString(),
      gallery: (j['gallery'] as List?)?.whereType<String>().toList() ?? [],
      recentDonors: (j['recentDonors'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
      updates: (j['updates'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
class CampaignService {
  static const _base = 'https://api.inuafund.co.ke/api';
  static const _h = {'Accept': 'application/json'};

  static Future<Campaign?> fetch(String id, {String? token}) async {
    try {
      final h = {..._h, if (token != null) 'Authorization': 'Bearer $token'};
      final r = await http.get(Uri.parse('$_base/campaigns/$id'), headers: h)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['status'] == 'success' && d['data'] != null)
          return Campaign.fromJson(d['data']);
      }
    } catch (e) { debugPrint('$e'); }
    return null;
  }

  static Future<List<Campaign>> similar(String cat, String excl) async {
    try {
      final r = await http.get(
        Uri.parse('$_base/campaigns?category=$cat&limit=6'), headers: _h)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        final raw = (d is Map ? (d['data'] ?? d['campaigns']) : d) as List? ?? [];
        return raw.whereType<Map<String, dynamic>>()
            .where((m) => m['_id']?.toString() != excl)
            .take(3).map(Campaign.fromJson).toList();
      }
    } catch (e) { debugPrint('$e'); }
    return [];
  }
}

// ── Atoms ─────────────────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  final Color bg, fg; final double size;
  const _Btn({required this.icon, required this.onTap, this.bg = _card,
      this.fg = _ink, this.size = 40});
  @override
  Widget build(_) => GestureDetector(onTap: onTap,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: size * 0.48)));
}

class _Pill extends StatelessWidget {
  final String label; final Color bg, fg; final IconData? icon;
  const _Pill(this.label, {required this.bg, required this.fg, this.icon});
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 10, color: fg), const SizedBox(width: 3)],
      Text(label, style: TextStyle(fontFamily: 'Poppins',
          fontWeight: FontWeight.w800, fontSize: 9, color: fg, letterSpacing: 0.4)),
    ]));
}

class _TierBadge extends StatelessWidget {
  final Tier tier; final double size;
  const _TierBadge(this.tier, {this.size = 26});
  @override
  Widget build(_) {
    if (tier == Tier.none) return const SizedBox.shrink();
    return Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: tier.cols,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: tier.glow, blurRadius: 8)]),
      child: Icon(Icons.star_rounded, color: Colors.white, size: size * 0.46));
  }
}

Widget _surfCard({required Widget child, double pad = 18, double r = 20}) =>
    Container(padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(r),
        border: Border.all(color: _bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 3))]),
      child: child);

// ── Main Screen ───────────────────────────────────────────────────────────────
class SingleCampaignScreen extends StatefulWidget {
  final String campaignId; final String? token;
  const SingleCampaignScreen({super.key, required this.campaignId, this.token});
  @override State<SingleCampaignScreen> createState() => _SCState();
}

class _SCState extends State<SingleCampaignScreen> with SingleTickerProviderStateMixin {
  Campaign? _c; List<Campaign> _sim = [];
  bool _loading = true; String? _err;
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _ac.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    final c = await CampaignService.fetch(widget.campaignId, token: widget.token);
    if (!mounted) return;
    if (c != null) {
      final sim = await CampaignService.similar(c.cat, c.id);
      if (mounted) { setState(() { _c = c; _sim = sim; _loading = false; }); _ac.forward(from: 0); }
    } else {
      setState(() { _loading = false; _err = 'Campaign not found.'; });
    }
  }

  String _fmt(double v, {String? cur}) {
    final c = cur ?? _c?.currency ?? 'KES';
    if (v >= 1e6) return '$c ${(v/1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '$c ${(v/1e3).toStringAsFixed(0)}K';
    return '$c ${v.toStringAsFixed(0)}';
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
    backgroundColor: _mg, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(seconds: 2)));

  void _share() {
    Clipboard.setData(ClipboardData(text: 'https://inuafund.co.ke/campaigns/${widget.campaignId}'));
    _snack('Link copied ✓');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
    if (_loading) return _loadPage();
    if (_err != null || _c == null) return _errPage();
    return _mainPage();
  }

  Widget _loadPage() => const Scaffold(backgroundColor: _snow,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _mg, strokeWidth: 2.5),
      SizedBox(height: 16),
      Text('Loading…', style: TextStyle(fontFamily: 'Poppins', color: _mist, fontSize: 13)),
    ])));

  Widget _errPage() => Scaffold(backgroundColor: _snow,
    body: Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: _red.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, color: _red, size: 36)),
        const SizedBox(height: 20),
        const Text('Oops!', style: TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w800, fontSize: 22, color: _ink)),
        const SizedBox(height: 8),
        Text(_err!, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _mist)),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: _fg,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      ]))));

  Widget _mainPage() {
    final c = _c!;
    final imgs = [if (c.img != null) c.img!, ...c.gallery];
    final prog = (c.pct / 100).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _snow,
      bottomNavigationBar: c.canDonate ? _BottomBar(c: c, fmt: _fmt, onDonate: _donate) : null,
      body: FadeTransition(opacity: _fade,
        child: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: _Hero(c: c, imgs: imgs,
              onBack: () => Navigator.pop(context), onShare: _share)),

          SliverToBoxAdapter(child: Container(
            decoration: const BoxDecoration(color: _snow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Title block
                Row(children: [
                  _Pill(c.cat.toUpperCase(), bg: c.grad[0].withOpacity(0.10), fg: c.grad[0]),
                  if (c.urgent) ...[const SizedBox(width: 6),
                    _Pill('URGENT', bg: _red.withOpacity(0.09), fg: _red, icon: Icons.flash_on_rounded)],
                  const Spacer(), _TierBadge(c.tier, size: 28),
                ]),
                const SizedBox(height: 10),
                Text(c.title, style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 22, color: _ink, height: 1.25)),
                if (c.creator != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(width: 20, height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_mg.withOpacity(0.7), _fg],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Center(child: Text(c.creator![0].toUpperCase(),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 9, color: Colors.white)))),
                    const SizedBox(width: 6),
                    Text('by ${c.creator}', style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: _mist)),
                    if (c.loc != null) ...[const SizedBox(width: 8),
                      const Icon(Icons.location_on_rounded, size: 11, color: _mist),
                      Text(c.loc!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _mist))],
                  ]),
                ],

                const SizedBox(height: 16),

                // ── Progress
                _surfCard(child: _Progress(c: c, prog: prog, fmt: _fmt)),
                const SizedBox(height: 12),

                // ── Actions
                _Actions(c: c, onDonate: _donate, onShare: _share),
                const SizedBox(height: 20),

                // ── Sections
                _Sec('About this Campaign', Icons.info_outline_rounded,
                    _ExpandText(text: c.desc)),
                _Sec('Campaign Details', Icons.list_alt_rounded, _InfoRows(c: c)),
                _Sec('Organiser', Icons.account_circle_outlined,
                    _Organiser(c: c,
                      onEmail: c.email != null ? () {
                        Clipboard.setData(ClipboardData(text: c.email!)); _snack('Email copied ✓');
                      } : null,
                      onPhone: c.phone != null ? () {
                        Clipboard.setData(ClipboardData(text: c.phone!)); _snack('Phone copied ✓');
                      } : null)),
                if (imgs.length > 1) _Sec('Gallery', Icons.photo_library_outlined,
                    _Gallery(imgs: imgs)),
                _Sec('Community & Support', Icons.people_outline_rounded,
                    _Community(c: c, fmt: _fmt, onDonate: _donate)),
                _Sec('Updates', Icons.campaign_outlined, _Updates(c: c)),

                if (c.days > 0) ...[const SizedBox(height: 4), _UrgencyBanner(c: c)],
                const SizedBox(height: 24),

                // ── Similar
                if (_sim.isNotEmpty) ...[
                  _SecLabel('You Might Also Like', Icons.explore_outlined),
                  const SizedBox(height: 12),
                  ..._sim.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _SimCard(c: s, fmt: (v) => _fmt(v, cur: s.currency),
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (_) => SingleCampaignScreen(
                              campaignId: s.id, token: widget.token)))))),
                ],
                const SizedBox(height: 120),
              ]),
            ))),
        ]),
      ),
    );
  }

  void _donate() {
    if (_c == null || !_c!.canDonate) return;
    Navigator.push(context, _slide(DonationScreen(campaign: _c!, token: widget.token)));
  }
}

// ── Section wrappers ──────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String t; final IconData ic; final Widget child;
  const _Sec(this.t, this.ic, this.child);
  @override
  Widget build(_) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: _surfCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SecLabel(t, ic), const SizedBox(height: 14), child,
    ])));
}

class _SecLabel extends StatelessWidget {
  final String t; final IconData ic;
  const _SecLabel(this.t, this.ic);
  @override
  Widget build(_) => Row(children: [
    Container(padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: _mg.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
      child: Icon(ic, color: _mg, size: 15)),
    const SizedBox(width: 10),
    Expanded(child: Text(t, style: const TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 15, color: _ink))),
  ]);
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatefulWidget {
  final Campaign c; final List<String> imgs;
  final VoidCallback onBack, onShare;
  const _Hero({required this.c, required this.imgs, required this.onBack, required this.onShare});
  @override State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  int _i = 0; final _pc = PageController();
  @override void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SizedBox(height: 310, child: Stack(fit: StackFit.expand, children: [
      widget.imgs.isNotEmpty
          ? PageView.builder(controller: _pc, itemCount: widget.imgs.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => Image.network(widget.imgs[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _gradBg(c)))
          : _gradBg(c),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.05), Colors.transparent,
              Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.82)],
          stops: const [0, 0.3, 0.7, 1.0],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
      SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _Btn(icon: Icons.arrow_back_rounded, onTap: widget.onBack,
              bg: Colors.black38, fg: Colors.white),
          const Spacer(),
          _Btn(icon: Icons.share_rounded, onTap: widget.onShare,
              bg: Colors.black38, fg: Colors.white),
        ]))),
      Positioned(left: 16, right: 16, bottom: 18, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (widget.imgs.length > 1) ...[
          Row(children: List.generate(widget.imgs.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 220), margin: const EdgeInsets.only(right: 4),
            width: _i == i ? 22 : 6, height: 4,
            decoration: BoxDecoration(color: _i == i ? _lime : Colors.white30,
                borderRadius: BorderRadius.circular(3))))),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.32),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: Row(children: [
              const Icon(Icons.people_rounded, size: 11, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${c.donors} supporters', style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            ])),
          const SizedBox(width: 8),
          if (c.urgent) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.flash_on_rounded, size: 10, color: Colors.white), SizedBox(width: 3),
              Text('URGENT', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800, fontSize: 9, color: Colors.white)),
            ])),
          const Spacer(),
          if (c.days > 0) Text('${c.days}d left', style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white70)),
        ]),
      ])),
    ]));
  }

  Widget _gradBg(Campaign c) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: c.grad, begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Icon(c.icon, color: Colors.white.withOpacity(0.18), size: 90)));
}

// ── Progress ──────────────────────────────────────────────────────────────────
class _Progress extends StatelessWidget {
  final Campaign c; final double prog;
  final String Function(double, {String? cur}) fmt;
  const _Progress({required this.c, required this.prog, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final ug = c.urgent; final col = ug ? _red : _fg;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fmt(c.raised), style: TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w800, fontSize: 26, color: col, height: 1.1)),
          Text('of ${fmt(c.goal)}', style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: _mist)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: col.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: col.withOpacity(0.15))),
          child: Column(children: [
            Text('${c.pct.toStringAsFixed(1)}%', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 20, color: col, height: 1.1)),
            Text('funded', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 10, color: col.withOpacity(0.7))),
          ])),
      ]),
      const SizedBox(height: 16),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: prog), duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(children: [
          Container(height: 8, decoration: BoxDecoration(
              color: ug ? _red.withOpacity(0.10) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8))),
          FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0),
            child: Container(height: 8, decoration: BoxDecoration(
              gradient: LinearGradient(colors: ug ? [_amb, _red] : [_lime, _fg]),
              borderRadius: BorderRadius.circular(8)))),
          FractionallySizedBox(widthFactor: v.clamp(0.03, 1.0),
            child: Align(alignment: Alignment.centerRight,
              child: Container(width: 14, height: 14, decoration: BoxDecoration(
                  color: col, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5))))),
        ])),
      const SizedBox(height: 14),
      Row(children: [
        _chip(Icons.people_rounded, '${c.donors} donors', _mg),
        const Spacer(),
        if (c.days > 0) _chip(Icons.timer_outlined, '${c.days}d left', ug ? _red : _amb),
      ]),
    ]);
  }

  Widget _chip(IconData ic, String label, Color col) => Row(children: [
    Container(padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: col.withOpacity(0.09), borderRadius: BorderRadius.circular(7)),
      child: Icon(ic, size: 13, color: col)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w600, fontSize: 12, color: col)),
  ]);
}

// ── Actions ───────────────────────────────────────────────────────────────────
class _Actions extends StatelessWidget {
  final Campaign c; final VoidCallback onDonate, onShare;
  const _Actions({required this.c, required this.onDonate, required this.onShare});
  @override
  Widget build(_) => Row(children: [
    Expanded(child: c.canDonate
      ? SizedBox(height: 52, child: ElevatedButton.icon(onPressed: onDonate,
          icon: const Icon(Icons.favorite_rounded, size: 17),
          label: const Text('Donate Now', style: TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w700, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: _fg, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))
      : Container(height: 52,
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline_rounded, color: _red, size: 15), SizedBox(width: 7),
            Text('Not accepting donations', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 12, fontWeight: FontWeight.w600, color: _red)),
          ]))),
    const SizedBox(width: 10),
    SizedBox(width: 100, height: 52,
      child: OutlinedButton.icon(onPressed: onShare,
        icon: const Icon(Icons.share_rounded, size: 15, color: _mg),
        label: const Text('Share', style: TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 13, color: _mg)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: _mg, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
  ]);
}

// ── Expandable text ───────────────────────────────────────────────────────────
class _ExpandText extends StatefulWidget {
  final String text;
  const _ExpandText({required this.text});
  @override State<_ExpandText> createState() => _ExpandTextState();
}
class _ExpandTextState extends State<_ExpandText> {
  bool _x = false;
  @override
  Widget build(_) {
    const lim = 280; final needs = widget.text.length > lim;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedCrossFade(
        firstChild: Text('${widget.text.substring(0, lim.clamp(0, widget.text.length))}${needs && !_x ? '…' : ''}',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _ink, height: 1.7)),
        secondChild: Text(widget.text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _ink, height: 1.7)),
        crossFadeState: _x ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 300)),
      if (needs) ...[
        const SizedBox(height: 10),
        GestureDetector(onTap: () => setState(() => _x = !_x),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(color: _mg.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _mg.withOpacity(0.14))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_x ? 'Show less' : 'Read more', style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _mg)),
              const SizedBox(width: 3),
              AnimatedRotation(turns: _x ? 0.5 : 0, duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: _mg, size: 15)),
            ]))),
      ],
    ]);
  }
}

// ── Info Rows ─────────────────────────────────────────────────────────────────
class _InfoRows extends StatelessWidget {
  final Campaign c;
  const _InfoRows({required this.c});
  @override
  Widget build(_) {
    final rows = <(String, String?, IconData)>[
      ('Campaign Type', c.type,  Icons.category_outlined),
      ('Location',      c.loc,   Icons.location_on_outlined),
      ('Start Date',    c.start, Icons.calendar_today_outlined),
      ('End Date',      c.end,   Icons.event_outlined),
    ].where((r) => r.$2?.isNotEmpty == true).toList();
    if (rows.isEmpty) return const Text('No additional details.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _mist));
    return Column(children: rows.asMap().entries.map((e) => Column(children: [
      if (e.key > 0) Divider(color: _bdr.withOpacity(0.7), height: 1),
      Padding(padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _mg.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7)),
            child: Icon(e.value.$3, size: 14, color: _mg)),
          const SizedBox(width: 12),
          Text(e.value.$1, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _mist)),
          const Spacer(),
          Flexible(child: Text(e.value.$2!, textAlign: TextAlign.right, maxLines: 2,
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600, fontSize: 13, color: _ink))),
        ])),
    ])).toList());
  }
}

// ── Organiser ─────────────────────────────────────────────────────────────────
class _Organiser extends StatelessWidget {
  final Campaign c; final VoidCallback? onEmail, onPhone;
  const _Organiser({required this.c, this.onEmail, this.onPhone});
  @override
  Widget build(_) {
    final name = c.creator ?? 'Campaign Organiser';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _snow, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bdr)),
        child: Row(children: [
          Container(width: 46, height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_fg, _mg],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 14, color: _ink)),
            const Text('Campaign Organiser', style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11, color: _mist)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: _lime.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: _mg.withOpacity(0.18))),
            child: const Row(children: [
              Icon(Icons.verified_rounded, color: _mg, size: 11), SizedBox(width: 3),
              Text('Verified', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 10, color: _mg)),
            ])),
        ])),
      if (c.email != null || c.phone != null) ...[
        const SizedBox(height: 12),
        if (c.email != null) _CTile(Icons.email_outlined, 'Email', c.email!, onEmail),
        if (c.phone != null) _CTile(Icons.phone_outlined, 'Phone', c.phone!, onPhone),
      ],
    ]);
  }
}

class _CTile extends StatelessWidget {
  final IconData ic; final String label, val; final VoidCallback? onCopy;
  const _CTile(this.ic, this.label, this.val, this.onCopy);
  @override
  Widget build(_) => Padding(padding: const EdgeInsets.only(top: 8),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: _snow, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bdr)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _mg.withOpacity(0.09), borderRadius: BorderRadius.circular(8)),
          child: Icon(ic, size: 14, color: _mg)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _mist)),
          Text(val, style: const TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w600, fontSize: 13, color: _ink)),
        ])),
        if (onCopy != null) GestureDetector(onTap: onCopy,
          child: Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _mg.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.copy_rounded, size: 14, color: _mg))),
      ])));
}

// ── Gallery ───────────────────────────────────────────────────────────────────
class _Gallery extends StatelessWidget {
  final List<String> imgs;
  const _Gallery({required this.imgs});
  @override
  Widget build(_) => SizedBox(height: 108,
    child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: imgs.length,
      itemBuilder: (_, i) => Container(width: 108, height: 108,
        margin: EdgeInsets.only(right: i < imgs.length - 1 ? 10 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bdr)),
        clipBehavior: Clip.hardEdge,
        child: Image.network(imgs[i], fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_rounded, color: _mist, size: 26))))));
}

// ── Community ─────────────────────────────────────────────────────────────────
class _Community extends StatelessWidget {
  final Campaign c; final String Function(double, {String? cur}) fmt;
  final VoidCallback onDonate;
  const _Community({required this.c, required this.fmt, required this.onDonate});
  @override
  Widget build(_) {
    final donors = c.recentDonors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _Stat('${c.donors}', 'Donors', Icons.people_rounded, _mg),
        const SizedBox(width: 8),
        _Stat(fmt(c.raised), 'Raised', Icons.volunteer_activism_rounded, _fg),
        const SizedBox(width: 8),
        _Stat('${c.pct.toStringAsFixed(0)}%', 'Funded', Icons.trending_up_rounded, _amb),
      ]),
      if (donors.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Recent Supporters', style: TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
        const SizedBox(height: 12),
        ...donors.take(5).map((d) => _DonorRow(d: d, fmt: fmt)),
      ] else ...[
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _snow, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _bdr)),
          child: Column(children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(color: _mg.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.favorite_border_rounded, color: _mg, size: 28)),
            const SizedBox(height: 12),
            const Text('Be the first to support!', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
            const SizedBox(height: 6),
            const Text('Your contribution makes a real difference.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _mist),
                textAlign: TextAlign.center),
            if (c.canDonate) ...[
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 46,
                child: ElevatedButton(onPressed: onDonate,
                  style: ElevatedButton.styleFrom(backgroundColor: _fg, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Donate Now', style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 14)))),
            ],
          ])),
      ],
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String val, label; final IconData icon; final Color col;
  const _Stat(this.val, this.label, this.icon, this.col);
  @override
  Widget build(_) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
    decoration: BoxDecoration(color: col.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withOpacity(0.10))),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: col.withOpacity(0.11), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: col, size: 14)),
      const SizedBox(height: 6),
      Text(val, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
          fontSize: 11, color: col), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: _mist),
          textAlign: TextAlign.center),
    ])));
}

class _DonorRow extends StatelessWidget {
  final Map<String, dynamic> d; final String Function(double, {String? cur}) fmt;
  const _DonorRow({required this.d, required this.fmt});
  @override
  Widget build(_) {
    final name = d['name']?.toString() ?? 'Anonymous';
    final amt  = (d['amount'] as num?)?.toDouble() ?? 0;
    final msg  = d['message']?.toString();
    final cols = [_mg, _fg, _amb, const Color(0xFF7B61FF), const Color(0xFF00838F)];
    final col  = cols[name.codeUnitAt(0) % cols.length];
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: col.withOpacity(0.12), shape: BoxShape.circle,
              border: Border.all(color: col.withOpacity(0.18))),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                  fontSize: 13, color: col)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w600, fontSize: 13, color: _ink),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _mg.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(fmt(amt), style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 11, color: _mg))),
          ]),
          if (msg?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _snow,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  border: Border.all(color: _bdr)),
              child: Text('"$msg"', style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 11, color: _mist, fontStyle: FontStyle.italic))),
          ],
        ])),
      ]));
  }
}

// ── Updates ───────────────────────────────────────────────────────────────────
class _Updates extends StatelessWidget {
  final Campaign c;
  const _Updates({required this.c});
  @override
  Widget build(_) {
    final items = c.updates.isNotEmpty ? c.updates.take(3).toList()
        : [{'title': 'Campaign launched.', 'date': c.start,
             'content': 'Help this campaign reach its first milestone.'}];
    return Column(children: items.asMap().entries.map((e) {
      final i = e.key; final u = e.value; final first = i == 0;
      return Padding(padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 11, height: 11,
              decoration: BoxDecoration(color: first ? _mg : _bdr, shape: BoxShape.circle,
                  border: Border.all(color: first ? _fg : _mist, width: 2))),
            if (i < items.length - 1)
              Container(width: 2, height: 52, margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(color: _bdr, borderRadius: BorderRadius.circular(2))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Container(padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: first ? _mg.withOpacity(0.04) : _snow,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: first ? _mg.withOpacity(0.16) : _bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(u['title']?.toString() ?? 'Update',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, fontSize: 13, color: _ink))),
                if (u['date'] != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: _snow, borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _bdr)),
                    child: Text(u['date'].toString(), style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 10, color: _mist))),
              ]),
              if (u['content']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(u['content'].toString(), style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: _mist, height: 1.5)),
              ],
            ]))),
        ]));
    }).toList());
  }
}

// ── Urgency Banner ────────────────────────────────────────────────────────────
class _UrgencyBanner extends StatelessWidget {
  final Campaign c;
  const _UrgencyBanner({required this.c});
  @override
  Widget build(_) {
    final col = c.urgent ? _red : _amb;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: col.withOpacity(0.06), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withOpacity(0.18))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: col.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
          child: Icon(c.urgent ? Icons.flash_on_rounded : Icons.timer_outlined, color: col, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.urgent ? 'Ending soon!' : 'Still time to help',
              style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: col)),
          Text('${c.days} ${c.days == 1 ? "day" : "days"} left · ${c.pct.toStringAsFixed(0)}% funded',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: col.withOpacity(0.72))),
        ])),
      ]));
  }
}

// ── Similar Card ──────────────────────────────────────────────────────────────
class _SimCard extends StatelessWidget {
  final Campaign c; final String Function(double) fmt; final VoidCallback onTap;
  const _SimCard({required this.c, required this.fmt, required this.onTap});
  @override
  Widget build(_) {
    final prog = (c.pct / 100).clamp(0.0, 1.0);
    return GestureDetector(onTap: onTap,
      child: _surfCard(pad: 13, child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 68, height: 68,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(colors: c.grad,
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: c.img != null
                ? ClipRRect(borderRadius: BorderRadius.circular(13),
                    child: Image.network(c.img!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(c.icon, color: Colors.white54, size: 28)))
                : Center(child: Icon(c.icon, color: Colors.white.withOpacity(0.8), size: 28))),
          if (c.tier != Tier.none)
            Positioned(bottom: -5, left: -5, child: _TierBadge(c.tier, size: 20)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Pill(c.cat.toUpperCase(), bg: c.grad[0].withOpacity(0.09), fg: c.grad[0]),
            if (c.urgent) ...[const SizedBox(width: 4),
              _Pill('URGENT', bg: _red.withOpacity(0.07), fg: _red)],
          ]),
          const SizedBox(height: 5),
          Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: _ink, height: 1.3)),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: prog, minHeight: 4,
                backgroundColor: const Color(0xFFD1FAE5),
                valueColor: const AlwaysStoppedAnimation(_mg))),
          const SizedBox(height: 5),
          Row(children: [
            Text(fmt(c.raised), style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 11, color: _mg)),
            const Spacer(),
            if (c.days > 0) Text('${c.days}d left', style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 11, color: _mist)),
          ]),
        ])),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _snow, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.arrow_forward_rounded, color: _mg, size: 15)),
      ])));
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final Campaign c; final String Function(double, {String? cur}) fmt;
  final VoidCallback onDonate;
  const _BottomBar({required this.c, required this.fmt, required this.onDonate});
  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    return Container(padding: EdgeInsets.fromLTRB(20, 12, 20, bot + 12),
      decoration: BoxDecoration(color: _card,
          border: const Border(top: BorderSide(color: _bdr)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 18, offset: const Offset(0, -4))]),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text(fmt(c.raised), style: const TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w800, fontSize: 17, color: _fg)),
          Text('of ${fmt(c.goal)} · ${c.pct.toStringAsFixed(0)}% funded',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _mist)),
        ])),
        const SizedBox(width: 14),
        SizedBox(width: 158, height: 50,
          child: ElevatedButton.icon(onPressed: onDonate,
            icon: const Icon(Icons.favorite_rounded, size: 16),
            label: const Text('Donate Now', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(backgroundColor: _fg, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
      ]));
  }
}

// ── Page transition ───────────────────────────────────────────────────────────
PageRoute<T> _slide<T>(Widget screen) => PageRouteBuilder(
  pageBuilder: (_, a, __) => screen,
  transitionDuration: const Duration(milliseconds: 360),
  transitionsBuilder: (_, a, __, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(c),
        child: FadeTransition(opacity: c, child: child));
  });
