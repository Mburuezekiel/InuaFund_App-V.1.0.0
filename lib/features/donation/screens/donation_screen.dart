// donation_screen.dart  —  InuaFund  •  Fixed + Premium UI
// Fixes: correct API endpoints, correct polling response parsing,
//        matches TSX logic exactly. UI: smooth, modern, intuitive.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../campaign/screens/single_campaign_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _green      = Color(0xFF16A34A);
const _greenDark  = Color(0xFF0B5E35);
const _greenLight = Color(0xFFDCFCE7);
const _greenMid   = Color(0xFF22C55E);
const _ink        = Color(0xFF0F172A);
const _slate      = Color(0xFF64748B);
const _mist       = Color(0xFF94A3B8);
const _border     = Color(0xFFE2E8F0);
const _surface    = Color(0xFFFFFFFF);
const _snow       = Color(0xFFF8FAFC);
const _crimson    = Color(0xFFDC2626);
const _amber      = Color(0xFFF59E0B);

enum _Step { details, processing, success, error }

// ── Presets ───────────────────────────────────────────────────────────────────
const _presets = [
  (10.0,   'Essential support'),
  (50.0,   'Vital resources'),
  (100.0,  'Direct impact'),
  (500.0,  'Impactful change'),
  (1000.0, 'Lasting change'),
  (5000.0, 'Transform lives'),
];
const _popular  = 100.0;
const _feePct   = 5.0;
const _base     = 'https://api.inuafund.co.ke/api';

