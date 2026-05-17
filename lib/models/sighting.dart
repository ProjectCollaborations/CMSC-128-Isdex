enum SightingStatus { pending, approved, rejected }

extension SightingStatusX on SightingStatus {
  String get name => toString().split('.').last;
}

SightingStatus sightingStatusFromString(String? value) {
  return SightingStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => SightingStatus.pending,
  );
}

class Sighting {
  final String id;
  final String fishName;
  final String fishId;
  final String displayName;
  final String userId;
  final String notes;
  final double latitude;
  final double longitude;
  final String createdAt;
  final SightingStatus status;
  final bool isAnonymous;
  final bool isReported;
  final String geoValidationStatus;
  final String geoValidationMessage;

  const Sighting({
    required this.id,
    required this.fishName,
    required this.fishId,
    required this.displayName,
    required this.userId,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
    required this.isAnonymous,
    this.isReported = false,
    this.geoValidationStatus = 'unknown',
    this.geoValidationMessage = '',
  });

  factory Sighting.fromMap(String id, Map<dynamic, dynamic> map) {
    return Sighting(
      id: id,
      fishName: map['fishName']?.toString() ?? 'Unknown',
      fishId: map['fishId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Anonymous',
      userId: map['userId']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt']?.toString() ?? '0',
      status: sightingStatusFromString(map['status']?.toString()),
      isAnonymous: map['isAnonymous'] == true,
      isReported: map['isReported'] == true,
      geoValidationStatus: map['geoValidationStatus']?.toString() ?? 'unknown',
      geoValidationMessage: map['geoValidationMessage']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'fishName': fishName,
        'fishId': fishId,
        'displayName': displayName,
        'userId': userId,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt,
        'status': status.name,
        'isAnonymous': isAnonymous,
        'isReported': isReported,
        'geoValidationStatus': geoValidationStatus,
        'geoValidationMessage': geoValidationMessage,
      };

  Sighting copyWith({
    String? id,
    String? fishName,
    String? fishId,
    String? displayName,
    String? userId,
    String? notes,
    double? latitude,
    double? longitude,
    String? createdAt,
    SightingStatus? status,
    bool? isAnonymous,
    bool? isReported,
    String? geoValidationStatus,
    String? geoValidationMessage,
  }) {
    return Sighting(
      id: id ?? this.id,
      fishName: fishName ?? this.fishName,
      fishId: fishId ?? this.fishId,
      displayName: displayName ?? this.displayName,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isReported: isReported ?? this.isReported,
      geoValidationStatus: geoValidationStatus ?? this.geoValidationStatus,
      geoValidationMessage:
          geoValidationMessage ?? this.geoValidationMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Sighting && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
