class AppConfig {
  static const detectUrl = String.fromEnvironment(
    'DETECT_URL',
    defaultValue: 'http://222.255.184.116',
  );
  static const detectUrlLocal = String.fromEnvironment(
    'DETECT_URL_LOCAL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const historyUrl = String.fromEnvironment(
    'HISTORY_URL',
    defaultValue: 'http://192.168.1.23:8000',
  );
}
