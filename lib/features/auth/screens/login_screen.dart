import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/network/auth_service.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
class _C {
  static const green      = Color(0xFF1DB954);
  static const greenLight = Color(0xFF4ADE80);
  static const gold       = Color(0xFFF5A623);
  static const dark       = Color(0xFF0A0F0D);
  static const card       = Color(0xEA061409);
  static const muted      = Color(0x88FFFFFF);
  static const border     = Color(0x401DB954);
  static const error      = Color(0xFFEF4444);
  static const inputBg    = Color(0x14FFFFFF);
  static const inputBrd   = Color(0x26FFFFFF);
  static const success    = Color(0xFF22C55E);
}

// ─── API ──────────────────────────────────────────────────────────────────────
class _Api {
  static const _storage   = FlutterSecureStorage();
  static final _userDio   = _dio('https://api.inuafund.co.ke/api/users');
  static final _baseDio   = _dio('https://api.inuafund.co.ke/api');
  static final _google    = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '834391125130-bsmhrlr77l261543fek7a6er66pa6hs4.apps.googleusercontent.com',
  );

  static Dio _dio(String base) => Dio(BaseOptions(
    baseUrl: base, connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));

  static Future<void> _persist(Map<String, dynamic> d) async {
    await _storage.write(key: 'jwt_token',   value: d['token'].toString());
    await _storage.write(key: 'user_id',     value: d['_id']?.toString()        ?? '');
    await _storage.write(key: 'username',    value: d['username']?.toString()   ?? '');
    await _storage.write(key: 'email',       value: d['email']?.toString()      ?? '');
    await _storage.write(key: 'fullName',    value: d['fullName']?.toString()   ?? '');
    await _storage.write(key: 'role',        value: d['role']?.toString()       ?? '');
    await _storage.write(key: 'phoneNumber', value: d['phoneNumber']?.toString() ?? '');
  }

  static String _msg(Map d, String fb) => (d['message'] as String?) ?? fb;

  static String parseDioError(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      return (d is Map ? d['message'] : null) ?? e.message ?? 'Network error.';
    }
    return e.toString();
  }

  static Future<Map<String, dynamic>> _post(Dio dio, String path, Map body) async {
    final res = await dio.post(path, data: body);
    return res.data as Map<String, dynamic>;
  }

  static Future<void> login({required String email, required String password}) async {
    final data = await _post(_userDio, '/login', {'email': email, 'password': password});
    if (data['token'] == null) throw _msg(data, 'Login failed.');
    await _persist(data);
  }

  static Future<void> register({
    required String username, required String email, required String password,
    required String fullName, required String phoneNumber, required String country,
  }) async {
    final data = await _post(_userDio, '/register', {
      'username': username, 'email': email, 'password': password,
      'fullName': fullName, 'phoneNumber': phoneNumber, 'country': country,
    });
    if (data['token'] == null) throw _msg(data, 'Registration failed.');
    await _persist(data);
  }

  static Future<void> _googleAuth(String path, String fb) async {
    final user = await _google.signIn();
    if (user == null) throw 'Google sign-in was cancelled.';
    final idToken = (await user.authentication).idToken;
    if (idToken == null) throw 'Could not retrieve Google ID token.';
    final data = await _post(_baseDio, path, {'token': idToken});
    if (data['token'] == null) throw _msg(data, fb);
    await _persist(data);
  }

  static Future<void> googleLogin()    => _googleAuth('/Gauth/google-login',    'Google login failed.');
  static Future<void> googleRegister() => _googleAuth('/Gauth/google-register', 'Google registration failed.');

  static Future<void> forgotPassword(String email) async {
    final data = await _post(_baseDio, '/auth/forgot-password', {'email': email});
    if (data['token'] == null && data['message'] == null) throw 'Failed to process request.';
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
    await _google.signOut();
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 33, height: 33,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: _C.green.withOpacity(0.45), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset('assets/icon.png', width: 33, height: 33, fit: BoxFit.cover),
      ),
    ),
    const SizedBox(width: 8),
    RichText(text: const TextSpan(
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
      children: [
        TextSpan(text: 'Inua', style: TextStyle(color: Colors.white)),
        TextSpan(text: 'Fund', style: TextStyle(color: _C.green)),
      ],
    )),
  ]);
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: _C.card, borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _C.border),
      boxShadow: [BoxShadow(color: _C.green.withOpacity(0.08), blurRadius: 32)],
    ),
    child: child,
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure, enabled;
  final Widget? suffix;
  final TextInputType? kbType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _Field({
    required this.ctrl, required this.hint, required this.icon,
    this.obscure = false, this.enabled = true, this.suffix,
    this.kbType, this.validator, this.onChanged,
  });

  static InputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, obscureText: obscure, keyboardType: kbType,
    onChanged: onChanged, enabled: enabled,
    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
    validator: validator,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: _C.muted, fontFamily: 'Poppins', fontSize: 14),
      prefixIcon: Icon(icon, color: _C.muted, size: 20), suffixIcon: suffix,
      filled: true, fillColor: enabled ? _C.inputBg : _C.inputBg.withOpacity(0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:             _border(_C.inputBrd),
      enabledBorder:      _border(_C.inputBrd),
      focusedBorder:      _border(_C.green, 1.5),
      errorBorder:        _border(_C.error, 1.2),
      focusedErrorBorder: _border(_C.error, 1.5),
      disabledBorder:     _border(_C.inputBrd.withOpacity(0.4)),
      errorStyle: const TextStyle(color: _C.error, fontSize: 11, fontFamily: 'Poppins'),
    ),
  );
}

