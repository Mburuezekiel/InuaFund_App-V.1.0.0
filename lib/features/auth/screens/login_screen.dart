import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────────────────────
// API LAYER
// ─────────────────────────────────────────────────────────────────────────────

class _Api {
  static const usersBase = 'https://api.inuafund.co.ke/api/users';
  static const base      = 'https://api.inuafund.co.ke/api';
}

class _AuthApi {
  static const _storage = FlutterSecureStorage();

  // Dio for /api/users/* (login, register, profile)
  static final _userDio = Dio(BaseOptions(
    baseUrl: _Api.usersBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));

  // Dio for /api/* (Google OAuth, forgot-password)
  static final _baseDio = Dio(BaseOptions(
    baseUrl: _Api.base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '834391125130-bsmhrlr77l261543fek7a6er66pa6hs4.apps.googleusercontent.com',
  );

  // ── helpers ──────────────────────────────────────────────────────────────
  static Future<void> _persist(Map<String, dynamic> data) async {
    await _storage.write(key: 'jwt_token', value: data['token'] as String);
    await _storage.write(key: 'user_id',   value: data['_id']?.toString() ?? '');
    await _storage.write(key: 'username',  value: data['username']?.toString() ?? '');
    await _storage.write(key: 'email',     value: data['email']?.toString() ?? '');
    await _storage.write(key: 'fullName',  value: data['fullName']?.toString() ?? '');
    await _storage.write(key: 'role',      value: data['role']?.toString() ?? '');
  }

  static String _msg(Map<String, dynamic> data, String fallback) =>
      (data['message'] as String?) ?? fallback;

  static String parseDioError(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) return (d['message'] ?? e.message ?? 'Network error').toString();
      return e.message ?? 'Network error. Please try again.';
    }
    return e.toString();
  }

  // ── login ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _userDio.post('/login', data: {
      'email': email, 'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    if (res.statusCode == 200 && data['token'] != null) {
      await _persist(data);
      return data;
    }
    throw _msg(data, 'Login failed. Please check your credentials.');
  }

  // ── register ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String country,
  }) async {
    final res = await _userDio.post('/register', data: {
      'username': username, 'email': email,
      'password': password, 'fullName': fullName,
      'phoneNumber': phoneNumber, 'country': country,
    });
    final data = res.data as Map<String, dynamic>;
    if ((res.statusCode == 200 || res.statusCode == 201) && data['token'] != null) {
      await _persist(data);
      return data;
    }
    throw _msg(data, 'Registration failed. Please try again.');
  }

  // ── Google Sign-In → login ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> googleLogin() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw 'Google sign-in was cancelled.';
    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw 'Could not retrieve Google ID token.';

    final res = await _baseDio.post('/Gauth/google-login', data: {'token': idToken});
    final data = res.data as Map<String, dynamic>;
    if (res.statusCode == 200 && data['token'] != null) {
      await _persist(data);
      return data;
    }
    throw _msg(data, 'Google login failed.');
  }

  // ── Google Sign-In → register ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> googleRegister() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw 'Google sign-in was cancelled.';
    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw 'Could not retrieve Google ID token.';

    final res = await _baseDio.post('/Gauth/google-register', data: {'token': idToken});
    final data = res.data as Map<String, dynamic>;
    if ((res.statusCode == 200 || res.statusCode == 201) && data['token'] != null) {
      await _persist(data);
      return data;
    }
    throw _msg(data, 'Google registration failed.');
  }

  // ── forgot password ───────────────────────────────────────────────────────
  static Future<void> forgotPassword(String email) async {
    final res = await _baseDio.post('/auth/forgot-password', data: {'email': email});
    final data = res.data as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw _msg(data, 'Failed to process request. Please try again.');
    }
  }

  // ── logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _storage.deleteAll();
    await _googleSignIn.signOut();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COLOURS & HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const green       = Color(0xFF1DB954);
  static const greenDark   = Color(0xFF158A3E);
  static const greenLight  = Color(0xFF4ADE80);
  static const gold        = Color(0xFFF5A623);
  static const dark        = Color(0xFF0A0F0D);
  static const card        = Color(0xEA061409);
  static const muted       = Color(0x88FFFFFF);
  static const border      = Color(0x401DB954);
  static const error       = Color(0xFFEF4444);
  static const inputBg     = Color(0x14FFFFFF);
  static const inputBorder = Color(0x26FFFFFF);
  static const success     = Color(0xFF22C55E);
}

