class ApiConstants {
  // ── Base URLs ──────────────────────────────────────────────────────────────
  // Production
  static const String baseUrl      = 'https://api.inuafund.co.ke/api';
  static const String usersBaseUrl = 'https://api.inuafund.co.ke/api/users';

  // Local development — uncomment the one that matches your setup:
  // static const String baseUrl = 'http://10.0.2.2:5000/api';   // Android emulator
  // static const String baseUrl = 'http://localhost:5000/api';   // iOS simulator

  // ── User / Auth endpoints  (relative to usersBaseUrl) ─────────────────────
  static const String login    = '/login';     // POST   { email, password }
  static const String register = '/register';  // POST   { username, email, password, fullName, phoneNumber, country }
  static const String profile  = '/profile';   // GET    Bearer token required

  // ── Google OAuth endpoints  (relative to baseUrl) ─────────────────────────
  static const String googleLogin    = '/Gauth/google-login';    // POST  { token: googleIdToken }
  static const String googleRegister = '/Gauth/google-register'; // POST  { token: googleIdToken }

  // ── Password reset  (relative to baseUrl) ─────────────────────────────────
  static const String forgotPassword = '/auth/forgot-password';  // POST  { email }

  // ── OTP  (relative to baseUrl — keep for future use) ──────────────────────
  static const String sendOtp   = '/auth/send-otp';    // POST
  static const String verifyOtp = '/auth/verify-otp';  // POST

  // ── App features  (relative to baseUrl) ───────────────────────────────────
  static const String campaigns = '/campaigns';  // GET / POST
  static const String donate    = '/donations';  // POST
}