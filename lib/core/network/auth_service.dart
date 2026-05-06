import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _kUsersBase = 'https://api.inuafund.co.ke/api/users';
const _kBase      = 'https://api.inuafund.co.ke/api';
const _storage    = FlutterSecureStorage();

// ─── Models ──────────────────────────────────────────────────────────────────
class UserModel {
  final String id, username, email, fullName, phoneNumber, token, role;
  final String? profileImage, county, bio, location, occupation;
  final bool emailVerified, twoFactorEnabled;

  const UserModel({
    required this.id, required this.username, required this.email,
    required this.fullName, required this.phoneNumber,
    required this.token, required this.role,
    this.profileImage, this.county, this.bio, this.location, this.occupation,
    this.emailVerified = false, this.twoFactorEnabled = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['_id']?.toString() ?? '', username: j['username']?.toString() ?? '',
    email: j['email']?.toString() ?? '', fullName: j['fullName']?.toString() ?? '',
    phoneNumber: j['phoneNumber']?.toString() ?? '', token: j['token']?.toString() ?? '',
    role: j['role']?.toString() ?? 'user', profileImage: j['profileImage']?.toString(),
    county: j['county']?.toString(), bio: j['bio']?.toString(),
    location: j['location']?.toString(), occupation: j['occupation']?.toString(),
    emailVerified: j['emailVerified'] as bool? ?? false,
    twoFactorEnabled: j['twoFactorEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'username': username, 'email': email, 'fullName': fullName,
    'phoneNumber': phoneNumber, 'token': token, 'role': role,
    'profileImage': profileImage, 'county': county, 'emailVerified': emailVerified,
    'twoFactorEnabled': twoFactorEnabled, 'bio': bio,
    'location': location, 'occupation': occupation,
  };

  UserModel copyWith({String? token}) => UserModel(
    id: id, username: username, email: email, fullName: fullName,
    phoneNumber: phoneNumber, token: token ?? this.token, role: role,
    profileImage: profileImage, county: county, emailVerified: emailVerified,
    twoFactorEnabled: twoFactorEnabled, bio: bio, location: location, occupation: occupation,
  );
}

class AuthState {
  final String? token;
  final UserModel? user;
  final bool isAuthenticated;
  const AuthState({this.token, this.user, this.isAuthenticated = false});
  static const empty = AuthState();
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override String toString() => message;
}

// ─── Auth Service ─────────────────────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body, {String? token}) async {
    final res = await http.post(Uri.parse(url),
      headers: {
        'Content-Type': 'application/json', 'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 500) throw const AuthException('Server error. Please try again.');
    return data;
  }

  Future<UserModel> _handleResponse(Map<String, dynamic> data, String fallback) async {
    if (data['token'] == null) throw AuthException(data['message']?.toString() ?? fallback);
    final user = UserModel.fromJson(data);
    await _persist(user);
    return user;
  }

  Future<void> _persist(UserModel u) async {
    await _storage.write(key: 'jwt_token',    value: u.token);
    await _storage.write(key: 'user_id',      value: u.id);
    await _storage.write(key: 'username',     value: u.username);
    await _storage.write(key: 'email',        value: u.email);
    await _storage.write(key: 'fullName',     value: u.fullName);
    await _storage.write(key: 'role',         value: u.role);
    await _storage.write(key: 'phoneNumber',  value: u.phoneNumber);
  }

  Future<UserModel> login(String email, String password) async =>
      _handleResponse(await _post('$_kUsersBase/login', {'email': email, 'password': password}),
          'Login failed. Check your credentials.');

  Future<UserModel> register({
    required String username, required String email, required String password,
    required String fullName, required String phoneNumber, required String country,
  }) async => _handleResponse(
      await _post('$_kUsersBase/register', {
        'username': username, 'email': email, 'password': password,
        'fullName': fullName, 'phoneNumber': phoneNumber, 'country': country,
      }), 'Registration failed. Please try again.');

  Future<UserModel> googleLogin(String idToken) async =>
      _handleResponse(await _post('$_kBase/Gauth/google-login', {'token': idToken}),
          'Google login failed.');

  Future<UserModel> googleRegister(String idToken) async =>
      _handleResponse(await _post('$_kBase/Gauth/google-register', {'token': idToken}),
          'Google registration failed.');

  Future<void> forgotPassword(String email) async {
    final data = await _post('$_kBase/auth/forgot-password', {'email': email});
    if (data['token'] == null && data['message'] == null) {
      throw const AuthException('Failed to process request.');
    }
  }

  Future<AuthState> getCurrentUser() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) return AuthState.empty;
      final user = UserModel(
        id:          await _storage.read(key: 'user_id')     ?? '',
        username:    await _storage.read(key: 'username')    ?? '',
        email:       await _storage.read(key: 'email')       ?? '',
        fullName:    await _storage.read(key: 'fullName')    ?? '',
        phoneNumber: await _storage.read(key: 'phoneNumber') ?? '',
        role:        await _storage.read(key: 'role')        ?? 'user',
        token:       token,
      );
      return AuthState(token: token, user: user, isAuthenticated: true);
    } catch (_) { return AuthState.empty; }
  }

  Future<void> logout() => _storage.deleteAll();
}

// ─── Auth Provider ────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.empty;
  bool _loading = true;

  AuthState get authState  => _state;
  UserModel? get user      => _state.user;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get loading         => _loading;
  String get token         => _state.token ?? '';

  final _svc = AuthService.instance;

  AuthProvider() { _init(); }

  Future<void> _init() async {
    _state   = await _svc.getCurrentUser();
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshAuthState() async {
    _state = await _svc.getCurrentUser();
    notifyListeners();
  }

  void _set(UserModel u) {
    _state = AuthState(token: u.token, user: u, isAuthenticated: true);
    notifyListeners();
  }

  Future<UserModel> login(String email, String password) async {
    final u = await _svc.login(email, password); _set(u); return u;
  }

  Future<UserModel> register({
    required String username, required String email, required String password,
    required String fullName, required String phoneNumber, required String country,
  }) async {
    final u = await _svc.register(
      username: username, email: email, password: password,
      fullName: fullName, phoneNumber: phoneNumber, country: country,
    ); _set(u); return u;
  }

  Future<UserModel> googleLogin(String idToken) async {
    final u = await _svc.googleLogin(idToken); _set(u); return u;
  }

  Future<UserModel> googleRegister(String idToken) async {
    final u = await _svc.googleRegister(idToken); _set(u); return u;
  }

  Future<void> logout() async {
    await _svc.logout();
    _state = AuthState.empty;
    notifyListeners();
  }
}