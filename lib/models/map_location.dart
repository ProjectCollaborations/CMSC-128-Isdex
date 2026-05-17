class MapLocation {
  final String id;
  final String fishId;
  final double latitude;
  final double longitude;
  final String region;

  const MapLocation({
    required this.id,
    required this.fishId,
    required this.latitude,
    required this.longitude,
    required this.region,
  });

  factory MapLocation.fromMap(String id, Map<dynamic, dynamic> map) {
    return MapLocation(
      id: id,
      fishId: map['fishId']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 12.8797,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 121.774,
      region: map['region']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'fishId': fishId,
        'latitude': latitude,
        'longitude': longitude,
        'region': region,
      };

  MapLocation copyWith({
    String? id,
    String? fishId,
    double? latitude,
    double? longitude,
    String? region,
  }) {
    return MapLocation(
      id: id ?? this.id,
      fishId: fishId ?? this.fishId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      region: region ?? this.region,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapLocation && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