extension _Dur on int {
  Duration get ms => Duration(milliseconds: this);
  Duration get s  => Duration(seconds: this);
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool    _obscure       = true;
  bool    _loading       = false;
  bool    _googleLoading = false;
  bool    _remember      = false;
  String? _error;

  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: 600.ms)..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06), end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _fadeCtrl.dispose();
    super.dispose();
  }

  // ── email/password submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _AuthApi.login(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _error = _AuthApi.parseDioError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google sign-in ────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await _AuthApi.googleLogin();
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _error = _AuthApi.parseDioError(e));
    } catch (e) {
      final msg = e.toString();
      // User cancelled — don't show an error banner
      if (!msg.contains('cancelled')) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        // background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D2B1A), Color(0xFF061409)],
            ),
          ),
        ),
        const _StarField(),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: CustomPaint(size: Size(w, h * 0.30)),
        ),
        Positioned(
          bottom: h * 0.12, left: 40, right: 40,
          child: Container(height: 60, decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [_C.green.withOpacity(0.12), Colors.transparent]))),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 28),
                _Logo(),
                const SizedBox(height: 36),

                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide,
                    child: Column(children: [
                      RichText(text: const TextSpan(
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins', height: 1.15),
                        children: [
                          TextSpan(text: 'Welcome ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Back',      style: TextStyle(color: _C.green)),
                        ],
                      )),
                      const SizedBox(height: 8),
                      const Text('Sign in to continue making a difference',
                          style: TextStyle(color: _C.muted, fontSize: 14, fontFamily: 'Poppins')),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),

                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide,
                    child: _GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(children: [
                          if (_error != null) ...[_ErrorBanner(_error!), const SizedBox(height: 16)],

                          _InputField(
                            controller: _emailCtrl,
                            hint: 'Email address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_loading && !_googleLoading,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Email is required';
                              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email format';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _InputField(
                            controller: _passCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            enabled: !_loading && !_googleLoading,
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                                  color: _C.muted, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                _GreenCheckbox(
                                  value: _remember,
                                  onChanged: (v) => setState(() => _remember = v ?? false),
                                ),
                                const SizedBox(width: 8),
                                const Text('Remember me',
                                    style: TextStyle(color: _C.muted, fontSize: 12,
                                        fontFamily: 'Poppins')),
                              ]),
                              GestureDetector(
                                onTap: () => context.push('/forgot-password'),
                                child: const Text('Forgot password?',
                                    style: TextStyle(color: _C.green, fontSize: 12,
                                        fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _PrimaryBtn(
                            label: 'Sign In',
                            loading: _loading,
                            onTap: _loading || _googleLoading ? null : _submit,
                          ),
                          const SizedBox(height: 16),

                          _OrDivider(),
                          const SizedBox(height: 16),

                          _GoogleBtn(
                            label: 'Continue with Google',
                            loading: _googleLoading,
                            onTap: _loading || _googleLoading ? null : _googleSignIn,
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeTransition(
                  opacity: _fade,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: _C.muted, fontSize: 13, fontFamily: 'Poppins')),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text('Sign up',
                          style: TextStyle(color: _C.green, fontSize: 13,
                              fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ]),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _step1Key     = GlobalKey<FormState>();
  final _step2Key     = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  int     _step           = 1;
  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _loading        = false;
  bool    _googleLoading  = false;
  bool    _agreeToTerms   = false;
  bool    _newsletter     = false;
  double  _passStrength   = 0;
  String? _error;
  String  _selectedCounty = '';

  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: 500.ms)..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05), end: Offset.zero,
  ).animate(_fade);

  static const _counties = [
    'Baringo','Bomet','Bungoma','Busia','Elgeyo/Marakwet','Embu','Garissa',
    'Homa Bay','Isiolo','Kajiado','Kakamega','Kericho','Kiambu','Kilifi',
    'Kirinyaga','Kisii','Kisumu','Kitui','Kwale','Laikipia','Lamu',
    'Machakos','Makueni','Mandera','Marsabit','Meru','Migori','Mombasa',
    "Murang'a",'Nairobi','Nakuru','Nandi','Narok','Nyamira','Nyandarua',
    'Nyeri','Samburu','Siaya','Taita/Taveta','Tana River','Tharaka Nithi',
    'Trans Nzoia','Turkana','Uasin Gishu','Vihiga','Wajir','West Pokot',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _confirmCtrl.dispose(); _fullNameCtrl.dispose(); _phoneCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _loading || _googleLoading;

  void _calcStrength(String p) {
    double s = 0;
    if (p.length >= 8)                                              s += 20;
    if (RegExp(r'[a-z]').hasMatch(p))                              s += 20;
    if (RegExp(r'[A-Z]').hasMatch(p))                              s += 20;
    if (RegExp(r'\d').hasMatch(p))                                 s += 20;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p))           s += 20;
    setState(() => _passStrength = s);
  }

  String get _strengthLabel {
    if (_passCtrl.text.isEmpty) return 'Not set';
    if (_passStrength < 40) return 'Weak';
    if (_passStrength < 60) return 'Fair';
    if (_passStrength < 80) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    if (_passStrength < 40) return _C.error;
    if (_passStrength < 60) return _C.gold;
    if (_passStrength < 80) return _C.greenLight;
    return _C.green;
  }

  void _toStep2() {
    setState(() => _error = null);
    if (_step1Key.currentState!.validate()) {
      _fadeCtrl.reverse().then((_) {
        setState(() => _step = 2);
        _fadeCtrl.forward();
      });
    }
  }

  void _toStep1() {
    _fadeCtrl.reverse().then((_) {
      setState(() { _step = 1; _error = null; });
      _fadeCtrl.forward();
    });
  }

  // ── email/password register ───────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_step2Key.currentState!.validate()) return;
    if (!_agreeToTerms) {
      setState(() => _error = 'Please agree to the Terms and Conditions to proceed.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _AuthApi.register(
        username:    _usernameCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        password:    _passCtrl.text,
        fullName:    _fullNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        country:     _selectedCounty,
      );
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      _handleRegisterError(_AuthApi.parseDioError(e));
    } catch (e) {
      _handleRegisterError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // ── Google register ───────────────────────────────────────────────────────
  Future<void> _googleRegister() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await _AuthApi.googleRegister();
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _error = _AuthApi.parseDioError(e));
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('cancelled')) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _handleRegisterError(String msg) {
    final lower = msg.toLowerCase();
    final goToStep1 = lower.contains('username') || lower.contains('email');
    if (goToStep1) {
      _fadeCtrl.reverse().then((_) {
        setState(() { _step = 1; _error = msg; });
        _fadeCtrl.forward();
      });
    } else {
      setState(() => _error = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0A1A2E), Color(0xFF061020)],
            ),
          ),
        ),
        const _StarField(),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: CustomPaint(size: Size(w, h * 0.28),),
        ),
        Positioned(
          bottom: h * 0.10, left: 40, right: 40,
          child: Container(height: 60, decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [_C.green.withOpacity(0.10), Colors.transparent]))),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 20),

                // top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Logo(),
                    GestureDetector(
                      onTap: () => context.push('/login'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Text('Sign In',
                            style: TextStyle(color: _C.muted, fontSize: 13,
                                fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                FadeTransition(
                  opacity: _fade,
                  child: Column(children: [
                    RichText(text: TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins', height: 1.15),
                      children: [
                        TextSpan(text: _step == 1 ? 'Create ' : 'Almost ',
                            style: const TextStyle(color: Colors.white)),
                        TextSpan(text: _step == 1 ? 'Account' : 'There!',
                            style: const TextStyle(color: _C.green)),
                      ],
                    )),
                    const SizedBox(height: 14),
                    _StepIndicator(current: _step),
                  ]),
                ),
                const SizedBox(height: 24),

                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide,
                    child: _GlassCard(
                      child: _step == 1 ? _buildStep1() : _buildStep2(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeTransition(
                  opacity: _fade,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: _C.muted, fontSize: 13, fontFamily: 'Poppins')),
                    GestureDetector(
                      onTap: () => context.push('/login'),
                      child: const Text('Sign in',
                          style: TextStyle(color: _C.green, fontSize: 13,
                              fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ]),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── STEP 1 ────────────────────────────────────────────────────────────────
  Widget _buildStep1() => Form(
    key: _step1Key,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) ...[_ErrorBanner(_error!), const SizedBox(height: 16)],

      _InputField(
        controller: _usernameCtrl, hint: 'Username',
        icon: Icons.person_outline_rounded, enabled: !_busy,
        validator: (v) => (v == null || v.isEmpty) ? 'Username is required' : null,
      ),
      const SizedBox(height: 14),

      _InputField(
        controller: _emailCtrl, hint: 'Email address',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress, enabled: !_busy,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Email is required';
          if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email format';
          return null;
        },
      ),
      const SizedBox(height: 14),

      _InputField(
        controller: _passCtrl, hint: 'Password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscurePass, enabled: !_busy, onChanged: _calcStrength,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _C.muted, size: 20),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Password is required';
          if (_passStrength < 60) return 'Password is too weak';
          return null;
        },
      ),

      if (_passCtrl.text.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Strength: $_strengthLabel',
              style: TextStyle(color: _strengthColor, fontSize: 11,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          Text('${_passStrength.toInt()}%',
              style: TextStyle(color: _strengthColor, fontSize: 11, fontFamily: 'Poppins')),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passStrength / 100,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
            minHeight: 5,
          ),
        ),
      ],
      const SizedBox(height: 14),

      _InputField(
        controller: _confirmCtrl, hint: 'Confirm Password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscureConfirm, enabled: !_busy,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _C.muted, size: 20),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please confirm your password';
          if (v != _passCtrl.text) return 'Passwords do not match';
          return null;
        },
      ),
      const SizedBox(height: 24),

      _PrimaryBtn(
          label: 'Continue', loading: false,
          icon: Icons.arrow_forward_rounded,
          onTap: _busy ? null : _toStep2),
      const SizedBox(height: 16),
      _OrDivider(),
      const SizedBox(height: 16),

      _GoogleBtn(
          label: 'Sign up with Google',
          loading: _googleLoading,
          onTap: _busy ? null : _googleRegister),
    ]),
  );

  // ── STEP 2 ────────────────────────────────────────────────────────────────
  Widget _buildStep2() => Form(
    key: _step2Key,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) ...[_ErrorBanner(_error!), const SizedBox(height: 16)],

      _InputField(
        controller: _fullNameCtrl, hint: 'Full Name',
        icon: Icons.badge_outlined, enabled: !_busy,
        validator: (v) => (v == null || v.isEmpty) ? 'Full name is required' : null,
      ),
      const SizedBox(height: 14),

      _InputField(
        controller: _phoneCtrl, hint: 'Phone Number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone, enabled: !_busy,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Phone number is required';
          if (!RegExp(r'^\+?[0-9\s\-()]{7,20}$').hasMatch(v)) {
            return 'Invalid phone number format';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),

      _CountyDropdown(
        selected: _selectedCounty, counties: _counties,
        enabled: !_busy,
        onChanged: (v) => setState(() => _selectedCounty = v ?? ''),
        validator: (v) => (v == null || v.isEmpty) ? 'County is required' : null,
      ),
      const SizedBox(height: 20),

      _CheckRow(
        value: _agreeToTerms,
        onChanged: (v) => setState(() { _agreeToTerms = v ?? false; _error = null; }),
        label: 'I agree to the ',
        link: 'Terms & Conditions',
        onLinkTap: () => context.push('/terms'),
      ),
      const SizedBox(height: 10),
      _CheckRow(
        value: _newsletter,
        onChanged: (v) => setState(() => _newsletter = v ?? false),
        label: 'Subscribe to newsletter for updates',
      ),
      const SizedBox(height: 24),

      Row(children: [
        Expanded(child: _SecondaryBtn(
            label: 'Back', icon: Icons.arrow_back_rounded,
            onTap: _busy ? null : _toStep1)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _PrimaryBtn(
            label: 'Create Account', loading: _loading,
            onTap: _busy ? null : _submit)),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotState();
}

class _ForgotState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool    _loading     = false;
  bool    _submitted   = false;   // true after successful send
  bool    _attempted   = false;
  String? _error;

  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: 600.ms)..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06), end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _emailCtrl.dispose(); _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _AuthApi.forgotPassword(_emailCtrl.text.trim());
      if (mounted) {
        // cross-fade to success view
        await _fadeCtrl.reverse();
        setState(() => _submitted = true);
        _fadeCtrl.forward();
      }
    } on DioException catch (e) {
      setState(() => _error = _AuthApi.parseDioError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() async {
    await _fadeCtrl.reverse();
    setState(() {
      _submitted = false;
      _attempted = false;
      _error     = null;
      _emailCtrl.clear();
    });
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A0D2B), Color(0xFF0D0614)],
            ),
          ),
        ),
        const _StarField(),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: CustomPaint(size: Size(w, h * 0.28)),
        ),
        Positioned(
          bottom: h * 0.12, left: 40, right: 40,
          child: Container(height: 60, decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [_C.green.withOpacity(0.10), Colors.transparent]))),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 20),

                // back button row
                Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.arrow_back_rounded, color: _C.muted, size: 16),
                        SizedBox(width: 6),
                        Text('Back to Login',
                            style: TextStyle(color: _C.muted, fontSize: 13,
                                fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),

                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide,
                    child: Column(children: [
                      // icon
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_C.green.withOpacity(0.20), _C.green.withOpacity(0.06)]),
                          border: Border.all(color: _C.border, width: 1.5),
                        ),
                        child: Icon(
                          _submitted ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
                          color: _C.green, size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),

                      RichText(text: TextSpan(
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins', height: 1.15),
                        children: [
                          TextSpan(
                            text: _submitted ? 'Check Your ' : 'Reset ',
                            style: const TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: _submitted ? 'Email' : 'Password',
                            style: const TextStyle(color: _C.green),
                          ),
                        ],
                      )),
                      const SizedBox(height: 10),

                      Text(
                        _submitted
                            ? 'Check your email for reset instructions'
                            : 'Enter your email to receive password\nreset instructions',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _C.muted, fontSize: 14,
                            fontFamily: 'Poppins', height: 1.6),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),

                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide,
                    child: _submitted ? _buildSuccess() : _buildForm(),
                  ),
                ),

                const SizedBox(height: 24),

                // security notice
                FadeTransition(
                  opacity: _fade,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.shield_outlined, color: _C.muted, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'For security reasons, we only send reset instructions to registered email addresses.',
                          style: TextStyle(color: _C.muted, fontSize: 11,
                              fontFamily: 'Poppins', height: 1.6),
                        ),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── form view ─────────────────────────────────────────────────────────────
  Widget _buildForm() => _GlassCard(
    child: Form(
      key: _formKey,
      child: Column(children: [
        if (_error != null) ...[_ErrorBanner(_error!), const SizedBox(height: 16)],

        _InputField(
          controller: _emailCtrl,
          hint: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          enabled: !_loading,
          validator: (v) {
            if (!_attempted) return null;
            if (v == null || v.isEmpty) return 'Email is required';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // help link
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/help'),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.help_outline_rounded, color: _C.muted, size: 15),
              SizedBox(width: 5),
              Text('Need help?', style: TextStyle(
                  color: _C.muted, fontSize: 12, fontFamily: 'Poppins')),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        _PrimaryBtn(
          label: 'Send Reset Instructions',
          loading: _loading,
          icon: Icons.send_rounded,
          onTap: _loading ? null : _submit,
        ),
      ]),
    ),
  );

  // ── success view ──────────────────────────────────────────────────────────
  Widget _buildSuccess() => _GlassCard(
    child: Column(children: [
      // green success banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.success.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.success.withOpacity(0.30)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_outline_rounded, color: _C.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(text: TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 13,
                  fontFamily: 'Poppins', height: 1.6),
              children: [
                const TextSpan(text: "We've sent password reset instructions to "),
                TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: const TextStyle(
                      color: _C.greenLight, fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                    text: '. Please check your email and follow the link to reset your password.'),
              ],
            )),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      _SecondaryBtn(
        label: 'Send Another Reset Link',
        icon: Icons.refresh_rounded,
        onTap: _reset,
      ),
      const SizedBox(height: 12),

      _PrimaryBtn(
        label: 'Back to Sign In',
        loading: false,
        icon: Icons.arrow_forward_rounded,
        onTap: () => context.go('/login'),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
        child: Image.asset(
          'assets/icon.png',
          width: 33,
          height: 33,
          fit: BoxFit.cover,
        ),
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
// Glass container reused on all three screens
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.card,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _C.border),
      boxShadow: [
        BoxShadow(color: _C.green.withOpacity(0.08), blurRadius: 32, spreadRadius: 0),
      ],
    ),
    padding: const EdgeInsets.all(28),
    child: child,
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool enabled;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure    = false,
    this.enabled    = true,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    obscureText:  obscure,
    keyboardType: keyboardType,
    onChanged:    onChanged,
    enabled:      enabled,
    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
    validator: validator,
    decoration: InputDecoration(
      hintText:  hint,
      hintStyle: const TextStyle(color: _C.muted, fontFamily: 'Poppins', fontSize: 14),
      prefixIcon: Icon(icon, color: _C.muted, size: 20),
      suffixIcon: suffixIcon,
      filled:    true,
      fillColor: enabled ? _C.inputBg : _C.inputBg.withOpacity(0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.inputBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.inputBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.green, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.error, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.error, width: 1.5)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.inputBorder.withOpacity(0.4))),
      errorStyle: const TextStyle(color: _C.error, fontSize: 11, fontFamily: 'Poppins'),
    ),
  );
}