class _Btn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined;
  const _Btn({required this.label, required this.onTap,
    this.loading = false, this.icon, this.outlined = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: outlined
        ? OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.muted,
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          )
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.green,
              disabledBackgroundColor: _C.green.withOpacity(0.45),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8, shadowColor: _C.green.withOpacity(0.4),
            ),
            child: loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
                    if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
                  ]),
          ),
  );
}

class _GoogleBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _GoogleBtn({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.05),
        side: BorderSide(color: Colors.white.withOpacity(0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: const Size(20, 20), painter: _GoogleIcon()),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
    ),
  );
}

class _GoogleIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    for (final s in [
      (0.0, const Color(0xFF4285F4)), (90.0, const Color(0xFF34A853)),
      (180.0, const Color(0xFFFBBC05)), (270.0, const Color(0xFFEA4335)),
    ]) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), s.$1 * pi / 180,
          pi / 2, false, Paint()..color = s.$2..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('OR', style: TextStyle(color: _C.muted, fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w600))),
    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
  ]);
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.error.withOpacity(0.10), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.error.withOpacity(0.35)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: _C.error, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(color: _C.error, fontSize: 12, fontFamily: 'Poppins'))),
    ]),
  );
}

class _Checkbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _Checkbox({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(width: 22, height: 22,
    child: Checkbox(
      value: value, onChanged: onChanged,
      activeColor: _C.green, checkColor: Colors.white,
      side: BorderSide(color: Colors.white.withOpacity(0.30), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}

class _CheckRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final String? link;
  final VoidCallback? onLinkTap;
  const _CheckRow({required this.value, required this.onChanged, required this.label, this.link, this.onLinkTap});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Checkbox(value: value, onChanged: onChanged),
    const SizedBox(width: 10),
    Expanded(child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(text: TextSpan(
        style: const TextStyle(color: _C.muted, fontSize: 12, fontFamily: 'Poppins'),
        children: [
          TextSpan(text: label),
          if (link != null) WidgetSpan(child: GestureDetector(
            onTap: onLinkTap,
            child: Text(link!, style: const TextStyle(color: _C.green, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          )),
        ],
      )),
    )),
  ]);
}

class _StarField extends StatefulWidget {
  const _StarField();
  @override State<_StarField> createState() => _StarFieldState();
}
class _StarFieldState extends State<_StarField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(painter: _StarPainter(_c.value), size: Size.infinite),
  );
}
class _StarPainter extends CustomPainter {
  final double t;
  _StarPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); final p = Paint();
    for (int i = 0; i < 40; i++) {
      final op = (0.2 + rng.nextDouble() * 0.45 + (i % 3 == 0 ? t * 0.3 : 0)).clamp(0.0, 1.0);
      p.color = Colors.white.withOpacity(op);
      canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.55),
          0.7 + rng.nextDouble() * 1.2, p);
    }
  }
  @override bool shouldRepaint(_StarPainter o) => o.t != t;
}

Widget _bg(List<Color> colors) => Container(
  decoration: BoxDecoration(gradient: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)));

