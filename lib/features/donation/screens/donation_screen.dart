// ═══════════════════════════════════════════════════════════════════════════════
// donation_screen.dart  —  InuaFund  •  Final Production Build
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../campaign/screens/single_campaign_screen.dart';

const Color kMist = Color(0xFF94A3B8);

enum DonationStep { details, processing, success, error }

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

  double?      _selectedPreset;
  bool         _isAnonymous   = false;
  bool         _isSubmitting  = false;
  bool         _userPaysFee   = true;
  String       _paymentMethod = 'mpesa';
  DonationStep _step          = DonationStep.details;
  String?      _mpesaRef;
  Timer?       _pollTimer;
  String?      _errorMsg;
  bool         _goingForward  = true;

  late AnimationController _successCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _errorCtrl;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _rng = math.Random();

  static const double _feePct = 5.0;
  static const String _base   = 'https://api.inuafund.co.ke';

  static const _presets = [
    (10.0,   'Essential support'),
    (50.0,   'Vital resources'),
    (100.0,  'Direct impact'),
    (500.0,  'Impactful change'),
    (1000.0, 'Lasting change'),
    (5000.0, 'Transform lives'),
  ];
  static const _popular = 100.0;

  static const _green      = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _greenMid   = Color(0xFF22C55E);
  static const _ink        = Color(0xFF0F172A);
  static const _slate      = Color(0xFF64748B);
  static const _border     = Color(0xFFE2E8F0);
  static const _surface    = Color(0xFFFFFFFF);
  static const _snow       = Color(0xFFF8FAFC);
  static const _crimson    = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onFormChanged);
    _nameCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _amountCtrl.addListener(_onFormChanged);

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _launchConfetti();
      });
    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8)); // match React 8000ms
    _errorCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  void _onFormChanged() => setState(() {});

  // ── Amount helpers ────────────────────────────────────────────────────────
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
    return _emailCtrl.text.trim().contains('@') &&
        _entered >= 10 &&
        RegExp(r'^07\d{8}$').hasMatch(_phoneCtrl.text.trim()) &&
        (_isAnonymous || _nameCtrl.text.trim().isNotEmpty);
  }

  void _goToStep(DonationStep next, {bool forward = true}) {
    if (!mounted) return;
    setState(() { _goingForward = forward; _step = next; });
  }

  // ── Confetti ──────────────────────────────────────────────────────────────
  void _launchConfetti() {
    _particles.clear();
    // 400 particles matching the React Confetti component
    for (int i = 0; i < 400; i++) {
      _particles.add(_ConfettiParticle(
        x:     _rng.nextDouble(),
        delay: _rng.nextDouble() * 0.6,
        color: [
          const Color(0xFFFF6B6B), const Color(0xFF4ECDC4),
          const Color(0xFF45B7D1), const Color(0xFFF9CA24),
          const Color(0xFFF0932B), const Color(0xFF6C5CE7),
          const Color(0xFFA29BFE), const Color(0xFFFD79A8),
          const Color(0xFFFDCB6E), const Color(0xFF00B894),
          const Color(0xFF74B9FF), const Color(0xFFE84393),
        ][_rng.nextInt(12)],
        size:  4 + _rng.nextDouble() * 8,
        spin:  (_rng.nextDouble() - 0.5) * 10,
        shape: _ConfettiShape.values[_rng.nextInt(_ConfettiShape.values.length)],
      ));
    }
    _confettiCtrl.forward(from: 0);
  }

  // ── M-Pesa payment ────────────────────────────────────────────────────────
  Future<void> _payMpesa() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    if (!_formKey.currentState!.validate() || !_isFormValid) {
      setState(() => _isSubmitting = false);
      _showSnack('Please fill in all required fields correctly.', error: true);
      return;
    }

    _goToStep(DonationStep.processing);

    final int amountInt = _amounts.total.round();

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
          'accountReference': 'Donation to ${widget.campaign.title}',
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('STK push → ${res.statusCode}: ${res.body}');

      Map<String, dynamic>? data;
      try {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (data == null) {
        setState(() { _isSubmitting = false; _errorMsg = 'Unexpected server response (HTTP ${res.statusCode}).'; });
        _goToStep(DonationStep.error);
        return;
      }

      final ok = (res.statusCode == 200 || res.statusCode == 201) &&
          (data['status'] == 'success' || data['success'] == true ||
           data['ResponseCode'] == '0');

      if (ok) {
        // Extract reference — try every known field the server might return
        final ref = (data['paymentReference'] ??
                     data['data']?['paymentReference'] ??
                     data['checkoutRequestID'] ??
                     data['data']?['checkoutRequestID'] ??
                     data['CheckoutRequestID'])?.toString();

        if (ref == null || ref.isEmpty) {
          setState(() { _isSubmitting = false; _errorMsg = 'No payment reference received.'; });
          _goToStep(DonationStep.error);
          return;
        }
        _mpesaRef = ref;
        debugPrint('Polling ref: $_mpesaRef');
        _showSnack('M-Pesa prompt sent! Enter your PIN to complete.');
        _startPolling();
      } else {
        final msg = data['message']?.toString() ??
                    data['errorMessage']?.toString() ??
                    'Payment initiation failed.';
        setState(() { _isSubmitting = false; _errorMsg = msg; });
        _goToStep(DonationStep.error);
      }
    } catch (e) {
      debugPrint('_payMpesa error: $e');
      setState(() {
        _isSubmitting = false;
        _errorMsg = 'Network error. Please check your connection and try again.';
      });
      _goToStep(DonationStep.error);
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  //
  // Server status response shape (from mpesaController.js):
  //   { status: 'success', data: { status: 'pending'|'completed'|'failed'|'cancelled',
  //                                 isVerified: bool,
  //                                 resultCode: number,
  //                                 resultDesc: string } }
  //
  void _startPolling() {
    if (_mpesaRef == null || _mpesaRef!.isEmpty) return;
    _pollTimer?.cancel();
    final deadline = DateTime.now().add(const Duration(minutes: 5));

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }

      if (DateTime.now().isAfter(deadline)) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _errorMsg =
              'Payment timed out after 5 minutes. '
              'Please check your M-Pesa transaction history.');
          _goToStep(DonationStep.error);
          _errorCtrl.forward(from: 0);
        }
        return;
      }

      try {
        final res = await http.get(
          Uri.parse('$_base/api/v1/thedi/mpinua/status/$_mpesaRef'),
          headers: {
            if (widget.token != null && widget.token!.isNotEmpty)
              'Authorization': 'Bearer ${widget.token}',
          },
        ).timeout(const Duration(seconds: 10));

        debugPrint('Poll → ${res.statusCode}: ${res.body}');

        Map<String, dynamic>? body;
        try {
          final d = json.decode(res.body);
          if (d is Map<String, dynamic>) body = d;
        } catch (_) { return; }

        if (body == null) return;

        // Extract the payment status — handle both flat and nested shapes
        final dataNode = body['data'];
        final String? payStatus = (dataNode is Map
                ? (dataNode['status'] ?? dataNode['paymentStatus'])
                : body['status'])
            ?.toString()
            .toLowerCase();

        final int? resultCode = (dataNode is Map)
            ? (dataNode['resultCode'] as num?)?.toInt()
            : null;

        final String? resultDesc = (dataNode is Map)
            ? dataNode['resultDesc']?.toString()
            : null;

        debugPrint('payStatus=$payStatus  resultCode=$resultCode');

        if (payStatus == 'completed') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _isSubmitting = false);
            _goToStep(DonationStep.success);
            _successCtrl.forward(from: 0);
          }

        } else if (payStatus == 'cancelled' || resultCode == 1032) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _errorMsg = 'Payment was cancelled. '
                  'You can try again whenever you\'re ready.';
            });
            _goToStep(DonationStep.error);
            _errorCtrl.forward(from: 0);
          }

        } else if (payStatus == 'failed') {
          _pollTimer?.cancel();
          // Distinguish insufficient funds (resultCode 1) from other failures
          String msg;
          if (resultCode == 1) {
            msg = 'Insufficient M-Pesa balance. '
                'Please top up and try again.';
          } else if (resultDesc != null && resultDesc.isNotEmpty) {
            msg = resultDesc;
          } else {
            msg = 'M-Pesa payment failed. Please try again.';
          }
          if (mounted) {
            setState(() { _isSubmitting = false; _errorMsg = msg; });
            _goToStep(DonationStep.error);
            _errorCtrl.forward(from: 0);
          }

        }
        // pending → keep polling silently
      } catch (_) {
        // Network hiccup — retry on next tick, don't surface error yet
      }
    });
  }

  // ── Paystack stub ─────────────────────────────────────────────────────────
  void _payPaystack() {
    _goToStep(DonationStep.processing);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _errorMsg =
            'Paystack checkout is coming soon. Please use M-Pesa for now.');
        _goToStep(DonationStep.error);
        _errorCtrl.forward(from: 0);
      }
    });
  }

  // ── Share ─────────────────────────────────────────────────────────────────
  Future<void> _share() async {
    final text = 'I just donated to "${widget.campaign.title}" on InuaFund! '
        'Support this cause: https://inuafund.co.ke';
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Share link copied to clipboard!');
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _goingForward   = false;
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
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final c in [_emailCtrl, _nameCtrl, _phoneCtrl, _amountCtrl]) {
      c.removeListener(_onFormChanged);
      c.dispose();
    }
    _successCtrl.dispose();
    _confettiCtrl.dispose();
    _errorCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _snow,
      appBar: AppBar(
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
          onPressed: () { _pollTimer?.cancel(); Navigator.pop(context); },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          transitionBuilder: (child, anim) {
            final begin = _goingForward
                ? const Offset(0.05, 0) : const Offset(-0.05, 0);
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
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
              particles: _particles, progress: _confettiCtrl.value),
          ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // DETAILS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildDetails() {
    final amts = _amounts;
    return SingleChildScrollView(
      key: const ValueKey('details'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _CampaignCard(campaign: widget.campaign, fmt: _fmt),
          const SizedBox(height: 24),

          // ── Amount ────────────────────────────────────────────────────────
          _SectionLabel(icon: Icons.volunteer_activism_rounded,
              label: 'Choose amount', sub: widget.campaign.currency),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.6,
            children: _presets.map((p) => _AmountChip(
              amount: p.$1, label: p.$2, currency: widget.campaign.currency,
              selected: _selectedPreset == p.$1, isPopular: p.$1 == _popular,
              onTap: () => setState(() {
                _selectedPreset  = p.$1;
                _amountCtrl.text = p.$1.toStringAsFixed(0);
              }),
            )).toList(),
          ),
          const SizedBox(height: 10),
          _StyledField(
            ctrl: _amountCtrl,
            hint: 'Custom amount (min ${widget.campaign.currency} 10)',
            icon: Icons.edit_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _selectedPreset = null),
            validator: (v) {
              final n = double.tryParse(v ?? '') ?? 0;
              return n < 10 ? 'Minimum is ${widget.campaign.currency} 10' : null;
            },
          ),

          // ── Fee ───────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionLabel(icon: Icons.receipt_long_rounded,
              label: 'Platform fee', sub: '${_feePct.toStringAsFixed(0)}%'),
          const SizedBox(height: 12),
          _FeeToggleCard(
              userPaysFee: _userPaysFee,
              onChanged: (v) => setState(() => _userPaysFee = v)),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: _entered >= 10
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _BreakdownCard(
                      donation: double.parse(amts.donation.toStringAsFixed(2)),
                      fee:      double.parse(amts.fee.toStringAsFixed(2)),
                      total:    _paymentMethod == 'mpesa'
                          ? amts.total.roundToDouble()
                          : double.parse(amts.total.toStringAsFixed(2)),
                      fmt: _fmt,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Personal details ──────────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionLabel(icon: Icons.person_outline_rounded, label: 'Your details'),
          const SizedBox(height: 12),
          _StyledField(
            ctrl: _emailCtrl, hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v?.contains('@') ?? false) ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 10),
          _StyledField(
            ctrl: _nameCtrl, hint: 'Full name',
            icon: Icons.badge_outlined, enabled: !_isAnonymous,
            validator: (v) =>
                !_isAnonymous && (v?.isEmpty ?? true) ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),
          _StyledField(
            ctrl: _phoneCtrl, hint: 'Phone  07XXXXXXXXX',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => RegExp(r'^07\d{8}$').hasMatch(v ?? '')
                ? null : 'Use format 07XXXXXXXXX',
          ),
          const SizedBox(height: 10),
          _CheckRow(
            label: 'Donate anonymously', value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v)),

          // ── Payment method ────────────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionLabel(icon: Icons.payment_rounded, label: 'Payment method'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _PayMethodCard(
              label: 'M-Pesa', icon: Icons.phone_android_rounded,
              color: const Color(0xFF00A550),
              selected: _paymentMethod == 'mpesa',
              onTap: () => setState(() => _paymentMethod = 'mpesa'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PayMethodCard(
              label: 'Paystack', icon: Icons.credit_card_rounded,
              color: const Color(0xFF0AA83F),
              selected: _paymentMethod == 'paystack',
              onTap: () => setState(() => _paymentMethod = 'paystack'),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 13, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _paymentMethod == 'mpesa'
                  ? 'M-Pesa supports Safaricom numbers only.'
                  : 'Paystack supports cards, Airtel Money, and more.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: Color(0xFF3B82F6)),
            )),
          ]),

          // ── CTA ───────────────────────────────────────────────────────────
          const SizedBox(height: 28),
          _DonateButton(
            isValid: _isFormValid,
            method: _paymentMethod,
            label: _entered < 10
                ? 'Minimum ${widget.campaign.currency} 10'
                : _isFormValid
                    ? 'Donate ${_fmt(_paymentMethod == "mpesa"
                          ? _amounts.total.roundToDouble()
                          : double.parse(_amounts.total.toStringAsFixed(2)))} '
                      'with ${_paymentMethod == "mpesa" ? "M-Pesa" : "Paystack"}'
                    : 'Complete form to continue',
            onTap: _isFormValid
                ? () => _paymentMethod == 'mpesa' ? _payMpesa() : _payPaystack()
                : null,
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.lock_outline_rounded, size: 12, color: kMist),
            SizedBox(width: 5),
            Text('Secured by InuaFund',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kMist)),
          ]),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROCESSING
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildProcessing() => _ProcessingView(
    key: const ValueKey('processing'),
    phone: _phoneCtrl.text,
    method: _paymentMethod,
    onCancel: _reset,
  );

  // ════════════════════════════════════════════════════════════════════════
  // SUCCESS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildSuccess() {
    if (_successCtrl.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _successCtrl.forward();
      });
    }
    return _SuccessView(
      key: const ValueKey('success'),
      ctrl: _successCtrl,
      campaignTitle: widget.campaign.title,
      isAnonymous: _isAnonymous,
      name: _nameCtrl.text.trim(),
      amount: _fmt(_paymentMethod == 'mpesa'
          ? _amounts.total.roundToDouble()
          : double.parse(_amounts.total.toStringAsFixed(2))),
      onShare: _share,
      onDonateAgain: _reset,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ERROR
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildError() {
    if (_errorCtrl.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _errorCtrl.forward();
      });
    }
    return _ErrorView(
      key: const ValueKey('error'),
      ctrl: _errorCtrl,
      message: _errorMsg,
      onRetry: _reset,
      onBack: () { _pollTimer?.cancel(); Navigator.pop(context); },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESSING VIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _ProcessingView extends StatefulWidget {
  final String phone, method;
  final VoidCallback onCancel;
  const _ProcessingView({super.key, required this.phone,
      required this.method, required this.onCancel});

  @override
  State<_ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<_ProcessingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() => _elapsed++); });
  }

  @override
  void dispose() { _pulse.dispose(); _timer?.cancel(); super.dispose(); }

  String get _timeLeft {
    final rem = 300 - _elapsed;
    if (rem <= 0) return '0:00';
    return '${rem ~/ 60}:${(rem % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(const Color(0xFFDCFCE7),
                  const Color(0xFFBBF7D0), _pulse.value),
            ),
            child: child,
          ),
          child: ClipOval(
            child: Image.network(
              '../../../../assets/images/Donation Processing.jpeg',
              width: 160, height: 160, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.hourglass_top_rounded,
                    color: Color(0xFF16A34A), size: 64)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          widget.method == 'mpesa'
              ? 'Waiting for payment…'
              : 'Processing donation…',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 22, color: Color(0xFF0F172A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        if (widget.method == 'mpesa')
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  color: Color(0xFF64748B), height: 1.7),
              children: [
                const TextSpan(text: 'An M-Pesa prompt was sent to\n'),
                TextSpan(text: widget.phone,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
                const TextSpan(text: '\n\nEnter your PIN to complete.'),
              ],
            ),
          )
        else
          const Text('Please wait while we securely process\nyour contribution.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                color: Color(0xFF64748B), height: 1.7)),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            backgroundColor: Color(0xFFDCFCE7),
            valueColor: AlwaysStoppedAnimation(Color(0xFF22C55E)),
            minHeight: 6),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Checking every 5s…',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                color: Color(0xFF94A3B8))),
          Row(children: [
            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF94A3B8)),
            const SizedBox(width: 3),
            Text('Times out $_timeLeft',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: Color(0xFF94A3B8))),
          ]),
        ]),
        const SizedBox(height: 28),
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                fontSize: 13, color: Color(0xFF64748B))),
        ),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS VIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _SuccessView extends StatelessWidget {
  final AnimationController ctrl;
  final String campaignTitle, name, amount;
  final bool isAnonymous;
  final VoidCallback onShare, onDonateAgain;

  const _SuccessView({super.key, required this.ctrl,
      required this.campaignTitle, required this.isAnonymous,
      required this.name, required this.amount,
      required this.onShare, required this.onDonateAgain});

  @override
  Widget build(BuildContext context) {
    final displayName = isAnonymous ? 'Anonymous Donor'
        : (name.isNotEmpty ? name : 'Generous Donor');

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
            child: ClipOval(
              child: Image.network(
                '../../../../assets/images/SuccessDonation.jpeg',
                width: 140, height: 140, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 140, height: 140,
                  decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF16A34A), size: 64)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: CurvedAnimation(
                parent: ctrl, curve: const Interval(0.25, 1.0)),
            child: Column(children: [
              const Text('Thank you,',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 17,
                    color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text('$displayName!',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 26,
                    color: Color(0xFF0F172A)),
                textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                ),
                child: Column(children: [
                  const Text('Your contribution',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(amount,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800, fontSize: 28,
                        color: Color(0xFF16A34A))),
                  const SizedBox(height: 8),
                  Container(height: 1, color: const Color(0xFFD1FAE5)),
                  const SizedBox(height: 8),
                  Text('supports "$campaignTitle"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                        color: Color(0xFF166534), fontWeight: FontWeight.w500,
                        height: 1.4)),
                ]),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + i * 120),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.star_rounded,
                        color: Color(0xFFFBBF24), size: 28)),
                ))),
              const SizedBox(height: 6),
              const Text('You made a real difference today',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: Color(0xFF94A3B8))),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded,
                      size: 16, color: Color(0xFF3B82F6)),
                  label: const Text('Share',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: Color(0xFF3B82F6))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: onDonateAgain,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Donate again',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR VIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final AnimationController ctrl;
  final String? message;
  final VoidCallback onRetry, onBack;

  const _ErrorView({super.key, required this.ctrl, this.message,
      required this.onRetry, required this.onBack});

  // Pick the right icon/colour based on the error message
  bool get _isCancelled =>
      message?.toLowerCase().contains('cancel') ?? false;
  bool get _isInsufficient =>
      message?.toLowerCase().contains('insufficient') ?? false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = _isCancelled
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);
    final Color bgColor = _isCancelled
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFEF2F2);
    final Color borderColor = _isCancelled
        ? const Color(0xFFFDE68A)
        : const Color(0xFFFECACA);
    final Color textColor = _isCancelled
        ? const Color(0xFF92400E)
        : const Color(0xFF991B1B);
    final IconData icon = _isCancelled
        ? Icons.cancel_outlined
        : _isInsufficient
            ? Icons.account_balance_wallet_outlined
            : Icons.error_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
            child: Stack(alignment: Alignment.center, children: [
              ClipOval(
                child: Image.network(
                  '../../../../assets/images/FailedDonation.jpeg',
                  width: 130, height: 130, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.10),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: iconColor, size: 56)),
                ),
              ),
              // Tinted overlay so error colour still reads clearly
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(0.18)),
              ),
              Icon(icon, color: Colors.white, size: 48),
            ]),
          ),
          const SizedBox(height: 24),
          Text(
            _isCancelled
                ? 'Payment Cancelled'
                : _isInsufficient
                    ? 'Insufficient Balance'
                    : 'Payment Failed',
            style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 24,
                color: Color(0xFF0F172A)),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              message ??
                  'There was an issue processing your payment.\n'
                  'Please check your details and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: textColor, height: 1.6),
            ),
          ),
          if (_isInsufficient) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Top up your M-Pesa and try again, '
                  'or try a smaller amount.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      color: Color(0xFF166534), height: 1.5),
                )),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again',
                style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCancelled
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Go back',
                style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: Color(0xFF64748B))),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Confetti
