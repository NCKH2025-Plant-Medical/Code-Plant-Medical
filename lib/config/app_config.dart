class AppConfig {
  static const detectUrl = String.fromEnvironment(
    'DETECT_URL',
    defaultValue: 'http://222.255.184.116',
  );
  static const historyUrl = String.fromEnvironment(
    'HISTORY_URL',
    defaultValue: 'http://192.168.1.33:8000',
  );
}