class _CountyDropdown extends StatelessWidget {
  final String selected;
  final List<String> counties;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const _CountyDropdown({
    required this.selected, required this.counties,
    required this.onChanged, this.validator, this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: selected.isEmpty ? null : selected,
    onChanged: enabled ? onChanged : null,
    validator: validator,
    dropdownColor: const Color(0xFF0E1F14),
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted),
    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
    hint: const Row(children: [
      Icon(Icons.location_on_outlined, color: _C.muted, size: 20),
      SizedBox(width: 12),
      Text('Select County',
          style: TextStyle(color: _C.muted, fontFamily: 'Poppins', fontSize: 14)),
    ]),
    decoration: InputDecoration(
      filled: true,
      fillColor: _C.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.green, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.error)),
      errorStyle: const TextStyle(color: _C.error, fontSize: 11, fontFamily: 'Poppins'),
    ),
    items: counties.map((c) => DropdownMenuItem(
      value: c,
      child: Text(c, style: const TextStyle(
          color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
    )).toList(),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String   label;
  final bool     loading;
  final VoidCallback? onTap;
  final IconData? icon;

  const _PrimaryBtn({
    required this.label, required this.loading,
    required this.onTap, this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
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
              Text(label, style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
            ]),
    ),
  );
}

class _SecondaryBtn extends StatelessWidget {
  final String   label;
  final VoidCallback? onTap;
  final IconData? icon;
  const _SecondaryBtn({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.muted,
        side: BorderSide(color: Colors.white.withOpacity(0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        Text(label, style: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    ),
  );
}

class _GoogleBtn extends StatelessWidget {
  final String    label;
  final bool      loading;
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
              child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2.2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: const Size(20, 20), painter: _GoogleIcon()),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                  fontSize: 14, color: Colors.white)),
            ]),
    ),
  );
}

