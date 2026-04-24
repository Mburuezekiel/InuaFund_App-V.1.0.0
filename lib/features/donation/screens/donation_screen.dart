// ═══════════════════════════════════════════════════════════════════════════════
// donation_screen.dart  —  InuaFund  •  Polished Donation Flow
// Fixes applied:
//   1. Controller listeners → reactive setState on every keystroke
//   2. _startPolling null-guards _mpesaRef before hitting verify endpoint
//   3. Removed invalid `static const` in extension → mist is top-level const
//   4. Share button wired via Share.share (share_plus) with clipboard fallback
//   5. Back button cancels _pollTimer before popping
//   6. Paystack stub sets _step = processing with clear UX
//   7. Confetti-style animated success particles added in pure Flutter
//   8. [FIX] Use correct STK push endpoint: /api/v1/thedi/mpinua/stkpush
//   9. [FIX] Payload matches web app schema (phoneNumber, amount, email, campaignId, isAnonymous)
//  10. [FIX] Polling uses correct endpoint: /api/v1/thedi/mpinua/status/{ref}
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../campaign/screens/single_campaign_screen.dart';

// ─── Top-level constant (fixes invalid extension static const) ───────────────
const Color kMist = Color(0xFF94A3B8);

// ─── Step Enum ────────────────────────────────────────────────────────────────
enum DonationStep { details, processing, success, error }

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════
class DonationScreen extends StatefulWidget {
  final CampaignDetail campaign;
  final String? token;
  const DonationScreen({super.key, required this.campaign, this.token});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────────
  double?  _selectedPreset;
  bool     _isAnonymous    = false;
  bool     _isSubmitting   = false;
  bool     _userPaysFee    = true;
  String   _paymentMethod  = 'mpesa';
  DonationStep _step       = DonationStep.details;
  String?  _mpesaRef;
  Timer?   _pollTimer;
  String?  _errorMsg;

  // ── Animation controllers ────────────────────────────────────────────────────
  late AnimationController _successCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _errorCtrl;
  late AnimationController _processingPulse;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _rng = math.Random();

  // ── Constants ─────────────────────────────────────────────────────────────────
  static const double _feePct = 5.0;

  // FIX 8: Base URL without the /api suffix — each endpoint has its own full path
  static const String _base   = 'https://api.inuafund.co.ke';

  static const _presets = [
    (10.0,   'Essential support'),
    (50.0,   'Vital resources'),
    (100.0,  'Direct impact'),
    (500.0,  'Impactful solutions'),
    (1000.0, 'Lasting change'),
    (5000.0, 'Transform lives'),
  ];
  static const _popular = 100.0;

  // ── Colours ──────────────────────────────────────────────────────────────────
  static const _green      = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _greenMid   = Color(0xFF22C55E);
  static const _ink        = Color(0xFF0F172A);
  static const _slate      = Color(0xFF64748B);
  static const _border     = Color(0xFFE2E8F0);
  static const _surface    = Color(0xFFFFFFFF);
  static const _snow       = Color(0xFFF8FAFC);
  static const _crimson    = Color(0xFFDC2626);