// ═══════════════════════════════════════════════════════════════════════════════
class DonationScreen extends StatefulWidget {
  final Campaign campaign;
  final String? token;
  const DonationScreen({super.key, required this.campaign, this.token});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with TickerProviderStateMixin {

  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();

  double?  _preset;
  bool     _anonymous  = false;
  bool     _userFee    = true;
  String   _method     = 'mpesa';
  _Step    _step       = _Step.details;
  String?  _mpesaRef;
  String?  _errorMsg;
  Timer?   _poll;
  bool     _submitting = false;

  late final AnimationController _successAC = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _boom(); });
  late final AnimationController _confettiAC = AnimationController(
      vsync: this, duration: const Duration(seconds: 8));
  late final AnimationController _shakeAC = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  final _particles = <_Particle>[];
  final _rng = math.Random();

  // ── Amount math ──────────────────────────────────────────────────────────
  double get _entered => double.tryParse(_amountCtrl.text) ?? 0;

  ({double donation, double fee, double total}) get _amounts {
    final a = _entered;
    if (a <= 0) return (donation: 0, fee: 0, total: 0);
    if (_userFee) {
      final fee = a * _feePct / 100;
      return (donation: a, fee: fee, total: a + fee);
    }
    final fee = a * _feePct / (100 + _feePct);
    return (donation: a - fee, fee: fee, total: a);
  }

  String _fmt(double v) {
    final c = widget.campaign.currency;
    if (v >= 1e6) return '$c ${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '$c ${(v / 1e3).toStringAsFixed(1)}K';
    return '$c ${v.toStringAsFixed(2)}';
  }

  bool get _valid =>
      _emailCtrl.text.trim().contains('@') &&
      _entered >= 10 &&
      RegExp(r'^07\d{8}$').hasMatch(_phoneCtrl.text.trim()) &&
      (_anonymous || _nameCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    for (final c in [_emailCtrl, _nameCtrl, _phoneCtrl, _amountCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [_emailCtrl, _nameCtrl, _phoneCtrl, _amountCtrl]) c.dispose();
    _successAC.dispose();
    _confettiAC.dispose();
    _shakeAC.dispose();
    super.dispose();
  }

  void _boom() {
    _particles.clear();
    for (int i = 0; i < 400; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        delay: _rng.nextDouble() * 0.6,
        color: const [
          Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1),
          Color(0xFFF9CA24), Color(0xFFF0932B), Color(0xFF6C5CE7),
          Color(0xFFA29BFE), Color(0xFFFD79A8), Color(0xFFFDCB6E),
          Color(0xFF00B894), Color(0xFF74B9FF), Color(0xFFE84393),
        ][_rng.nextInt(12)],
        size: 4 + _rng.nextDouble() * 8,
        spin: (_rng.nextDouble() - 0.5) * 10,
        shape: _PShape.values[_rng.nextInt(_PShape.values.length)],
      ));
    }
    _confettiAC.forward(from: 0);
  }

  // ── M-Pesa STK push ───────────────────────────────────────────────────────
  // Matches TSX: POST /api/donations with same body shape
  Future<void> _payMpesa() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate() || !_valid) {
      _snack('Please fill in all required fields correctly.', error: true);
      return;
    }
    setState(() { _submitting = true; _step = _Step.processing; });

    final amts = _amounts;
    final roundedTotal = amts.total.round();

    try {
      final res = await http.post(
        Uri.parse('$_base/donations'),           // ← correct endpoint (matches TSX)
        headers: {
          'Content-Type': 'application/json',
          if (widget.token?.isNotEmpty == true)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'campaignId':    widget.campaign.id,
          'amount':        roundedTotal,
          'donationAmount': double.parse(amts.donation.toStringAsFixed(2)),
          'platformFee':   double.parse(amts.fee.toStringAsFixed(2)),
          'currency':      widget.campaign.currency,
          'email':         _emailCtrl.text.trim(),
          'name':          _anonymous ? 'Anonymous' : _nameCtrl.text.trim(),
          'phoneNumber':   _phoneCtrl.text.trim(),
          'paymentMethod': 'mpesa',
          'isAnonymous':   _anonymous,
          'accountReference': widget.campaign.title,
        }),
      ).timeout(const Duration(seconds: 30));

      Map<String, dynamic>? data;
      try { data = json.decode(res.body) as Map<String, dynamic>?; } catch (_) {}

      if (data == null) {
        _fail('Unexpected server response (HTTP ${res.statusCode}).');
        return;
      }

      // TSX checks: response.ok && data.status === 'success'
      final ok = (res.statusCode == 200 || res.statusCode == 201) &&
                 data['status'] == 'success';

      if (ok) {
        // TSX reads: data.data.paymentReference
        final ref = data['data']?['paymentReference']?.toString();
        if (ref == null || ref.isEmpty) {
          _fail('No payment reference received from server.');
          return;
        }
        _mpesaRef = ref;
        _snack('M-Pesa prompt sent! Enter your PIN to complete.');
        _startPolling();
      } else {
        _fail(data['message']?.toString() ?? 'Failed to initiate M-Pesa payment.');
      }
    } catch (e) {
      _fail('Network error. Please check your connection and try again.');
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  // TSX: GET /api/donations/verify/{ref}
  // Checks: data.status === 'success' && data.data.donation.paymentStatus
  void _startPolling() {
    _poll?.cancel();
    final deadline = DateTime.now().add(const Duration(minutes: 5));

    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) { _poll?.cancel(); return; }

      if (DateTime.now().isAfter(deadline)) {
        _poll?.cancel();
        _fail('M-Pesa payment timed out. Please check your M-Pesa transaction history.');
        return;
      }

      try {
        final res = await http.get(
          Uri.parse('$_base/donations/verify/$_mpesaRef'), // ← correct endpoint (matches TSX)
          headers: {
            if (widget.token?.isNotEmpty == true)
              'Authorization': 'Bearer ${widget.token}',
          },
        ).timeout(const Duration(seconds: 10));

        Map<String, dynamic>? body;
        try { body = json.decode(res.body) as Map<String, dynamic>?; } catch (_) { return; }
        if (body == null) return;

        // TSX: data.status === 'success' && data.data.donation.paymentStatus
        final outerOk  = body['status']?.toString() == 'success';
        final donation = (body['data'] as Map<String, dynamic>?)?['donation'];
        final payStatus = (donation as Map<String, dynamic>?)?['paymentStatus']
            ?.toString().toLowerCase();

        debugPrint('Poll → outerOk=$outerOk payStatus=$payStatus');

        if (!outerOk) return; // network blip, keep polling

        if (payStatus == 'completed') {
          _poll?.cancel();
          if (!mounted) return;
          setState(() { _submitting = false; _step = _Step.success; });
          _successAC.forward(from: 0);

        } else if (payStatus == 'failed') {
          _poll?.cancel();
          _fail('M-Pesa payment failed. Please try again.');

        } else if (payStatus == 'cancelled') {
          _poll?.cancel();
          _fail('Payment was cancelled. You can try again whenever you\'re ready.');
        }
        // pending → keep polling silently
      } catch (_) {
        // Network hiccup — retry next tick
      }
    });
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMsg   = msg;
      _step       = _Step.error;
    });
    _shakeAC.forward(from: 0);
  }

  void _reset() {
    _poll?.cancel();
    setState(() {
      _step      = _Step.details;
      _mpesaRef  = null;
      _errorMsg  = null;
      _preset    = null;
      _submitting = false;
      _amountCtrl.clear();
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13))),
      ]),
      backgroundColor: error ? _crimson : _green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _share() async {
    final text =
        'I just donated to "${widget.campaign.title}" on InuaFund! '
        'Support this cause: https://inuafund.co.ke/campaigns/${widget.campaign.id}';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Share link copied to clipboard!');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _snow,
      appBar: _appBar(),
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: switch (_step) {
            _Step.details    => _Details(key: const ValueKey('d'), state: this),
            _Step.processing => _Processing(key: const ValueKey('p'), state: this),
            _Step.success    => _Success(key: const ValueKey('s'), state: this),
            _Step.error      => _Error(key: const ValueKey('e'), state: this),
          },
        ),
        if (_step == _Step.success)
          AnimatedBuilder(
            animation: _confettiAC,
            builder: (_, __) => _ConfettiLayer(
                particles: _particles, progress: _confettiAC.value),
          ),
      ]),
    );
  }

  AppBar _appBar() => AppBar(
    backgroundColor: _surface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Make a Donation',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 16, color: _ink)),
      Text(widget.campaign.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _slate)),
    ]),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: _ink),
      onPressed: () { _poll?.cancel(); Navigator.pop(context); },
    ),
    bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAILS
