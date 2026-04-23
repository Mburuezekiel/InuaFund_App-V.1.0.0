// ═══════════════════════════════════════════════════════════════════════════════
// auth_service.dart
// Flutter equivalent of authService.ts + AuthContext.tsx
// Uses SharedPreferences for token/user persistence (mirrors localStorage)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kApiBase  = 'https://api.inuafund.co.ke/api/users';
const _kFApiBase = 'https://api.inuafund.co.ke/api';

const _kTokenKey = 'token';
const _kUserKey  = 'user';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class LoginCredentials {
  final String email;
  final String password;
  const LoginCredentials({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterData {
  final String username;
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String country;
  const RegisterData({
    required this.username, required this.email,
    required this.password, required this.fullName,
    required this.phoneNumber, required this.country,
  });
  Map<String, dynamic> toJson() => {
    'username': username, 'email': email, 'password': password,
    'fullName': fullName, 'phoneNumber': phoneNumber, 'country': country,
  };
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String token;
  final String role;
  final String? profileImage;
  final String? county;
  final bool emailVerified;
  final bool twoFactorEnabled;
  final String? bio;
  final String? location;
  final String? occupation;

  const UserModel({
    required this.id, required this.username, required this.email,
    required this.fullName, required this.phoneNumber, required this.token,
    required this.role, this.profileImage, this.county,
    this.emailVerified = false, this.twoFactorEnabled = false,
    this.bio, this.location, this.occupation,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:               j['_id']?.toString()          ?? '',
    username:         j['username']?.toString()      ?? '',
    email:            j['email']?.toString()         ?? '',
    fullName:         j['fullName']?.toString()      ?? '',
    phoneNumber:      j['phoneNumber']?.toString()   ?? '',
    token:            j['token']?.toString()         ?? '',
    role:             j['role']?.toString()          ?? 'user',
    profileImage:     j['profileImage']?.toString(),
    county:           j['county']?.toString(),
    emailVerified:    j['emailVerified'] as bool?    ?? false,
    twoFactorEnabled: j['twoFactorEnabled'] as bool? ?? false,
    bio:              j['bio']?.toString(),
    location:         j['location']?.toString(),
    occupation:       j['occupation']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'username': username, 'email': email,
    'fullName': fullName, 'phoneNumber': phoneNumber, 'token': token,
    'role': role, 'profileImage': profileImage, 'county': county,
    'emailVerified': emailVerified, 'twoFactorEnabled': twoFactorEnabled,
    'bio': bio, 'location': location, 'occupation': occupation,
  };

  UserModel copyWith({String? token}) => UserModel(
    id: id, username: username, email: email, fullName: fullName,
    phoneNumber: phoneNumber, token: token ?? this.token, role: role,
    profileImage: profileImage, county: county,
    emailVerified: emailVerified, twoFactorEnabled: twoFactorEnabled,
    bio: bio, location: location, occupation: occupation,
  );
}

class AuthState {
  final String? token;
  final UserModel? user;
  final bool isAuthenticated;
  const AuthState({this.token, this.user, this.isAuthenticated = false});
  static const empty = AuthState(token: null, user: null, isAuthenticated: false);
}

// ─────────────────────────────────────────────────────────────────────────────
// EXCEPTIONS
// ─────────────────────────────────────────────────────────────────────────────

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE  (mirrors authService.ts — stateless, uses SharedPreferences)
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body, {String? token}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 500) throw const AuthException('Server error. Please try again.');
    return decoded;
  }

  Future<Map<String, dynamic>> _get(String url, {String? token}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 500) throw const AuthException('Server error. Please try again.');
    return decoded;
  }

  Future<void> _persist(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, user.token);
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }

  // ── public API ─────────────────────────────────────────────────────────────

  /// Login with email + password
  Future<UserModel> login(LoginCredentials credentials) async {
    final data = await _post('$_kApiBase/login', credentials.toJson());
    if (data['token'] == null) {
      throw AuthException(data['message']?.toString() ?? 'Login failed. Check your credentials.');
    }
    final user = UserModel.fromJson(data);
    await _persist(user);
    return user;
  }

  /// Register with email + password
  Future<UserModel> register(RegisterData reg) async {
    final data = await _post('$_kApiBase/register', reg.toJson());
    if (data['token'] == null) {
      throw AuthException(data['message']?.toString() ?? 'Registration failed. Please try again.');
    }
    final user = UserModel.fromJson(data);
    await _persist(user);
    return user;
  }

  /// Google OAuth login (existing user)
  Future<UserModel> googleLogin(String idToken) async {
    final data = await _post('$_kFApiBase/Gauth/google-login', {'token': idToken});
    if (data['token'] == null) {
      throw AuthException(data['message']?.toString() ?? 'Google login failed.');
    }
    final user = UserModel.fromJson(data);
    await _persist(user);
    return user;
  }

  /// Google OAuth register (new user)
  Future<UserModel> registerWithGoogle(String idToken) async {
    final data = await _post('$_kFApiBase/Gauth/google-register', {'token': idToken});
    if (data['token'] == null) {
      throw AuthException(data['message']?.toString() ?? 'Google registration failed.');
    }
    final user = UserModel.fromJson(data);
    await _persist(user);
    return user;
  }

  /// Fetch full profile from server
  Future<UserModel> getUserProfile({required String token}) async {
    final data = await _get('$_kApiBase/profile', token: token);
    return UserModel.fromJson(data).copyWith(token: token);
  }

  /// Read persisted auth state (mirrors getCurrentUser / refreshAuthState)
  Future<AuthState> getCurrentUser() async {
  try {
    const storage = FlutterSecureStorage();
    
    // Read from secure storage (where login_screen.dart saves)
    final token     = await storage.read(key: 'jwt_token');
    final id        = await storage.read(key: 'user_id')   ?? '';
    final username  = await storage.read(key: 'username')  ?? '';
    final email     = await storage.read(key: 'email')     ?? '';
    final fullName  = await storage.read(key: 'fullName')  ?? '';
    final role      = await storage.read(key: 'role')      ?? 'user';

    if (token == null || token.isEmpty) return AuthState.empty;

    final user = UserModel(
      id: id, username: username, email: email,
      fullName: fullName, phoneNumber: '', token: token, role: role,
    );
    return AuthState(token: token, user: user, isAuthenticated: true);
  } catch (_) {
    return AuthState.empty;
  }
}


  /// Logout — clears storage
  Future<void> logout() async {
  const storage = FlutterSecureStorage();
  await storage.deleteAll();
}

  /// Forgot password
  Future<String> forgotPassword(String email) async {
    final data = await _post('$_kFApiBase/auth/forgot-password', {'email': email});
    return data['message']?.toString() ?? 'Password reset link sent. Check your email.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PROVIDER  (mirrors AuthContext.tsx — ChangeNotifier for Flutter)
// Wrap your MaterialApp with ChangeNotifierProvider<AuthProvider>
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.empty;
  bool _loading = true;

  AuthState get authState    => _state;
  UserModel? get user        => _state.user;
  bool get isAuthenticated   => _state.isAuthenticated;
  bool get loading           => _loading;
  String get token           => _state.token ?? '';

  final AuthService _svc = AuthService.instance;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _state   = await _svc.getCurrentUser();
    _loading = false;
    notifyListeners();
  }

  /// Refreshes auth state from SharedPreferences (mirrors refreshAuthState)
  Future<void> refreshAuthState() async {
    _state = await _svc.getCurrentUser();
    notifyListeners();
  }

  Future<UserModel> login(LoginCredentials credentials) async {
    final user = await _svc.login(credentials);
    _state = AuthState(token: user.token, user: user, isAuthenticated: true);
    notifyListeners();
    return user;
  }

  Future<UserModel> register(RegisterData data) async {
    final user = await _svc.register(data);
    _state = AuthState(token: user.token, user: user, isAuthenticated: true);
    notifyListeners();
    return user;
  }

  Future<UserModel> googleLogin(String idToken) async {
    final user = await _svc.googleLogin(idToken);
    _state = AuthState(token: user.token, user: user, isAuthenticated: true);
    notifyListeners();
    return user;
  }

  Future<UserModel> registerWithGoogle(String idToken) async {
    final user = await _svc.registerWithGoogle(idToken);
    _state = AuthState(token: user.token, user: user, isAuthenticated: true);
    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    await _svc.logout();
    _state = AuthState.empty;
    notifyListeners();
  }
}