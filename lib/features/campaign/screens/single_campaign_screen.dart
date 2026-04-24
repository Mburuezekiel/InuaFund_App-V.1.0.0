// ═══════════════════════════════════════════════════════════════════════════════
// single_campaign_screen.dart  —  InuaFund  (full rewrite, stable layout)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../donation/screens/donation_screen.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const amber       = Color(0xFFE8860A);
  static const crimson     = Color(0xFFD93025);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF4F6F4);
  static const white       = Color(0xFFFFFFFF);
  static const mist        = Color(0xFF8FA896);
}

// ─── Model ───────────────────────────────────────────────────────────────────
class CampaignDetail {
  final String id, title, description, category, currency, status;
  final double amountRaised, goal, percentFunded;
  final int donorsCount, daysRemaining;
  final String? featuredImage, creatorName, contactEmail, contactPhone,
      campaignType, location, endDate, startDate, approvalStatus, timeStatus;
  final List<String> gallery;
  final List<Map<String, dynamic>> recentDonors;

  const CampaignDetail({
    required this.id, required this.title, required this.description,
    required this.category, required this.currency, required this.status,
    required this.amountRaised, required this.goal, required this.percentFunded,
    required this.donorsCount, required this.daysRemaining,
    this.featuredImage, this.creatorName, this.contactEmail, this.contactPhone,
    this.campaignType, this.location, this.endDate, this.startDate,
    this.approvalStatus, this.timeStatus,
    this.gallery = const [], this.recentDonors = const [],
  });

  bool get canDonate =>
      approvalStatus == 'approved' && timeStatus == 'ongoing';