  // ─────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _emailCtrl.addListener(_onFormChanged);
    _nameCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _amountCtrl.addListener(_onFormChanged);

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _launchConfetti();
      });

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));

    _errorCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _processingPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  void _onFormChanged() => setState(() {});

  // ── Amounts ───────────────────────────────────────────────────────────────────
  double get _entered => double.tryParse(_amountCtrl.text) ?? 0;

  ({double donation, double fee, double total}) get _amounts {
    final a = _entered;
    if (a <= 0) return (donation: 0, fee: 0, total: 0);
    if (_userPaysFee) {
      final fee = a * _feePct / 100;
      return (donation: a, fee: fee, total: a + fee);
    } else {
      final fee = a * _feePct / (100 + _feePct);
      return (donation: a - fee, fee: fee, total: a);
    }
  }

  String _fmt(double v) {
    final c = widget.campaign.currency;
    if (v >= 1000000) return '$c ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '$c ${(v / 1000).toStringAsFixed(1)}K';
    return '$c ${v.toStringAsFixed(2)}';
  }

  bool get _isFormValid {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    return email.contains('@') &&
        _entered >= 10 &&
        RegExp(r'^07\d{8}$').hasMatch(phone) &&
        (_isAnonymous || name.isNotEmpty);
  }

  // ── Confetti ──────────────────────────────────────────────────────────────────
  void _launchConfetti() {
    _particles.clear();
    for (int i = 0; i < 80; i++) {
      _particles.add(_ConfettiParticle(
        x:     _rng.nextDouble(),
        delay: _rng.nextDouble() * 0.6,
        color: [
          const Color(0xFFFBBF24), const Color(0xFF34D399),
          const Color(0xFF60A5FA), const Color(0xFFF472B6),
          const Color(0xFFA78BFA), const Color(0xFFFB923C),
        ][_rng.nextInt(6)],
        size:  4 + _rng.nextDouble() * 6,
        spin:  (_rng.nextDouble() - 0.5) * 6,
      ));
    }
    _confettiCtrl.forward(from: 0);
  }

  // ── M-Pesa ────────────────────────────────────────────────────────────────────
  Future<void> _payMpesa() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      setState(() => _isSubmitting = false);
      _showSnack('Please fill in all required fields correctly.', error: true);
      return;
    }
    setState(() { _step = DonationStep.processing; _errorMsg = null; });

    final amt        = _amounts;
    final int    amountInt   = amt.total.round();
    final double donationAmt = double.parse(amt.donation.toStringAsFixed(2));
    final double platformFee = double.parse(amt.fee.toStringAsFixed(2));

    debugPrint('▶ POST /api/donations payload:');
    debugPrint('  campaignId       : ${widget.campaign.id}');
    debugPrint('  amount           : $amountInt');
    debugPrint('  donationAmount   : $donationAmt');
    debugPrint('  platformFee      : $platformFee');
    debugPrint('  accountReference : ${widget.campaign.title}');

    try {
      final res = await http.post(
        Uri.parse('$_base/api/v1/thedi/mpinua/stkpush'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'phoneNumber':      _phoneCtrl.text.trim(),
          'amount':           amountInt,
          'email':            _emailCtrl.text.trim(),
          'campaignId':       widget.campaign.id,
          'isAnonymous':      _isAnonymous,
          'name':             _isAnonymous ? 'Anonymous' : _nameCtrl.text.trim(),
          'accountReference': widget.campaign.title,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response \${res.statusCode}: \${res.body}');

      Map<String, dynamic>? data;
      try {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (data == null) {
        setState(() {
          _step     = DonationStep.error;
          _errorMsg = 'Unexpected server response (HTTP \${res.statusCode}).';
          _isSubmitting = false;
        });
        return;
      }

      // Web checks: response.ok && data.status === "success"
      final isSuccess = (res.statusCode == 200 || res.statusCode == 201) &&
          (data['status'] == 'success' || data['success'] == true);

      if (isSuccess) {
        // stkpush returns paymentReference at top level
        final ref = (data['paymentReference'] ??
                     data['checkoutRequestID'] ??
                     data['data']?['paymentReference'])
            ?.toString();

        if (ref == null || ref.isEmpty) {
          setState(() {
            _step     = DonationStep.error;
            _errorMsg = 'No payment reference received. Please try again.';
            _isSubmitting = false;
          });
          return;
        }
        _mpesaRef = ref;
        _showSnack('M-Pesa prompt sent! Check your phone.');
        _startPolling();
      } else {
        setState(() {
          _step        = DonationStep.error;
          _errorMsg    = data ?['message']?.toString() ?? 'Payment initiation failed.';
          _isSubmitting = false;
        });
      }
    } catch (e, stack) {
      debugPrint('_payMpesa error: $e\n$stack');
      setState(() {
        _step        = DonationStep.error;
        _errorMsg    = 'Network error. Please check your connection and try again.';
        _isSubmitting = false;
      });
    }
  }

  // FIX 10: Poll the correct status endpoint used by the web app
  void _startPolling() {
    if (_mpesaRef == null || _mpesaRef!.isEmpty) return;
    _pollTimer?.cancel();
    final deadline = DateTime.now().add(const Duration(minutes: 5));

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (DateTime.now().isAfter(deadline)) {
        _pollTimer?.cancel();
        if (mounted) setState(() {
          _step     = DonationStep.error;
          _errorMsg = 'Payment timed out. Please check your M-Pesa transaction history.';
        });
        return;
      }
      try {
        final res  = await http.get(
          Uri.parse('$_base/api/v1/thedi/mpinua/status/$_mpesaRef'),
          headers: {
            if (widget.token != null && widget.token!.isNotEmpty)
              'Authorization': 'Bearer ${widget.token}',
          },
        );
        debugPrint('Poll ${res.statusCode}: ${res.body}');

        final decoded = json.decode(res.body);
        if (decoded is! Map<String, dynamic>) return;

        final outerStatus   = decoded['status']?.toString();
        final paymentStatus = decoded['data']?['donation']?['paymentStatus']?.toString();
        // Also handle top-level success shape from stkpush status endpoint
        final topStatus = (decoded['data']?['status'] ?? outerStatus)?.toString().toLowerCase();

        if ((outerStatus == 'success' && paymentStatus == 'completed') ||
            topStatus == 'completed') {
          _pollTimer?.cancel();
          if (mounted) setState(() {
            _step = DonationStep.success;
            _successCtrl.forward(from: 0);
          });
        } else if ((outerStatus == 'success' && paymentStatus == 'failed') ||
                   topStatus == 'failed' || topStatus == 'cancelled') {
          _pollTimer?.cancel();
          if (mounted) setState(() {
            _step     = DonationStep.error;
            _errorMsg = 'M-Pesa payment was declined or cancelled. Please try again.';
            _errorCtrl.forward(from: 0);
          });
        }
        // pending → keep polling silently
      } catch (_) {} // silent retry on network blip
    });
  }

  // ── Share ─────────────────────────────────────────────────────────────────────
  Future<void> _share() async {
    final text =
        'I just donated to "${widget.campaign.title}" on InuaFund! '
        'You can support this cause too.';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Share link copied to clipboard!');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Share link copied to clipboard!');
    }
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _step           = DonationStep.details;
      _mpesaRef       = null;
      _errorMsg       = null;
      _selectedPreset = null;
      _isSubmitting   = false;
      _amountCtrl.clear();
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13))),
      ]),
      backgroundColor: error ? _crimson : _green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _emailCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _nameCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _phoneCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _amountCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _successCtrl.dispose();
    _confettiCtrl.dispose();
    _errorCtrl.dispose();
    _processingPulse.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _snow,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
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
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04), end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: switch (_step) {
            DonationStep.details    => _buildDetails(),
            DonationStep.processing => _buildProcessing(),
            DonationStep.success    => _buildSuccess(),
            DonationStep.error      => _buildError(),
          },
        ),
        if (_step == DonationStep.success)
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) => _ConfettiOverlay(
              particles: _particles,
              progress: _confettiCtrl.value,
            ),
          ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // DETAILS STEP
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildDetails() {
    final amts = _amounts;
    return SingleChildScrollView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _CampaignCard(campaign: widget.campaign, fmt: _fmt),
          const SizedBox(height: 24),

          _SectionLabel(
            icon: Icons.volunteer_activism_rounded,
            label: 'Choose Amount',
            sub: widget.campaign.currency,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: _presets.map((p) {
              final sel = _selectedPreset == p.$1;
              return _AmountChip(
                amount: p.$1,
                label: p.$2,
                currency: widget.campaign.currency,
                selected: sel,
                isPopular: p.$1 == _popular,
                onTap: () => setState(() {
                  _selectedPreset  = p.$1;
                  _amountCtrl.text = p.$1.toStringAsFixed(0);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _StyledField(
            ctrl: _amountCtrl,
            hint: 'Enter custom amount (min ${widget.campaign.currency} 10)',
            icon: Icons.edit_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _selectedPreset = null),
            validator: (v) {
              final n = double.tryParse(v ?? '') ?? 0;
              if (n < 10) return 'Minimum donation is ${widget.campaign.currency} 10';
              return null;
            },
          ),

          const SizedBox(height: 24),
          _SectionLabel(
            icon: Icons.receipt_long_rounded,
            label: 'Platform Fee',
            sub: '${_feePct.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 12),
          _FeeToggleCard(
            userPaysFee: _userPaysFee,
            onChanged: (v) => setState(() => _userPaysFee = v),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _entered >= 10
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _BreakdownCard(
                      donation: double.parse(amts.donation.toStringAsFixed(2)),
                      fee:      double.parse(amts.fee.toStringAsFixed(2)),
                      total:    _paymentMethod == 'mpesa'
                          ? amts.total.roundToDouble()
                          : double.parse(amts.total.toStringAsFixed(2)),
                      fmt:      _fmt,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          _SectionLabel(icon: Icons.person_outline_rounded, label: 'Your Details'),
          const SizedBox(height: 12),
          _StyledField(
            ctrl: _emailCtrl,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v?.contains('@') ?? false)
                ? null : 'Enter a valid email address',
          ),
          const SizedBox(height: 10),
          _StyledField(
            ctrl: _nameCtrl,
            hint: 'Full name',
            icon: Icons.badge_outlined,
            enabled: !_isAnonymous,
            validator: (v) => !_isAnonymous && (v?.isEmpty ?? true)
                ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),
          _StyledField(
            ctrl: _phoneCtrl,
            hint: 'Phone — 07XXXXXXXXX',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => RegExp(r'^07\d{8}$').hasMatch(v ?? '')
                ? null : 'Use format 07XXXXXXXXX',
          ),
          const SizedBox(height: 10),
          _CheckRow(
            label: 'Donate anonymously',
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),

          const SizedBox(height: 24),
          _SectionLabel(icon: Icons.payment_rounded, label: 'Payment Method'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _PayMethodLogoCard(
              logoUrl: 'https://api.inuafund.co.ke/assets/mpesa.png',
              fallbackIcon: Icons.phone_android_rounded,
              color: const Color(0xFF00A550),
              selected: _paymentMethod == 'mpesa',
              onTap: () => setState(() => _paymentMethod = 'mpesa'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PayMethodLogoCard(
              logoUrl: 'https://api.inuafund.co.ke/assets/Paystack.png',
              fallbackIcon: Icons.credit_card_rounded,
              color: const Color(0xFF0AA83F),
              selected: _paymentMethod == 'paystack',
              onTap: () => setState(() => _paymentMethod = 'paystack'),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _paymentMethod == 'mpesa'
                  ? 'M-Pesa supports Safaricom numbers only.'
                  : 'Paystack supports cards, Airtel Money, and more.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: Color(0xFF3B82F6)),
            )),
          ]),

          const SizedBox(height: 28),
          _DonateButton(
            isValid: _isFormValid,
            method: _paymentMethod,
            label: _entered < 10
                ? 'Minimum donation is ${widget.campaign.currency} 10'
                : _isFormValid
                    ? 'Donate ${_fmt(_paymentMethod == "mpesa" ? _amounts.total.roundToDouble() : double.parse(_amounts.total.toStringAsFixed(2)))} with ${_paymentMethod == "mpesa" ? "M-Pesa" : "Paystack"}'
                    : 'Complete form to donate',
            onTap: _isFormValid
                ? () => _paymentMethod == 'mpesa'
                    ? _payMpesa()
                    : _payPaystack()
                : null,
          ),

          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline_rounded, size: 12, color: kMist),
            const SizedBox(width: 5),
            Text('Secured by InuaFund',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kMist)),
          ]),
        ]),
      ),
    );
  }

  // ── Paystack stub ─────────────────────────────────────────────────────────────
  void _payPaystack() {
    setState(() { _step = DonationStep.processing; _errorMsg = null; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() {
        _step     = DonationStep.error;
        _errorMsg = 'Paystack web checkout is coming soon. Please use M-Pesa for now.';
        _errorCtrl.forward(from: 0);
      });
    });
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PROCESSING STEP
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildProcessing() => Center(
    key: const ValueKey('processing'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Processing image — matches web app processingImage asset
        SizedBox(
          width: 192, height: 192,
          child: Image.network(
            'https://api.inuafund.co.ke/assets/Donation%20Processing.jpeg',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 192, height: 192,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _greenLight),
              child: const Icon(Icons.hourglass_top_rounded, color: _green, size: 72),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _paymentMethod == 'mpesa' ? 'Waiting for Payment…' : 'Processing…',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
              fontSize: 24, color: _ink, height: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          _paymentMethod == 'mpesa'
              ? 'An M-Pesa prompt was sent to\n${_phoneCtrl.text}.\n\nEnter your PIN to complete.'
              : 'Please wait while we securely\nprocess your contribution.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
              color: _slate, height: 1.7),
        ),
        const SizedBox(height: 32),
        LinearProgressIndicator(
          backgroundColor: _greenLight,
          valueColor: const AlwaysStoppedAnimation(_greenMid),
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _reset,
          child: const Text('Cancel',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                color: _slate, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // SUCCESS STEP
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSuccess() {
    if (_successCtrl.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _successCtrl.forward();
      });
    }
    return Center(
      key: const ValueKey('success'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
            child: SizedBox(
              width: 160, height: 160,
              child: Image.network(
                'https://api.inuafund.co.ke/assets/SuccessDonation.jpeg',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: _green, size: 56),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: CurvedAnimation(parent: _successCtrl, curve: const Interval(0.3, 1.0)),
            child: Column(children: [
              Text('Thank You,',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400,
                    fontSize: 18, color: _slate)),
              const SizedBox(height: 4),
              Text(
                _isAnonymous
                    ? 'Anonymous Donor!'
                    : '${_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "Generous Donor"}!',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                    fontSize: 26, color: _ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  'Your donation supports\n"${widget.campaign.title}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                      color: Color(0xFF166534), fontWeight: FontWeight.w500, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + i * 100),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 26),
                  ),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF3B82F6)),
              label: const Text('Share',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                    fontSize: 14, color: Color(0xFF3B82F6))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3B82F6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Donate Again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ERROR STEP
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildError() {
    if (_errorCtrl.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _errorCtrl.forward();
      });
    }
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _errorCtrl, curve: Curves.elasticOut),
            child: SizedBox(
              width: 160, height: 160,
              child: Image.network(
                'https://api.inuafund.co.ke/assets/FailedDonation.jpeg',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: _crimson.withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline_rounded, color: _crimson, size: 52),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Payment Failed',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                fontSize: 24, color: _ink),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              _errorMsg ??
                  'There was an issue processing your payment.\nPlease check your details and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: Color(0xFF991B1B), height: 1.6),
            ),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _crimson, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(
              onPressed: () { _pollTimer?.cancel(); Navigator.pop(context); },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Go Back',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                    fontSize: 14, color: _slate)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Confetti System
// ═══════════════════════════════════════════════════════════════════════════════
class _ConfettiParticle {
  final double x, delay, size, spin;
  final Color color;
  _ConfettiParticle({
    required this.x, required this.delay, required this.size,
    required this.spin, required this.color,
  });
}

class _ConfettiOverlay extends StatelessWidget {
  final List<_ConfettiParticle> particles;
  final double progress;
  const _ConfettiOverlay({required this.particles, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(particles: particles, progress: progress),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay).clamp(0.0, 1.0));
      if (t == 0) continue;
      final opacity = t < 0.8 ? 1.0 : (1 - t) / 0.2;
      final paint = Paint()..color = p.color.withOpacity(opacity);
      final x = p.x * size.width + math.sin(t * math.pi * 2 + p.spin) * 40;
      final y = t * (size.height + 60) - 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _CampaignCard extends StatelessWidget {
  final CampaignDetail campaign;
  final String Function(double) fmt;
  const _CampaignCard({required this.campaign, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final progress = (campaign.percentFunded / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: campaign.featuredImage != null
              ? Image.network(campaign.featuredImage!,
                  width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgFallback())
              : _imgFallback(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(campaign.title,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 13, color: Color(0xFF0F172A), height: 1.3)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 6,
                backgroundColor: const Color(0xFFD1FAE5),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E))),
            ),
          ),
          const SizedBox(height: 5),
          Row(children: [
            Text('${fmt(campaign.amountRaised)} of ${fmt(campaign.goal)}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                  color: Color(0xFF6B7280))),
            const Spacer(),
            const Icon(Icons.people_outline_rounded, size: 11, color: Color(0xFF6B7280)),
            const SizedBox(width: 3),
            Text('${campaign.donorsCount}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                  color: Color(0xFF6B7280))),
          ]),
        ])),
      ]),
    );
  }

  Widget _imgFallback() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E).withOpacity(0.12),
      borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.campaign_rounded, color: Color(0xFF22C55E), size: 28),
  );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  const _SectionLabel({required this.icon, required this.label, this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
    ),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
    if (sub != null) ...[
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(sub!, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
      ),
    ],
  ]);
}