// ═══════════════════════════════════════════════════════════════════════════════
class _Details extends StatelessWidget {
  final _DonationScreenState state;
  const _Details({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final amts = s._amounts;
    final totalCharge = s._method == 'mpesa'
        ? amts.total.roundToDouble()
        : double.parse(amts.total.toStringAsFixed(2));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      child: Form(
        key: s._formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Campaign card
          _CampaignBanner(campaign: s.widget.campaign, fmt: s._fmt),
          const SizedBox(height: 22),

          // ── Amount ──────────────────────────────────────────────────────
          _Label(Icons.volunteer_activism_rounded,
              'Choose Amount', sub: s.widget.campaign.currency),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
            children: _presets.map((p) => _AmountTile(
              amount: p.$1, label: p.$2, currency: s.widget.campaign.currency,
              selected: s._preset == p.$1, popular: p.$1 == _popular,
              onTap: () => s.setState(() {
                s._preset = p.$1;
                s._amountCtrl.text = p.$1.toStringAsFixed(0);
              }),
            )).toList(),
          ),
          const SizedBox(height: 10),
          _Field(
            ctrl: s._amountCtrl, hint: 'Custom amount (min ${s.widget.campaign.currency} 10)',
            icon: Icons.edit_rounded,
            inputType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChange: (_) => s.setState(() => s._preset = null),
            validator: (v) {
              final n = double.tryParse(v ?? '') ?? 0;
              return n < 10 ? 'Minimum is ${s.widget.campaign.currency} 10' : null;
            },
          ),

          // ── Fee ─────────────────────────────────────────────────────────
          const SizedBox(height: 22),
          _Label(Icons.receipt_long_rounded, 'Platform Fee', sub: '5%'),
          const SizedBox(height: 10),
          _FeeRow('I\'ll cover the platform fee',
              '100% of your donation reaches the campaign',
              selected: s._userFee, onTap: () => s.setState(() => s._userFee = true)),
          const SizedBox(height: 8),
          _FeeRow('Deduct fee from my donation',
              'Platform fee subtracted before transfer',
              selected: !s._userFee, onTap: () => s.setState(() => s._userFee = false)),
          AnimatedSize(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic,
            child: s._entered >= 10
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _BreakdownCard(
                        donation: amts.donation, fee: amts.fee,
                        total: totalCharge, fmt: s._fmt))
                : const SizedBox.shrink(),
          ),

          // ── Personal ─────────────────────────────────────────────────────
          const SizedBox(height: 22),
          _Label(Icons.person_outline_rounded, 'Your Details'),
          const SizedBox(height: 10),
          _Field(ctrl: s._emailCtrl, hint: 'Email address',
              icon: Icons.mail_outline_rounded, inputType: TextInputType.emailAddress,
              validator: (v) => (v?.contains('@') == true) ? null : 'Enter a valid email'),
          const SizedBox(height: 8),
          _Field(ctrl: s._nameCtrl, hint: 'Full name',
              icon: Icons.badge_outlined, enabled: !s._anonymous,
              validator: (v) => (!s._anonymous && (v?.isEmpty ?? true)) ? 'Name required' : null),
          const SizedBox(height: 8),
          _Field(ctrl: s._phoneCtrl, hint: 'Phone (07XXXXXXXXX)',
              icon: Icons.phone_android_rounded, inputType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => RegExp(r'^07\d{8}$').hasMatch(v ?? '')
                  ? null : 'Use format 07XXXXXXXXX'),
          const SizedBox(height: 8),
          _ToggleRow('Donate anonymously', s._anonymous,
              onTap: () => s.setState(() => s._anonymous = !s._anonymous)),

          // ── Payment method ──────────────────────────────────────────────
          const SizedBox(height: 22),
          _Label(Icons.payment_rounded, 'Payment Method'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MethodCard(
                label: 'M-Pesa', icon: Icons.phone_android_rounded,
                accent: const Color(0xFF00A550),
                selected: s._method == 'mpesa',
                onTap: () => s.setState(() => s._method = 'mpesa'))),
            const SizedBox(width: 10),
            Expanded(child: _MethodCard(
                label: 'Paystack', icon: Icons.credit_card_rounded,
                accent: const Color(0xFF0AA83F),
                selected: s._method == 'paystack',
                onTap: () => s.setState(() => s._method = 'paystack'))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Expanded(child: Text(
                s._method == 'mpesa'
                    ? 'M-Pesa supports Safaricom numbers only.'
                    : 'Paystack supports cards, Airtel Money, and more.',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    color: Color(0xFF3B82F6)))),
          ]),

          // ── CTA ─────────────────────────────────────────────────────────
          const SizedBox(height: 26),
          _CTA(
            valid: s._valid, method: s._method,
            label: s._entered < 10
                ? 'Minimum ${s.widget.campaign.currency} 10'
                : s._valid
                    ? 'Donate ${s._fmt(totalCharge)} via '
                      '${s._method == "mpesa" ? "M-Pesa" : "Paystack"}'
                    : 'Complete the form to continue',
            onTap: s._valid
                ? () => s._method == 'mpesa' ? s._payMpesa() : _paystackStub(s)
                : null,
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.lock_outline_rounded, size: 12, color: _mist),
            SizedBox(width: 5),
            Text('Secured by InuaFund',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _mist)),
          ]),
        ]),
      ),
    );
  }

  void _paystackStub(_DonationScreenState s) {
    s.setState(() => s._step = _Step.processing);
    Future.delayed(const Duration(seconds: 2), () {
      if (s.mounted) s._fail('Paystack checkout coming soon. Please use M-Pesa for now.');
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESSING
// ═══════════════════════════════════════════════════════════════════════════════
class _Processing extends StatefulWidget {
  final _DonationScreenState state;
  const _Processing({super.key, required this.state});
  @override State<_Processing> createState() => _ProcessingState();
}

class _ProcessingState extends State<_Processing> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _elapsed++); });
  }

  @override
  void dispose() { _pulse.dispose(); _timer?.cancel(); super.dispose(); }

  String get _timeLeft {
    final rem = 300 - _elapsed;
    if (rem <= 0) return '0:00';
    return '${rem ~/ 60}:${(rem % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(_greenLight, const Color(0xFFBBF7D0), _pulse.value),
                  boxShadow: [BoxShadow(
                      color: _greenMid.withOpacity(0.25 + _pulse.value * 0.2),
                      blurRadius: 40, spreadRadius: 5)]),
              child: child),
            child: const Icon(Icons.hourglass_top_rounded, color: _green, size: 64),
          ),
          const SizedBox(height: 32),
          Text(
            s._method == 'mpesa' ? 'Waiting for payment…' : 'Processing donation…',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 22, color: _ink),
            textAlign: TextAlign.center),
          const SizedBox(height: 14),
          if (s._method == 'mpesa') ...[
            RichText(textAlign: TextAlign.center, text: TextSpan(
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  color: _slate, height: 1.7),
              children: [
                const TextSpan(text: 'M-Pesa prompt sent to\n'),
                TextSpan(text: s._phoneCtrl.text,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                const TextSpan(text: '\n\nEnter your PIN to complete.'),
              ])),
          ] else
            const Text('Please wait while we securely process\nyour contribution.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                    color: _slate, height: 1.7)),
          const SizedBox(height: 28),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
                minHeight: 6, backgroundColor: _greenLight,
                valueColor: AlwaysStoppedAnimation(_greenMid))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Checking every 5s…',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _mist)),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 12, color: _mist),
              const SizedBox(width: 3),
              Text('Times out $_timeLeft',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _mist)),
            ]),
          ]),
          const SizedBox(height: 24),
          TextButton(
            onPressed: s._reset,
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                    fontSize: 13, color: _slate))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS
// ═══════════════════════════════════════════════════════════════════════════════
class _Success extends StatefulWidget {
  final _DonationScreenState state;
  const _Success({super.key, required this.state});
  @override State<_Success> createState() => _SuccessState();
}

