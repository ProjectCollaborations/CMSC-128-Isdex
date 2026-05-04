/// Central place for build-time configuration values injected via --dart-define.
///
/// To inject at runtime:
///   flutter run --dart-define=IUCN_API_TOKEN=your_token_here
/// The defaultValue is intentionally empty
/// so the app degrades gracefully (shows RTDB fallback) instead of crashing.
class AppConfig {
  AppConfig._(); // Static-only — not instantiable

  /// IUCN Red List API token.
  /// Injected at build time via: --dart-define=IUCN_API_TOKEN=<value>
  static const String iucnApiToken = String.fromEnvironment(
    'IUCN_API_TOKEN',
    defaultValue: '',
  );

  /// Returns true if the IUCN token is present and non-empty.
  static bool get hasIucnToken => iucnApiToken.isNotEmpty;
}