class AppConfig {
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api';

  // App-wide settings
  static const int defaultPageSize = 50;
  static const int messageRefreshInterval = 5000; // milliseconds
  static const Duration apiTimeout = Duration(seconds: 30);

  // Feature flags
  static const bool enablePushNotifications = true;
  static const bool enableReadReceipts = true;
  static const bool enableTypingIndicators = true;
}