class _GoogleIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2; final r = size.width / 2;
    const segs = [
      (0.0,   90.0,  Color(0xFF4285F4)),
      (90.0,  90.0,  Color(0xFF34A853)),
      (180.0, 90.0,  Color(0xFFFBBC05)),
      (270.0, 90.0,  Color(0xFFEA4335)),
    ];
    for (final s in segs) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - 1.5),
        s.$1 * pi / 180, s.$2 * pi / 180, false,
        Paint()..color = s.$3..style = PaintingStyle.stroke..strokeWidth = 3,
      );
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text('OR', style: TextStyle(
          color: _C.muted, fontSize: 12, fontFamily: 'Poppins',
          fontWeight: FontWeight.w600)),
    ),
    Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
  ]);
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.error.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.error.withOpacity(0.35)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: _C.error, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(
          color: _C.error, fontSize: 12, fontFamily: 'Poppins'))),
    ]),
  );
}

class _GreenCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _GreenCheckbox({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22, height: 22,
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
  const _CheckRow({required this.value, required this.onChanged,
      required this.label, this.link, this.onLinkTap});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _GreenCheckbox(value: value, onChanged: onChanged),
      const SizedBox(width: 10),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(text: TextSpan(
          style: const TextStyle(color: _C.muted, fontSize: 12, fontFamily: 'Poppins'),
          children: [
            TextSpan(text: label),
            if (link != null)
              WidgetSpan(child: GestureDetector(
                onTap: onLinkTap,
                child: Text(link!, style: const TextStyle(
                    color: _C.green, fontSize: 12,
                    fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              )),
          ],
        )),
      )),
    ],
  );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: _StepLabel('Account Details',
          active: current == 1, done: current > 1)),
      Expanded(child: _StepLabel('Personal Info',
          active: current == 2, done: false, align: TextAlign.right)),
    ]),
    const SizedBox(height: 6),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: current == 1 ? 0.5 : 1.0,
        backgroundColor: Colors.white.withOpacity(0.08),
        valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
        minHeight: 4,
      ),
    ),
  ]);
}