  factory CampaignDetail.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is Map) {
        final i = v['\$numberInt']; if (i != null) return double.parse(i.toString());
        final d = v['\$numberDouble']; if (d != null) return double.parse(d.toString());
      }
      return double.tryParse(v.toString()) ?? 0;
    }

    final raised = n(j['amountRaised']);
    final goal   = n(j['goal']);
    final pct    = goal > 0 ? (raised / goal * 100).clamp(0.0, 100.0) : 0.0;

    final now       = DateTime.now();
    final endDt     = j['endDate']   != null ? DateTime.tryParse(j['endDate'].toString())   : null;
    final startDt   = j['startDate'] != null ? DateTime.tryParse(j['startDate'].toString()) : null;
    String timeStatus = 'ongoing';
    if (endDt != null && now.isAfter(endDt))       timeStatus = 'ended';
    else if (startDt != null && now.isBefore(startDt)) timeStatus = 'upcoming';

    final creator = j['creator'];
    String? creatorName;
    if (creator is Map) creatorName = creator['username']?.toString();
    else creatorName = j['username']?.toString();

    final galleryRaw = j['gallery'];
    final gallery = galleryRaw is List
        ? galleryRaw.whereType<String>().toList() : <String>[];

    final donorsRaw = j['recentDonors'];
    final donors = donorsRaw is List
        ? donorsRaw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    return CampaignDetail(
      id: j['_id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      description: j['description']?.toString() ?? '',
      category: j['category']?.toString() ?? 'General',
      currency: j['currency']?.toString() ?? 'KES',
      status: j['status']?.toString() ?? 'active',
      amountRaised: raised, goal: goal, percentFunded: pct.toDouble(),
      donorsCount: n(j['donorsCount']).toInt(),
      daysRemaining: n(j['daysRemaining']).toInt(),
      featuredImage: j['featuredImage']?.toString(),
      creatorName: creatorName,
      contactEmail: j['contactEmail']?.toString(),
      contactPhone: j['contactPhone']?.toString(),
      campaignType: j['campaignType']?.toString(),
      location: j['location']?.toString(),
      endDate:   endDt   != null ? '${endDt.day}/${endDt.month}/${endDt.year}'     : null,
      startDate: startDt != null ? '${startDt.day}/${startDt.month}/${startDt.year}' : null,
      approvalStatus: j['approvalStatus']?.toString() ?? 'pending',
      timeStatus: timeStatus,
      gallery: gallery,
      recentDonors: donors,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────
class CampaignDetailService {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<CampaignDetail?> fetch(String id, {String? token}) async {
    try {
      final headers = {'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final r = await http
          .get(Uri.parse('$_base/campaigns/$id'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['status'] == 'success' && d['data'] != null) {
          return CampaignDetail.fromJson(d['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('CampaignDetailService.fetch error: $e');
    }
    return null;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class SingleCampaignScreen extends StatefulWidget {
  final String campaignId;
  final String? token;

  const SingleCampaignScreen({
    super.key,
    required this.campaignId,
    this.token,
  });

  @override
  State<SingleCampaignScreen> createState() => _SingleCampaignScreenState();
}

class _SingleCampaignScreenState extends State<SingleCampaignScreen> {
  CampaignDetail? _campaign;
  bool  _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final c = await CampaignDetailService.fetch(
        widget.campaignId, token: widget.token);
    if (!mounted) return;
    setState(() {
      _campaign = c;
      _loading  = false;
      if (c == null) _error = 'Campaign not found or failed to load.';
    });
  }

  String _fmt(double v) {
    final cur = _campaign?.currency ?? 'KES';
    if (v >= 1000000) return '$cur ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '$cur ${(v / 1000).toStringAsFixed(0)}K';
    return '$cur ${v.toStringAsFixed(0)}';
  }

  void _openDonation() {
    if (_campaign == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DonationScreen(campaign: _campaign!, token: widget.token),
    ));
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingPage();
    if (_error != null || _campaign == null) return _errorPage();
    return _contentPage();
  }

  // ── loading ───────────────────────────────────────────────────────────────
  Widget _loadingPage() => Scaffold(
    backgroundColor: AppColors.snow,
    appBar: AppBar(
      backgroundColor: AppColors.forestGreen,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppColors.midGreen, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Loading campaign…',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                color: AppColors.mist)),
      ]),
    ),
  );

  // ── error ─────────────────────────────────────────────────────────────────
  Widget _errorPage() => Scaffold(
    backgroundColor: AppColors.snow,
    appBar: AppBar(
      backgroundColor: AppColors.forestGreen, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.crimson, size: 56),
          const SizedBox(height: 16),
          const Text('Oops!', style: TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w800, fontSize: 22,
              color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(_error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: AppColors.mist)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    ),
  );

  // ── content ───────────────────────────────────────────────────────────────
  Widget _contentPage() {
    final c        = _campaign!;
    final progress = (c.percentFunded / 100).clamp(0.0, 1.0);
    final images   = [if (c.featuredImage != null) c.featuredImage!, ...c.gallery];

    return Scaffold(
      backgroundColor: AppColors.snow,
      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.forestGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
        title: Text(
          c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        ),
      ),
      // ── Body ──────────────────────────────────────────────────────────────
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero image / carousel
          if (images.isNotEmpty)
            SizedBox(height: 240, child: _Carousel(images: images)),

          // ── Main content padding ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.midGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c.category.toUpperCase(),
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700, fontSize: 10,
                          color: AppColors.midGreen, letterSpacing: 0.6)),
                ),
                const SizedBox(height: 10),

                // Title
                Text(c.title,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800, fontSize: 20,
                        color: AppColors.ink, height: 1.3)),

                // Creator
                if (c.creatorName != null) ...[
                  const SizedBox(height: 4),
                  Text('by ${c.creatorName}',
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 13, color: AppColors.mist)),
                ],

                const SizedBox(height: 20),

                // ── Progress card ──────────────────────────────────────────
                _card(child: _ProgressSection(
                    campaign: c, progress: progress, fmt: _fmt)),

                const SizedBox(height: 16),

                // ── Action buttons ─────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: c.canDonate
                        ? _greenBtn('Donate Now', Icons.favorite_rounded,
                            _openDonation)
                        : _notAccepting(),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100, height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share_rounded,
                          size: 16, color: AppColors.midGreen),
                      label: const Text('Share',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: AppColors.midGreen)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.midGreen),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────────────────
                _card(child: _CardSection(
                  title: 'About',
                  child: _ExpandableText(text: c.description),
                )),

                const SizedBox(height: 16),

                // ── Campaign details ───────────────────────────────────────
                _card(child: _CardSection(
                  title: 'Campaign Details',
                  child: _InfoRows(campaign: c),
                )),

                // ── Gallery ───────────────────────────────────────────────
                if (images.length > 1) ...[
                  const SizedBox(height: 16),
                  _card(child: _CardSection(
                    title: 'Gallery',
                    child: _GalleryStrip(images: images),
                  )),
                ],

                // ── Recent donors ──────────────────────────────────────────
                if (c.recentDonors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _card(child: _CardSection(
                    title: 'Recent Donations',
                    child: _DonorList(donors: c.recentDonors, fmt: _fmt),
                  )),
                ],

                // ── Days remaining ─────────────────────────────────────────
                if (c.daysRemaining > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined,
                          color: AppColors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${c.daysRemaining} '
                        '${c.daysRemaining == 1 ? "day" : "days"} remaining',
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600, fontSize: 13,
                            color: AppColors.amber),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      // ── Sticky bottom bar ────────────────────────────────────────────────
      bottomNavigationBar: c.canDonate
          ? _BottomBar(
              raised: c.amountRaised, goal: c.goal,
              pct: c.percentFunded, fmt: _fmt, onDonate: _openDonation)
          : null,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cloud),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Widget _greenBtn(String label, IconData icon, VoidCallback onTap) =>
      SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );

  Widget _notAccepting() => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.info_outline_rounded, color: AppColors.crimson, size: 16),
      SizedBox(width: 6),
      Flexible(child: Text('Not accepting donations',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
              fontWeight: FontWeight.w600, color: AppColors.crimson))),
    ]),
  );
}

