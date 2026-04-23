import 'dart:async';

class NotificationPreferences {
  final bool email;
  final bool push;
  final bool inApp;

  NotificationPreferences({
    required this.email,
    required this.push,
    required this.inApp,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'push': push,
        'inApp': inApp,
      };
}

class NotificationStatus {
  final bool isSupported;
  final bool isSubscribed;
  final Object? subscription;
  final String? error;

  NotificationStatus({
    required this.isSupported,
    required this.isSubscribed,
    this.subscription,
    this.error,
  });
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  Future<NotificationStatus> getNotificationStatus() async =>
      NotificationStatus(isSupported: false, isSubscribed: false);

  Future<bool> requestPermission() async => false;

  Future<bool> unsubscribe() async => false;

  Future<void> updatePreferences(NotificationPreferences preferences) async =>
      throw UnsupportedError('Notifications not supported on this platform.');
}