class _StepLabel extends StatelessWidget {
  final String text;
  final bool active, done;
  final TextAlign align;
  const _StepLabel(this.text, {required this.active, required this.done,
      this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) => Text(text,
    textAlign: align,
    style: TextStyle(
      color: active ? _C.green : done ? _C.greenLight.withOpacity(0.6) : _C.muted,
      fontSize: 11, fontFamily: 'Poppins',
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAR FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _StarField extends StatefulWidget {
  const _StarField();
  @override State<_StarField> createState() => _StarFieldState();
}
class _StarFieldState extends State<_StarField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);
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
    final rng = Random(42);
    final p = Paint();
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.55;
      final op = (0.2 + rng.nextDouble() * 0.45 + (i % 3 == 0 ? t * 0.3 : 0)).clamp(0.0, 1.0);
      p.color = Colors.white.withOpacity(op);
      canvas.drawCircle(Offset(x, y), 0.7 + rng.nextDouble() * 1.2, p);
    }
  }
  @override bool shouldRepaint(_StarPainter o) => o.t != t;
}

// // ─────────────────────────────────────────────────────────────────────────────
// // CITY PAINTER
// // ─────────────────────────────────────────────────────────────────────────────
// class _CityPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final w = size.width; final h = size.height;
//     final rng = Random(99);
//     const bldgs = [
//       [0.00,0.07,0.55],[0.06,0.06,0.65],[0.11,0.05,0.58],[0.15,0.08,0.72],
//       [0.22,0.04,0.60],[0.26,0.09,0.82],[0.34,0.05,0.68],[0.38,0.10,0.88],
//       [0.48,0.06,0.75],[0.53,0.13,0.92],[0.65,0.06,0.70],[0.70,0.10,0.85],
//       [0.79,0.05,0.68],[0.83,0.08,0.60],[0.90,0.10,0.72],
//     ];
//     const cols = [0xFF0E1F14, 0xFF112318, 0xFF133020, 0xFF0D2B1A];
//     for (int i = 0; i < bldgs.length; i++) {
//       final bx = bldgs[i][0]*w; final bw = bldgs[i][1]*w; final bh = bldgs[i][2]*h;
//       canvas.drawRRect(
//         RRect.fromRectAndCorners(Rect.fromLTWH(bx, h-bh, bw, bh),
//             topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
//         Paint()..color = Color(cols[i % cols.length]),
//       );
//       for (int j = 0; j < 5; j++) {
//         final wx = bx + 3 + rng.nextDouble() * (bw - 8).clamp(0, bw);
//         final wy = (h - bh) + 6 + rng.nextDouble() * bh * 0.7;
//         final wc = j % 3 == 0 ? _C.gold : j % 4 == 0 ? _C.green : Colors.white;
//         canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 6),
//             Paint()..color = wc.withOpacity(0.35 + rng.nextDouble() * 0.3));
//       }
//     }
//     canvas.drawRect(
//         Rect.fromLTWH(0, h-3, w, 3), Paint()..color = const Color(0xFF061409));
//   }
//   @override bool shouldRepaint(_) => false;
// }