// ─── Carousel ─────────────────────────────────────────────────────────────────
class _Carousel extends StatefulWidget {
  final List<String> images;
  const _Carousel({required this.images});
  @override State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => Image.network(
          widget.images[i], fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.midGreen,
            child: const Icon(Icons.image_not_supported_rounded,
                color: Colors.white54, size: 48),
          ),
        ),
      ),
      // gradient
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: const [0.55, 1.0],
        ),
      ))),
      // dots
      if (widget.images.length > 1)
        Positioned(bottom: 10, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  color: _index == i ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
          )),
    ]);
  }
}

// ─── Progress section ─────────────────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final CampaignDetail campaign;
  final double progress;
  final String Function(double) fmt;
  const _ProgressSection({required this.campaign, required this.progress,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fmt(campaign.amountRaised),
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800, fontSize: 24,
                  color: AppColors.forestGreen)),
          Text('raised of ${fmt(campaign.goal)}',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 12, color: AppColors.mist)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${campaign.percentFunded.toStringAsFixed(1)}%',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 20,
                  color: AppColors.midGreen)),
          const Text('funded', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 11, color: AppColors.mist)),
        ]),
      ]),
      const SizedBox(height: 12),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: v, minHeight: 8,
            backgroundColor: const Color(0xFFD1FAE5),
            valueColor: const AlwaysStoppedAnimation(AppColors.midGreen),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.people_rounded, size: 15, color: AppColors.midGreen),
        const SizedBox(width: 4),
        Text('${campaign.donorsCount} donors',
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 12, color: AppColors.mist)),
        if (campaign.daysRemaining > 0) ...[
          const Spacer(),
          const Icon(Icons.schedule_rounded, size: 15, color: AppColors.amber),
          const SizedBox(width: 4),
          Text('${campaign.daysRemaining} days left',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: AppColors.amber, fontWeight: FontWeight.w600)),
        ],
      ]),
    ]);
  }
}

// ─── Card section header ──────────────────────────────────────────────────────
class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: AppColors.midGreen,
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
      ]),
      const SizedBox(height: 14),
      child,
    ]);
  }
}

// ─── Expandable text ──────────────────────────────────────────────────────────
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});
  @override State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const limit = 220;
    final needs = widget.text.length > limit;
    final display = (!needs || _expanded)
        ? widget.text
        : '${widget.text.substring(0, limit)}…';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(display, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 13, color: AppColors.ink, height: 1.65)),
      if (needs) ...[
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Show less' : 'Read more',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: AppColors.midGreen,
                  decoration: TextDecoration.underline)),
        ),
      ],
    ]);
  }
}

// ─── Info rows ────────────────────────────────────────────────────────────────
class _InfoRows extends StatelessWidget {
  final CampaignDetail campaign;
  const _InfoRows({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Type',          campaign.campaignType),
      ('Location',      campaign.location),
      ('Start Date',    campaign.startDate),
      ('End Date',      campaign.endDate),
      ('Contact Email', campaign.contactEmail),
    ].where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();

    if (rows.isEmpty) {
      return const Text('No details available.',
          style: TextStyle(fontFamily: 'Poppins',
              fontSize: 13, color: AppColors.mist));
    }

    return Column(
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(r.$1, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 12, color: AppColors.mist)),
          const Spacer(),
          Flexible(child: Text(r.$2!,
              textAlign: TextAlign.right,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600, fontSize: 12,
                  color: AppColors.ink))),
        ]),
      )).toList(),
    );
  }
}

// ─── Gallery strip ────────────────────────────────────────────────────────────
class _GalleryStrip extends StatelessWidget {
  final List<String> images;
  const _GalleryStrip({required this.images});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 90,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (_, i) => Container(
        width: 90, height: 90,
        margin: EdgeInsets.only(right: i < images.length - 1 ? 10 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.hardEdge,
        child: Image.network(images[i], fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.cloud,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.mist),
            )),
      ),
    ),
  );
}

// ─── Donor list ───────────────────────────────────────────────────────────────
class _DonorList extends StatelessWidget {
  final List<Map<String, dynamic>> donors;
  final String Function(double) fmt;
  const _DonorList({required this.donors, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: donors.take(5).map((d) {
        final name = d['name']?.toString() ?? 'Anonymous';
        final amt  = (d['amount'] as num?)?.toDouble() ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: AppColors.midGreen.withOpacity(0.10),
                  shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.person_rounded,
                  color: AppColors.midGreen, size: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                fontSize: 13, color: AppColors.ink))),
            Text(fmt(amt), style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 13, color: AppColors.midGreen)),
          ]),
        );
      }).toList(),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final double raised, goal, pct;
  final String Function(double) fmt;
  final VoidCallback onDonate;

  const _BottomBar({required this.raised, required this.goal,
      required this.pct, required this.fmt, required this.onDonate});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, -3))],
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmt(raised), style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 15, color: AppColors.forestGreen)),
            Text('of ${fmt(goal)} · ${pct.toStringAsFixed(0)}%',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.mist)),
          ],
        )),
        const SizedBox(width: 16),
        SizedBox(
          width: 160, height: 50,
          child: ElevatedButton.icon(
            onPressed: onDonate,
            icon: const Icon(Icons.favorite_rounded, size: 16),
            label: const Text('Donate Now', style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}