// ─── Screen base ──────────────────────────────────────────────────────────────
mixin _AuthScreenMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  bool loading = false, gLoading = false;
  String? error;
  bool get busy => loading || gLoading;

  late final AnimationController fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final Animation<double> fade = CurvedAnimation(parent: fadeCtrl, curve: Curves.easeOut);
  late final Animation<Offset> slide = Tween<Offset>(
    begin: const Offset(0, 0.06), end: Offset.zero).animate(fade);

  @override
  void dispose() { fadeCtrl.dispose(); super.dispose(); }

  Future<void> run(Future<void> Function() fn, {bool isGoogle = false}) async {
    setState(() { isGoogle ? gLoading = true : loading = true; error = null; });
    try {
      await fn();
      if (mounted) {
        await context.read<AuthProvider>().refreshAuthState();
        context.go('/home');
      }
    } on DioException catch (e) {
      if (mounted) setState(() => error = _Api.parseDioError(e));
    } catch (e) {
      final msg = e.toString();
      if (mounted && (!isGoogle || !msg.contains('cancelled'))) {
        setState(() => error = msg);
      }
    } finally {
      if (mounted) setState(() { isGoogle ? gLoading = false : loading = false; });
    }
  }

  Widget anim(Widget child) => FadeTransition(opacity: fade,
      child: SlideTransition(position: slide, child: child));
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen>
    with TickerProviderStateMixin, _AuthScreenMixin {
  final _fk    = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _obscure = true, _remember = false;

  @override void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.dark,
    body: Stack(children: [
      _bg(const [Color(0xFF0D2B1A), Color(0xFF061409)]),
      const _StarField(),
      SafeArea(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 28),
            _Logo(),
            const SizedBox(height: 36),
            anim(Column(children: [
              RichText(text: const TextSpan(
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'Poppins', height: 1.15),
                children: [
                  TextSpan(text: 'Welcome ', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Back',     style: TextStyle(color: _C.green)),
                ],
              )),
              const SizedBox(height: 8),
              const Text('Sign in to continue making a difference',
                  style: TextStyle(color: _C.muted, fontSize: 14, fontFamily: 'Poppins')),
            ])),
            const SizedBox(height: 32),
            anim(_GlassCard(child: Form(key: _fk, child: Column(children: [
              if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 16)],
              _Field(ctrl: _email, hint: 'Email address', icon: Icons.mail_outline_rounded,
                kbType: TextInputType.emailAddress, enabled: !busy,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email';
                  return null;
                }),
              const SizedBox(height: 14),
              _Field(ctrl: _pass, hint: 'Password', icon: Icons.lock_outline_rounded,
                obscure: _obscure, enabled: !busy,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _C.muted, size: 20),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  _Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false)),
                  const SizedBox(width: 8),
                  const Text('Remember me', style: TextStyle(color: _C.muted, fontSize: 12, fontFamily: 'Poppins')),
                ]),
                GestureDetector(
                  onTap: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?', style: TextStyle(color: _C.green, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                ),
              ]),
              const SizedBox(height: 24),
              _Btn(label: 'Sign In', loading: loading, onTap: busy ? null : () {
                if (_fk.currentState!.validate()) run(() => _Api.login(email: _email.text.trim(), password: _pass.text));
              }),
              const SizedBox(height: 16),
              _OrDivider(),
              const SizedBox(height: 16),
              _GoogleBtn(label: 'Continue with Google', loading: gLoading,
                  onTap: busy ? null : () => run(_Api.googleLogin, isGoogle: true)),
            ])))),
            const SizedBox(height: 24),
            FadeTransition(opacity: fade, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account? ", style: TextStyle(color: _C.muted, fontSize: 13, fontFamily: 'Poppins')),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: const Text('Sign up', style: TextStyle(color: _C.green, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ])),
            const SizedBox(height: 40),
          ]),
        ),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterState();
}
class _RegisterState extends State<RegisterScreen>
    with TickerProviderStateMixin, _AuthScreenMixin {
  final _s1k       = GlobalKey<FormState>();
  final _s2k       = GlobalKey<FormState>();
  final _username  = TextEditingController();
  final _email     = TextEditingController();
  final _pass      = TextEditingController();
  final _confirm   = TextEditingController();
  final _fullName  = TextEditingController();
  final _phone     = TextEditingController();

  int    _step        = 1;
  bool   _obscureP    = true, _obscureC = true, _agree = false, _news = false;
  double _strength    = 0;
  String _county      = '';

  @override
  void dispose() {
    _username.dispose(); _email.dispose(); _pass.dispose();
    _confirm.dispose(); _fullName.dispose(); _phone.dispose();
    super.dispose();
  }

  static const _counties = [
    'Baringo','Bomet','Bungoma','Busia','Elgeyo/Marakwet','Embu','Garissa',
    'Homa Bay','Isiolo','Kajiado','Kakamega','Kericho','Kiambu','Kilifi',
    'Kirinyaga','Kisii','Kisumu','Kitui','Kwale','Laikipia','Lamu',
    'Machakos','Makueni','Mandera','Marsabit','Meru','Migori','Mombasa',
    "Murang'a",'Nairobi','Nakuru','Nandi','Narok','Nyamira','Nyandarua',
    'Nyeri','Samburu','Siaya','Taita/Taveta','Tana River','Tharaka Nithi',
    'Trans Nzoia','Turkana','Uasin Gishu','Vihiga','Wajir','West Pokot',
  ];

  void _calcStrength(String p) {
    double s = 0;
    if (p.length >= 8)                                    s += 20;
    if (RegExp(r'[a-z]').hasMatch(p))                    s += 20;
    if (RegExp(r'[A-Z]').hasMatch(p))                    s += 20;
    if (RegExp(r'\d').hasMatch(p))                       s += 20;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) s += 20;
    setState(() => _strength = s);
  }

  String get _sLabel => _pass.text.isEmpty ? 'Not set'
      : _strength < 40 ? 'Weak' : _strength < 60 ? 'Fair'
      : _strength < 80 ? 'Good' : 'Strong';

  Color get _sColor => _strength < 40 ? _C.error : _strength < 60 ? _C.gold
      : _strength < 80 ? _C.greenLight : _C.green;

  void _toStep(int s) => fadeCtrl.reverse().then((_) {
    setState(() { _step = s; error = null; });
    fadeCtrl.forward();
  });

  void _handleError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('username') || lower.contains('email')) {
      fadeCtrl.reverse().then((_) {
        setState(() { _step = 1; error = msg; });
        fadeCtrl.forward();
      });
    } else { setState(() => error = msg); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.dark,
    body: Stack(children: [
      _bg(const [Color(0xFF0A1A2E), Color(0xFF061020)]),
      const _StarField(),
      SafeArea(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Logo(),
              GestureDetector(
                onTap: () => context.push('/login'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Text('Sign In', style: TextStyle(color: _C.muted, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            FadeTransition(opacity: fade, child: Column(children: [
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Poppins', height: 1.15),
                children: [
                  TextSpan(text: _step == 1 ? 'Create ' : 'Almost ', style: const TextStyle(color: Colors.white)),
                  TextSpan(text: _step == 1 ? 'Account' : 'There!', style: const TextStyle(color: _C.green)),
                ],
              )),
              const SizedBox(height: 14),
              _StepIndicator(current: _step),
            ])),
            const SizedBox(height: 24),
            anim(_GlassCard(child: _step == 1 ? _step1() : _step2())),
            const SizedBox(height: 24),
            FadeTransition(opacity: fade, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account? ', style: TextStyle(color: _C.muted, fontSize: 13, fontFamily: 'Poppins')),
              GestureDetector(
                onTap: () => context.push('/login'),
                child: const Text('Sign in', style: TextStyle(color: _C.green, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ])),
            const SizedBox(height: 40),
          ]),
        ),
      )),
    ]),
  );

  Widget _step1() => Form(key: _s1k, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 16)],
    _Field(ctrl: _username, hint: 'Username', icon: Icons.person_outline_rounded, enabled: !busy,
        validator: (v) => (v == null || v.isEmpty) ? 'Username is required' : null),
    const SizedBox(height: 14),
    _Field(ctrl: _email, hint: 'Email address', icon: Icons.mail_outline_rounded,
        kbType: TextInputType.emailAddress, enabled: !busy,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Email is required';
          if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email';
          return null;
        }),
    const SizedBox(height: 14),
    _Field(ctrl: _pass, hint: 'Password', icon: Icons.lock_outline_rounded,
        obscure: _obscureP, enabled: !busy, onChanged: _calcStrength,
        suffix: IconButton(
          onPressed: () => setState(() => _obscureP = !_obscureP),
          icon: Icon(_obscureP ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _C.muted, size: 20),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Password is required';
          if (_strength < 60) return 'Password is too weak';
          return null;
        }),
    if (_pass.text.isNotEmpty) ...[
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Strength: $_sLabel', style: TextStyle(color: _sColor, fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        Text('${_strength.toInt()}%', style: TextStyle(color: _sColor, fontSize: 11, fontFamily: 'Poppins')),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: _strength / 100, minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_sColor))),
    ],
    const SizedBox(height: 14),
    _Field(ctrl: _confirm, hint: 'Confirm Password', icon: Icons.lock_outline_rounded,
        obscure: _obscureC, enabled: !busy,
        suffix: IconButton(
          onPressed: () => setState(() => _obscureC = !_obscureC),
          icon: Icon(_obscureC ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _C.muted, size: 20),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please confirm your password';
          if (v != _pass.text) return 'Passwords do not match';
          return null;
        }),
    const SizedBox(height: 24),
    _Btn(label: 'Continue', icon: Icons.arrow_forward_rounded, onTap: busy ? null : () {
      if (_s1k.currentState!.validate()) _toStep(2);
    }),
    const SizedBox(height: 16),
    _OrDivider(),
    const SizedBox(height: 16),
    _GoogleBtn(label: 'Sign up with Google', loading: gLoading,
        onTap: busy ? null : () => run(_Api.googleRegister, isGoogle: true)),
  ]));

  Widget _step2() => Form(key: _s2k, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 16)],
    _Field(ctrl: _fullName, hint: 'Full Name', icon: Icons.badge_outlined, enabled: !busy,
        validator: (v) => (v == null || v.isEmpty) ? 'Full name is required' : null),
    const SizedBox(height: 14),
    _Field(ctrl: _phone, hint: 'Phone Number', icon: Icons.phone_outlined,
        kbType: TextInputType.phone, enabled: !busy,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Phone number is required';
          if (!RegExp(r'^\+?[0-9\s\-()]{7,20}$').hasMatch(v)) return 'Invalid phone format';
          return null;
        }),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      initialValue: _county.isEmpty ? null : _county,
      onChanged: busy ? null : (v) => setState(() => _county = v ?? ''),
      validator: (v) => (v == null || v.isEmpty) ? 'County is required' : null,
      dropdownColor: const Color(0xFF0E1F14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted),
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
      hint: const Row(children: [
        Icon(Icons.location_on_outlined, color: _C.muted, size: 20), SizedBox(width: 12),
        Text('Select County', style: TextStyle(color: _C.muted, fontFamily: 'Poppins', fontSize: 14)),
      ]),
      decoration: InputDecoration(
        filled: true, fillColor: _C.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.inputBrd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.inputBrd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.green, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.error)),
        errorStyle: const TextStyle(color: _C.error, fontSize: 11, fontFamily: 'Poppins'),
      ),
      items: _counties.map((c) => DropdownMenuItem(value: c,
          child: Text(c, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)))).toList(),
    ),
    const SizedBox(height: 20),
    _CheckRow(value: _agree, label: 'I agree to the ', link: 'Terms & Conditions',
        onLinkTap: () => context.push('/terms'),
        onChanged: (v) => setState(() { _agree = v ?? false; error = null; })),
    const SizedBox(height: 10),
    _CheckRow(value: _news, label: 'Subscribe to newsletter for updates',
        onChanged: (v) => setState(() => _news = v ?? false)),
    const SizedBox(height: 24),
    Row(children: [
      Expanded(child: _Btn(label: 'Back', icon: Icons.arrow_back_rounded, outlined: true,
          onTap: busy ? null : () => _toStep(1))),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: _Btn(label: 'Create Account', loading: loading, onTap: busy ? null : () {
        if (!_s2k.currentState!.validate()) return;
        if (!_agree) { setState(() => error = 'Please agree to the Terms and Conditions.'); return; }
        run(() => _Api.register(
          username: _username.text.trim(), email: _email.text.trim(),
          password: _pass.text, fullName: _fullName.text.trim(),
          phoneNumber: _phone.text.trim(), country: _county,
        ));
      })),
    ]),
  ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotState();
}
class _ForgotState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin, _AuthScreenMixin {
  final _fk    = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitted = false, _attempted = false;