class _SuccessState extends State<_Success> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.state._successAC.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final ac = s._successAC;
    final amts = s._amounts;
    final total = s._method == 'mpesa'
        ? amts.total.roundToDouble()
        : double.parse(amts.total.toStringAsFixed(2));
    final displayName = s._anonymous
        ? 'Anonymous Donor'
        : s._nameCtrl.text.trim().isNotEmpty
            ? s._nameCtrl.text.trim()
            : 'Generous Donor';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: ac, curve: Curves.elasticOut),
          child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _greenLight,
                boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 40)]),
            child: const Icon(Icons.check_rounded, color: _green, size: 72)),
        ),
        const SizedBox(height: 28),
        FadeTransition(
          opacity: CurvedAnimation(parent: ac, curve: const Interval(0.3, 1)),
          child: Column(children: [
            const Text('Thank you,', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 16, color: _slate)),
            const SizedBox(height: 4),
            Text('$displayName!', textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 28, color: _ink)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                  boxShadow: [BoxShadow(color: _green.withOpacity(0.08), blurRadius: 20)]),
              child: Column(children: [
                const Text('Your contribution', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 12, color: _slate)),
                const SizedBox(height: 6),
                Text(s._fmt(total), style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 32, color: _green)),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFD1FAE5)),
                const SizedBox(height: 10),
                Text('supports "${s.widget.campaign.title}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                        color: Color(0xFF166534), fontWeight: FontWeight.w500, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 350 + i * 100),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 30))))),
            const SizedBox(height: 6),
            const Text('You made a real difference today',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _mist)),
            const SizedBox(height: 30),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: s._share,
                icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF3B82F6)),
                label: const Text('Share', style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF3B82F6))),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14)))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: s._reset,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Donate again', style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR
