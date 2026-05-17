import 'dart:convert';
import 'dart:io';

class GeoValidationResult {
  final String status;
  final String message;

  const GeoValidationResult({
    required this.status,
    required this.message,
  });
}

class GeoValidationService {
  GeoValidationService._();

  static Future<GeoValidationResult> validate(
      double latitude, double longitude) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );

      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'isdex-app/1.0 (sighting-validation)');
      final res = await req.close();

      if (res.statusCode != 200) {
        return GeoValidationResult(
          status: 'unknown',
          message: 'Location check unavailable (HTTP ${res.statusCode})',
        );
      }

      final body = await utf8.decoder.bind(res).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const GeoValidationResult(
          status: 'unknown',
          message: 'Location check unavailable',
        );
      }

      final address = decoded['address'];
      final displayName =
          (decoded['display_name'] ?? '').toString().toLowerCase();
      final topType = (decoded['type'] ?? '').toString().toLowerCase();
      final topCategory =
          (decoded['category'] ?? '').toString().toLowerCase();

      if (address is! Map) {
        return GeoValidationResult(
          status: 'unknown',
          message: displayName.isNotEmpty
              ? 'Location check uncertain: ${decoded['display_name']}'
              : 'Location check uncertain',
        );
      }

      final addr = Map<String, dynamic>.from(address);

      bool hasAny(List<String> keys) => keys.any((k) {
            final v = addr[k];
            return v != null && v.toString().trim().isNotEmpty;
          });

      final hasLandSignals = hasAny([
        'road', 'house_number', 'suburb', 'neighbourhood',
        'city', 'town', 'village', 'municipality', 'county', 'state', 'postcode',
      ]);

      final hasWaterSignals = hasAny([
        'ocean', 'sea', 'water', 'waterway', 'bay', 'strait', 'river', 'lake',
      ]);

      final isTopLevelWater = topCategory == 'natural' &&
          ['water', 'bay', 'strait', 'coastline', 'river', 'riverbank', 'reef']
              .contains(topType);

      if (isTopLevelWater) {
        return GeoValidationResult(
          status: 'water',
          message:
              'Detected on water (${decoded['display_name'] ?? 'unknown area'})',
        );
      }

      if (hasLandSignals) {
        return GeoValidationResult(
          status: 'land',
          message:
              'Detected on land (${decoded['display_name'] ?? 'unknown area'})',
        );
      }

      if (hasWaterSignals) {
        return GeoValidationResult(
          status: 'water',
          message:
              'Detected on water (${decoded['display_name'] ?? 'unknown area'})',
        );
      }

      return GeoValidationResult(
        status: 'unknown',
        message: displayName.isNotEmpty
            ? 'Location check uncertain: ${decoded['display_name']}'
            : 'Location check uncertain',
      );
    } catch (e) {
      return GeoValidationResult(
        status: 'unknown',
        message: 'Location check failed: $e',
      );
    } finally {
      client.close(force: true);
    }
  }
}