  @override void dispose() { _email.dispose(); super.dispose(); }

  // Override run — forgot password doesn't navigate to /home
  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (!_fk.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    try {
      await _Api.forgotPassword(_email.text.trim());
      if (mounted) {
        await fadeCtrl.reverse();
        setState(() => _submitted = true);
        fadeCtrl.forward();
      }
    } on DioException catch (e) {
      if (mounted) setState(() => error = _Api.parseDioError(e));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() => fadeCtrl.reverse().then((_) {
    setState(() { _submitted = false; _attempted = false; error = null; _email.clear(); });
    fadeCtrl.forward();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.dark,
    body: Stack(children: [
      _bg(const [Color(0xFF1A0D2B), Color(0xFF0D0614)]),
      const _StarField(),
      SafeArea(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_rounded, color: _C.muted, size: 16),
                  SizedBox(width: 6),
                  Text('Back to Login', style: TextStyle(color: _C.muted, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                ]),
              ),
            ),
            const SizedBox(height: 32),
            anim(Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_C.green.withOpacity(0.20), _C.green.withOpacity(0.06)]),
                  border: Border.all(color: _C.border, width: 1.5),
                ),
                child: Icon(_submitted ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
                    color: _C.green, size: 32),
              ),
              const SizedBox(height: 20),
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Poppins', height: 1.15),
                children: [
                  TextSpan(text: _submitted ? 'Check Your ' : 'Reset ', style: const TextStyle(color: Colors.white)),
                  TextSpan(text: _submitted ? 'Email' : 'Password', style: const TextStyle(color: _C.green)),
                ],
              )),
              const SizedBox(height: 10),
              Text(
                _submitted ? 'Check your email for reset instructions'
                    : 'Enter your email to receive password\nreset instructions',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.muted, fontSize: 14, fontFamily: 'Poppins', height: 1.6),
              ),
            ])),
            const SizedBox(height: 32),
            anim(_submitted ? _success() : _form()),
            const SizedBox(height: 24),
            FadeTransition(opacity: fade, child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.shield_outlined, color: _C.muted, size: 16), SizedBox(width: 10),
                Expanded(child: Text(
                  'For security reasons, we only send reset instructions to registered email addresses.',
                  style: TextStyle(color: _C.muted, fontSize: 11, fontFamily: 'Poppins', height: 1.6),
                )),
              ]),
            )),
            const SizedBox(height: 40),
          ]),
        ),
      )),
    ]),
  );

  Widget _form() => _GlassCard(child: Form(key: _fk, child: Column(children: [
    if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 16)],
    _Field(ctrl: _email, hint: 'you@example.com', icon: Icons.mail_outline_rounded,
        kbType: TextInputType.emailAddress, enabled: !loading,
        validator: (v) {
          if (!_attempted) return null;
          if (v == null || v.isEmpty) return 'Email is required';
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) return 'Invalid email address';
          return null;
        }),
    const SizedBox(height: 20),
    Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => context.push('/help'),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.help_outline_rounded, color: _C.muted, size: 15), SizedBox(width: 5),
          Text('Need help?', style: TextStyle(color: _C.muted, fontSize: 12, fontFamily: 'Poppins')),
        ]),
      ),
    ),
    const SizedBox(height: 20),
    _Btn(label: 'Send Reset Instructions', loading: loading, icon: Icons.send_rounded,
        onTap: loading ? null : _submit),
  ])));

  Widget _success() => _GlassCard(child: Column(children: [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.success.withOpacity(0.10), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.success.withOpacity(0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline_rounded, color: _C.success, size: 20),
        const SizedBox(width: 12),
        Expanded(child: RichText(text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Poppins', height: 1.6),
          children: [
            const TextSpan(text: "We've sent password reset instructions to "),
            TextSpan(text: _email.text.trim(), style: const TextStyle(color: _C.greenLight, fontWeight: FontWeight.w700)),
            const TextSpan(text: '. Please check your email and follow the link.'),
          ],
        ))),
      ]),
    ),
    const SizedBox(height: 20),
    _Btn(label: 'Send Another Reset Link', icon: Icons.refresh_rounded, outlined: true, onTap: _reset),
    const SizedBox(height: 12),
    _Btn(label: 'Back to Sign In', icon: Icons.arrow_forward_rounded,
        onTap: () => context.go('/login')),
  ]));
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: _StepLabel('Account Details', active: current == 1, done: current > 1)),
      Expanded(child: _StepLabel('Personal Info', active: current == 2, done: false, align: TextAlign.right)),
    ]),
    const SizedBox(height: 6),
    ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: current == 1 ? 0.5 : 1.0, minHeight: 4,
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
        )),
  ]);
}
class _StepLabel extends StatelessWidget {
  final String text;
  final bool active, done;
  final TextAlign align;
  const _StepLabel(this.text, {required this.active, required this.done, this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align,
    style: TextStyle(
      color: active ? _C.green : done ? _C.greenLight.withOpacity(0.6) : _C.muted,
      fontSize: 11, fontFamily: 'Poppins', fontWeight: active ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}