// ═══════════════════════════════════════════════════════════════════════════════
class _Error extends StatefulWidget {
  final _DonationScreenState state;
  const _Error({super.key, required this.state});
  @override State<_Error> createState() => _ErrorState();
}

class _ErrorState extends State<_Error> with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _ac.forward(); });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s    = widget.state;
    final msg  = s._errorMsg ?? '';
    final cancelled = msg.toLowerCase().contains('cancel');
    final insufficient = msg.toLowerCase().contains('insufficient');

    final accentColor = cancelled ? _amber : _crimson;
    final bgColor     = cancelled ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);
    final bdColor     = cancelled ? const Color(0xFFFDE68A) : const Color(0xFFFECACA);
    final textColor   = cancelled ? const Color(0xFF92400E) : const Color(0xFF991B1B);
    final icon        = cancelled
        ? Icons.cancel_outlined
        : insufficient
            ? Icons.account_balance_wallet_outlined
            : Icons.error_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _ac, curve: Curves.elasticOut),
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.12),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 30)]),
              child: Icon(icon, color: accentColor, size: 56)),
          ),
          const SizedBox(height: 24),
          Text(
            cancelled ? 'Payment Cancelled'
                : insufficient ? 'Insufficient Balance' : 'Payment Failed',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                fontSize: 24, color: _ink),
            textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bdColor)),
            child: Text(
                msg.isEmpty
                    ? 'There was an issue processing your payment.\nPlease try again.'
                    : msg,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                    color: textColor, height: 1.6))),
          if (insufficient) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD1FAE5))),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: _green),
                SizedBox(width: 8),
                Expanded(child: Text('Top up your M-Pesa and try again, '
                    'or try a smaller amount.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        color: Color(0xFF166534), height: 1.5))),
              ])),
          ],
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: s._reset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(
              onPressed: () { s._poll?.cancel(); Navigator.pop(context); },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Go back', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 14, color: _slate)))),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _CampaignBanner extends StatelessWidget {
  final Campaign campaign;
  final String Function(double) fmt;
  const _CampaignBanner({required this.campaign, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final prog = (campaign.pct / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.06), blurRadius: 16)]),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: campaign.featuredImage != null
              ? Image.network(campaign.featuredImage!.toString(),
                  width: 64, height: 64, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgFallback())
              : _imgFallback(),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(campaign.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                  fontSize: 13.5, color: _ink, height: 1.3)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: prog),
            duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 6,
                  backgroundColor: const Color(0xFFD1FAE5),
                  valueColor: const AlwaysStoppedAnimation(_greenMid)))),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('${fmt(campaign.raised)} of ${fmt(campaign.goal)}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _slate))),
            const Icon(Icons.people_outline_rounded, size: 11, color: _slate),
            const SizedBox(width: 3),
            Text('${campaign.donors}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _slate)),
          ]),
        ])),
      ]),
    );
  }

  Widget _imgFallback() => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: _greenMid.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.campaign_rounded, color: _greenMid, size: 30));
}