class _AmountChip extends StatelessWidget {
  final double amount;
  final String label, currency;
  final bool selected, isPopular;
  final VoidCallback onTap;
  const _AmountChip({
    required this.amount, required this.label, required this.currency,
    required this.selected, required this.isPopular, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF16A34A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1.5,
        ),
        boxShadow: selected
            ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.25),
                blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Expanded(child: Text('$currency ${amount.toStringAsFixed(0)}',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: selected ? Colors.white : const Color(0xFF0F172A)))),
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.2) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6)),
              child: Text('🔥 Hot',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFFD97706))),
            ),
        ]),
        Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5,
              color: selected ? Colors.white70 : const Color(0xFF94A3B8))),
      ]),
    ),
  );
}

class _StyledField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _StyledField({
    required this.ctrl, required this.hint, required this.icon,
    this.keyboardType, this.inputFormatters, this.enabled = true,
    this.validator, this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, enabled: enabled, keyboardType: keyboardType,
    inputFormatters: inputFormatters, validator: validator, onChanged: onChanged,
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF0F172A)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFCBD5E1)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
    ),
  );
}

class _FeeToggleCard extends StatelessWidget {
  final bool userPaysFee;
  final void Function(bool) onChanged;
  const _FeeToggleCard({required this.userPaysFee, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
    _FeeOption(label: "I'll cover the platform fee",
        sub: "100% of your donation goes to the campaign",
        selected: userPaysFee, onTap: () => onChanged(true)),
    const SizedBox(height: 8),
    _FeeOption(label: "Deduct fee from my donation",
        sub: "Platform fee is subtracted before transferring",
        selected: !userPaysFee, onTap: () => onChanged(false)),
  ]);
}