// ═══════════════════════════════════════════════════════════════════════════════
enum _ConfettiShape { rect, circle, triangle }

class _ConfettiParticle {
  final double x, delay, size, spin;
  final Color color;
  final _ConfettiShape shape;
  _ConfettiParticle({required this.x, required this.delay, required this.size,
      required this.spin, required this.color,
      this.shape = _ConfettiShape.rect});
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
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t == 0) continue;
      final opacity = (t < 0.8 ? 1.0 : (1 - t) / 0.2).clamp(0.0, 1.0);
      final paint   = Paint()..color = p.color.withOpacity(opacity);
      // Horizontal drift + vertical fall — mirrors React velocityX/velocityY
      final x = p.x * size.width + math.sin(t * math.pi * 2 + p.spin) * 40 +
                (p.spin * 20 * t);
      final y = t * (size.height + 100) - 50;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * math.pi * 4); // 720° like React animate
      switch (p.shape) {
        case _ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        case _ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
        case _ConfettiShape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero,
                  width: p.size, height: p.size * 0.5),
              const Radius.circular(2)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════
class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final String Function(double) fmt;
  const _CampaignCard({required this.campaign, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final progress = (campaign.pct / 100).clamp(0.0, 1.0);
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
              ? Image.network(campaign.featuredImage!, width: 60, height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback())
              : _fallback(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(campaign.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 13, color: Color(0xFF0F172A), height: 1.3)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 6,
                backgroundColor: const Color(0xFFD1FAE5),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)))),
          ),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: Text(
              '${fmt(campaign.raised)} of ${fmt(campaign.goal)}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                  color: Color(0xFF6B7280)))),
            const Icon(Icons.people_outline_rounded, size: 11, color: Color(0xFF6B7280)),
            const SizedBox(width: 3),
            Text('${campaign.donors}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                  color: Color(0xFF6B7280))),
          ]),
        ])),
      ]),
    );
  }

  Widget _fallback() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E).withOpacity(0.12),
      borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.campaign_rounded, color: Color(0xFF22C55E), size: 28));
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
          color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: const Color(0xFF16A34A))),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
    if (sub != null) ...[
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(6)),
        child: Text(sub!, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)))),
    ],
  ]);
}

