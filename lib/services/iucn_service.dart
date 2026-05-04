import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Represents the IUCN conservation data for a single species.
class IucnResult {
  /// Full display label matching existing UI, e.g. "Near Threatened (NT)"
  final String conservationStatus;

  /// 2-letter IUCN category code, e.g. "NT"
  final String category;

  /// Population trend from IUCN: "Decreasing", "Stable", "Increasing", or null
  final String? populationTrend;

  /// Direct link to the species page on iucnredlist.org, or null
  final String? iucnUrl;

  const IucnResult({
    required this.conservationStatus,
    required this.category,
    this.populationTrend,
    this.iucnUrl,
  });

  // Maps IUCN 2-letter category codes → full display labels used in your UI
  static const Map<String, String> _categoryMap = {
    'EX': 'Extinct (EX)',
    'EW': 'Extinct in the Wild (EW)',
    'CR': 'Critically Endangered (CR)',
    'EN': 'Endangered (EN)',
    'VU': 'Vulnerable (VU)',
    'NT': 'Near Threatened (NT)',
    'LC': 'Least Concern (LC)',
    'DD': 'Data Deficient (DD)',
    'NE': 'Not Evaluated (NE)',
  };

  factory IucnResult.fromApiMap(Map<String, dynamic> map) {
    final category = (map['category'] as String?) ?? 'NE';
    final taxonId = map['taxonid'];
    return IucnResult(
      category: category,
      conservationStatus: _categoryMap[category] ?? 'Not Evaluated (NE)',
      populationTrend: map['population_trend'] as String?,
      iucnUrl: taxonId != null
          ? 'https://www.iucnredlist.org/species/$taxonId'
          : null,
    );
  }

  /// Safe fallback used when the API is unreachable or the token is missing.
  static const IucnResult unknown = IucnResult(
    conservationStatus: 'Not Evaluated (NE)',
    category: 'NE',
  );
}

/// Fetches IUCN Red List conservation status for a given scientific name
/// by calling the IUCN API directly from the Flutter client.
///
/// The API token is injected at build time via --dart-define and never
/// stored in source control.
///
/// Caching: one in-memory session cache keyed by scientific name, so
/// the API is only hit once per species per app session.
class IucnService {
  IucnService._(); // Static-only — not instantiable

  static const String _baseUrl = 'https://apiv3.iucnredlist.org/api/v3';

  /// In-memory session cache — avoids repeat API calls within one app session.
  static final Map<String, IucnResult> _sessionCache = {};

  /// Fetches IUCN status for [scientificName].
  ///
  /// Returns [IucnResult.unknown] on any error so callers never need to
  /// handle exceptions — the UI degrades gracefully to the RTDB fallback.
  static Future<IucnResult> getStatus(String scientificName) async {
    final key = scientificName.trim();
    if (key.isEmpty) return IucnResult.unknown;

    // 1. Session cache hit — return immediately
    if (_sessionCache.containsKey(key)) {
      return _sessionCache[key]!;
    }

    // 2. Token guard — degrade gracefully if not injected at build time
    if (!AppConfig.hasIucnToken) {
      assert(() {
        // ignore: avoid_print
        print('[IucnService] IUCN_API_TOKEN not set. '
            'Run with: flutter run --dart-define=IUCN_API_TOKEN=your_token');
        return true;
      }());
      return IucnResult.unknown;
    }

    // 3. Call IUCN API
    try {
      final uri = Uri.parse(
        '$_baseUrl/species/${Uri.encodeComponent(key)}'
        '?token=${AppConfig.iucnApiToken}',
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        assert(() {
          // ignore: avoid_print
          print('[IucnService] 401 Unauthorized — check your IUCN_API_TOKEN.');
          return true;
        }());
        return IucnResult.unknown;
      }

      if (response.statusCode != 200) {
        assert(() {
          // ignore: avoid_print
          print('[IucnService] HTTP ${response.statusCode} for "$key"');
          return true;
        }());
        return IucnResult.unknown;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['result'] as List<dynamic>?;
      final first = results?.isNotEmpty == true ? results!.first : null;

      final iucnResult = first != null
          ? IucnResult.fromApiMap(Map<String, dynamic>.from(first as Map))
          : IucnResult.unknown;

      // 4. Store in session cache
      _sessionCache[key] = iucnResult;
      return iucnResult;
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[IucnService] Error fetching "$key": $e');
        return true;
      }());
      return IucnResult.unknown;
    }
  }

  /// Clears the session cache — call this on pull-to-refresh if needed.
  static void clearSessionCache() => _sessionCache.clear();
}