class _Label extends StatelessWidget {
  final IconData icon; final String label; final String? sub;
  const _Label(this.icon, this.label, {this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 34, height: 34,
        decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 17, color: _greenDark)),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
    if (sub != null) ...[
      const SizedBox(width: 7),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(6)),
          child: Text(sub!, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 10, fontWeight: FontWeight.w700, color: _greenDark))),
    ],
  ]);
}

class _AmountTile extends StatefulWidget {
  final double amount; final String label, currency;
  final bool selected, popular; final VoidCallback onTap;
  const _AmountTile({required this.amount, required this.label,
      required this.currency, required this.selected,
      required this.popular, required this.onTap});
  @override State<_AmountTile> createState() => _AmountTileState();
}

class _AmountTileState extends State<_AmountTile> with SingleTickerProviderStateMixin {
  late AnimationController _sc = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 100), lowerBound: 0.94, upperBound: 1, value: 1);
  @override void dispose() { _sc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { _sc.reverse().then((_) => _sc.forward()); widget.onTap(); },
    child: ScaleTransition(scale: _sc, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: widget.selected ? _green : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: widget.selected ? _green : _border,
              width: widget.selected ? 2 : 1.5),
          boxShadow: widget.selected
              ? [BoxShadow(color: _green.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Expanded(child: Text('${widget.currency} ${widget.amount.toStringAsFixed(0)}',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                  fontSize: 13.5, color: widget.selected ? Colors.white : _ink))),
          if (widget.popular)
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: widget.selected ? Colors.white.withOpacity(0.2) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(5)),
                child: Text('🔥 Hot', style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: widget.selected ? Colors.white : const Color(0xFFD97706)))),
        ]),
        Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5,
                color: widget.selected ? Colors.white70 : _mist)),
      ]),
    )),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint; final IconData icon;
  final TextInputType? inputType;
  final List<TextInputFormatter>? formatters;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onChange;

  const _Field({required this.ctrl, required this.hint, required this.icon,
      this.inputType, this.formatters, this.enabled = true,
      this.validator, this.onChange});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, enabled: enabled, keyboardType: inputType,
    inputFormatters: formatters, validator: validator, onChanged: onChange,
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _ink),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _mist),
      prefixIcon: Icon(icon, size: 18, color: _mist),
      filled: true, fillColor: enabled ? _surface : _snow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _green, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _crimson)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _crimson, width: 2)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
    ),
  );
}