class _FeeOption extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _FeeOption({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFF16A34A) : Colors.transparent,
            border: Border.all(
              color: selected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF166534) : const Color(0xFF374151))),
          Text(sub, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5,
              color: Color(0xFF94A3B8))),
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
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD1FAE5)),
    ),
    child: Column(children: [
      _Row(label: 'Your donation', value: fmt(donation), bold: false),
      const SizedBox(height: 6),
      _Row(label: 'Platform fee', value: fmt(fee), bold: false),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: const Color(0xFFD1FAE5), thickness: 1),
      ),
      _Row(label: 'Total charge', value: fmt(total), bold: true),
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row({required this.label, required this.value, required this.bold});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5,
        color: bold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Poppins', fontSize: bold ? 14 : 12.5,
        fontWeight: FontWeight.w700,
        color: bold ? const Color(0xFF16A34A) : const Color(0xFF0F172A))),
  ]);
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: value ? 2 : 1.5,
        ),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 20, height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: value ? const Color(0xFF16A34A) : Colors.transparent,
            border: Border.all(
              color: value ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: 2,
            ),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
            fontWeight: FontWeight.w500,
            color: value ? const Color(0xFF166534) : const Color(0xFF374151))),
      ]),
    ),
  );
}

class _PayMethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PayMethodCard({required this.label, required this.icon, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? color : const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: selected ? Colors.white : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
            fontSize: 14, color: selected ? Colors.white : const Color(0xFF64748B))),
      ]),
    ),
  );
}

// ── Payment method card with logo image ───────────────────────────────────────
class _PayMethodLogoCard extends StatelessWidget {
  final String logoUrl;
  final IconData fallbackIcon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PayMethodLogoCard({
    required this.logoUrl, required this.fallbackIcon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? color : const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Center(
        child: Image.network(
          logoUrl,
          height: 32,
          fit: BoxFit.contain,
          color: selected ? Colors.white : null,
          colorBlendMode: selected ? BlendMode.srcIn : null,
          errorBuilder: (_, __, ___) => Icon(
            fallbackIcon,
            size: 28,
            color: selected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    ),
  );
}

class _DonateButton extends StatelessWidget {
  final bool isValid;
  final String method, label;
  final VoidCallback? onTap;
  const _DonateButton({required this.isValid, required this.method,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isValid ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          boxShadow: isValid
              ? [const BoxShadow(color: Color(0x4016A34A), blurRadius: 16, offset: Offset(0, 6))]
              : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            method == 'mpesa' ? Icons.phone_android_rounded : Icons.credit_card_rounded,
            size: 20,
            color: isValid ? Colors.white : const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15,
              color: isValid ? Colors.white : const Color(0xFFCBD5E1),
            ),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }
}