class _AmountChip extends StatefulWidget {
  final double amount;
  final String label, currency;
  final bool selected, isPopular;
  final VoidCallback onTap;
  const _AmountChip({required this.amount, required this.label,
      required this.currency, required this.selected,
      required this.isPopular, required this.onTap});

  @override
  State<_AmountChip> createState() => _AmountChipState();
}

class _AmountChipState extends State<_AmountChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _sc;

  @override
  void initState() {
    super.initState();
    _sc = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.94, upperBound: 1.0, value: 1.0);
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { _sc.reverse().then((_) => _sc.forward()); widget.onTap(); },
    child: ScaleTransition(
      scale: _sc,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.selected ? const Color(0xFF16A34A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected
                ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: widget.selected ? 2 : 1.5),
          boxShadow: widget.selected
              ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.22),
                  blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Expanded(child: Text(
              '${widget.currency} ${widget.amount.toStringAsFixed(0)}',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: widget.selected ? Colors.white : const Color(0xFF0F172A)))),
            if (widget.isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('🔥 Hot', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: widget.selected
                        ? Colors.white : const Color(0xFFD97706)))),
          ]),
          Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5,
                color: widget.selected
                    ? Colors.white70 : const Color(0xFF94A3B8))),
        ]),
      ),
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

  const _StyledField({required this.ctrl, required this.hint,
      required this.icon, this.keyboardType, this.inputFormatters,
      this.enabled = true, this.validator, this.onChanged});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, enabled: enabled, keyboardType: keyboardType,
    inputFormatters: inputFormatters, validator: validator, onChanged: onChanged,
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF0F172A)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
          color: Color(0xFFCBD5E1)),
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
  const _FeeOption({required this.label, required this.sub,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1.5),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20, height: 20,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: selected ? const Color(0xFF16A34A) : Colors.transparent,
            border: Border.all(
              color: selected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: 2)),
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
      _BRow(label: 'Your donation', value: fmt(donation), bold: false),
      const SizedBox(height: 6),
      _BRow(label: 'Platform fee',  value: fmt(fee),      bold: false),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Color(0xFFD1FAE5), thickness: 1)),
      _BRow(label: 'Total charge',  value: fmt(total),    bold: true),
    ]),
  );
}

class _BRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _BRow({required this.label, required this.value, required this.bold});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5,
        color: bold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Poppins',
        fontSize: bold ? 14 : 12.5, fontWeight: FontWeight.w700,
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
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: value ? 2 : 1.5),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20, height: 20,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
            color: value ? const Color(0xFF16A34A) : Colors.transparent,
            border: Border.all(
              color: value ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: 2)),
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
  const _PayMethodCard({required this.label, required this.icon,
      required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.28),
                blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20,
            color: selected ? Colors.white : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 14,
            color: selected ? Colors.white : const Color(0xFF64748B))),
      ]),
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
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque, // prevents double-fire via scroll view
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
      height: 58, width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isValid ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
        boxShadow: isValid
            ? [const BoxShadow(color: Color(0x4016A34A),
                blurRadius: 18, offset: Offset(0, 7))]
            : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(method == 'mpesa'
            ? Icons.phone_android_rounded : Icons.credit_card_rounded,
            size: 20,
            color: isValid ? Colors.white : const Color(0xFFCBD5E1)),
        const SizedBox(width: 10),
        Flexible(child: Text(label,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isValid ? Colors.white : const Color(0xFFCBD5E1)),
          overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}