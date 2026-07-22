/// Build-time app configuration, set via `--dart-define`.
///
///   flutter build apk --release --dart-define=DEBUG_MODE=true
///
/// Debug mode surfaces raw technical error detail (exception types,
/// underlying platform messages, HTTP bodies) in the UI — useful while
/// diagnosing connectivity issues, not something end users should see.
/// Defaults to false (friendly messages only), so a normal deployed build
/// never leaks this by accident.
class AppConfig {
  AppConfig._();

  static const bool debugMode = bool.fromEnvironment('DEBUG_MODE');
}