class _FeeRow extends StatelessWidget {
  final String label, sub; final bool selected; final VoidCallback onTap;
  const _FeeRow(this.label, this.sub, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _green : _border, width: selected ? 2 : 1.5)),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: selected ? _green : Colors.transparent,
                border: Border.all(
                    color: selected ? _green : _mist, width: 2)),
            child: selected
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF166534) : const Color(0xFF374151))),
          Text(sub, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 10.5, color: _mist)),
        ])),
      ]),
    ),
  );
}

class _BreakdownCard extends StatelessWidget {
  final double donation, fee, total;
  final String Function(double) fmt;
  const _BreakdownCard({required this.donation, required this.fee,
      required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD1FAE5))),
    child: Column(children: [
      _Row('Your donation', fmt(donation), false),
      const SizedBox(height: 6),
      _Row('Platform fee (5%)', fmt(fee), false),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: const Color(0xFFD1FAE5), thickness: 1, height: 1)),
      _Row('Total charge', fmt(total), true),
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value; final bool bold;
  const _Row(this.label, this.value, this.bold);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5,
        color: bold ? _ink : _slate, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Poppins',
        fontSize: bold ? 14 : 12.5, fontWeight: FontWeight.w700,
        color: bold ? _green : _ink)),
  ]);
}

class _ToggleRow extends StatelessWidget {
  final String label; final bool value; final VoidCallback onTap;
  const _ToggleRow(this.label, this.value, {required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
          color: value ? const Color(0xFFF0FDF4) : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: value ? _green : _border, width: value ? 2 : 1.5)),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
                color: value ? _green : Colors.transparent,
                border: Border.all(color: value ? _green : _mist, width: 2)),
            child: value
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
            fontWeight: FontWeight.w500,
            color: value ? const Color(0xFF166534) : const Color(0xFF374151))),
      ]),
    ),
  );
}

class _MethodCard extends StatelessWidget {
  final String label; final IconData icon;
  final Color accent; final bool selected; final VoidCallback onTap;
  const _MethodCard({required this.label, required this.icon,
      required this.accent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: selected ? accent : _surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? accent : _border, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: selected ? Colors.white : _mist),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 14,
            color: selected ? Colors.white : _slate)),
      ]),
    ),
  );
}

class _CTA extends StatelessWidget {
  final bool valid; final String method, label; final VoidCallback? onTap;
  const _CTA({required this.valid, required this.method,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
      height: 58, width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: valid
              ? const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF0B5E35)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: valid ? null : _border,
          boxShadow: valid
              ? [const BoxShadow(color: Color(0x5016A34A), blurRadius: 20, offset: Offset(0, 8))]
              : []),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(method == 'mpesa' ? Icons.phone_android_rounded : Icons.credit_card_rounded,
            size: 20, color: valid ? Colors.white : _mist),
        const SizedBox(width: 10),
        Flexible(child: Text(label,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 15, color: valid ? Colors.white : _mist),
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Confetti
// ═══════════════════════════════════════════════════════════════════════════════
enum _PShape { rect, circle, triangle }

class _Particle {
  final double x, delay, size, spin;
  final Color color;
  final _PShape shape;
  const _Particle({required this.x, required this.delay, required this.size,
      required this.spin, required this.color, this.shape = _PShape.rect});
}

class _ConfettiLayer extends StatelessWidget {
  final List<_Particle> particles; final double progress;
  const _ConfettiLayer({required this.particles, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return const SizedBox.shrink();
    return IgnorePointer(child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(particles: particles, progress: progress)));
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles; final double progress;
  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t == 0) continue;
      final opacity = (t < 0.8 ? 1.0 : (1 - t) / 0.2).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      final x = p.x * size.width + math.sin(t * math.pi * 2 + p.spin) * 40 + p.spin * 20 * t;
      final y = t * (size.height + 100) - 50;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * math.pi * 4);
      switch (p.shape) {
        case _PShape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        case _PShape.triangle:
          canvas.drawPath(Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close(), paint);
        case _PShape.rect:
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
              const Radius.circular(2)), paint);
      }
      canvas.restore();
    }
  }

  @override bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}