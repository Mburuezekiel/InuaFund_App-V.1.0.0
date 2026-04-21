class ApiConstants {
  static const String baseUrl = 'https://your-node-backend.com/api';
  // Change to http://10.0.2.2:5000/api when testing on Android emulator
  // Change to http://localhost:5000/api when testing on iOS simulator

  static const String login       = '/auth/login';
  static const String sendOtp     = '/auth/send-otp';
  static const String verifyOtp   = '/auth/verify-otp';
  static const String campaigns   = '/campaigns';
  static const String donate      = '/donations';
  static const String profile     = '/users/me';
}