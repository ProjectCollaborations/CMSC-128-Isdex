// lib/data/models/sighting.dart
import 'package:flutter/material.dart';

enum SightingStatus {
  pending,
  verified,
  rejected,
  archived;

  String get displayName {
    switch (this) {
      case SightingStatus.pending:
        return 'Pending';
      case SightingStatus.verified:
        return 'Verified';
      case SightingStatus.rejected:
        return 'Rejected';
      case SightingStatus.archived:
        return 'Archived';
    }
  }

  Color get color {
    switch (this) {
      case SightingStatus.pending:
        return Colors.orange;
      case SightingStatus.verified:
        return Colors.green;
      case SightingStatus.rejected:
        return Colors.red;
      case SightingStatus.archived:
        return Colors.grey;
    }
  }
}

@immutable
class Sighting {
  final String id;
  final String userId;
  final String displayName;
  final bool isAnonymous;
  final String fishId;
  final String fishName;
  final String notes;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final SightingStatus status;
  final bool isReported;
  final String? geoValidationStatus;
  final String? geoValidationMessage;

  const Sighting({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    required this.fishId,
    required this.fishName,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
    required this.isReported,
    this.geoValidationStatus,
    this.geoValidationMessage,
  });

  factory Sighting.fromSnapshot(String id, Map<dynamic, dynamic> data) {
    final rawStatus = data['status']?.toString() ?? 'pending';
    final status = SightingStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => SightingStatus.pending,
    );

    final rawTs = data['createdAt'];
    final createdAt = rawTs is int
        ? DateTime.fromMillisecondsSinceEpoch(rawTs)
        : DateTime.now();

    return Sighting(
      id: id,
      userId: data['userId']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? 'Anonymous',
      isAnonymous: data['isAnonymous'] == true,
      fishId: data['fishId']?.toString() ?? '',
      fishName: data['fishName']?.toString() ?? 'Unknown',
      notes: data['notes']?.toString() ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      status: status,
      isReported: data['isReported'] == true,
      geoValidationStatus: data['geoValidationStatus']?.toString(),
      geoValidationMessage: data['geoValidationMessage']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
      'fishId': fishId,
      'fishName': fishName,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.name,
      'isReported': isReported,
      if (geoValidationStatus != null) 'geoValidationStatus': geoValidationStatus,
      if (geoValidationMessage != null) 'geoValidationMessage': geoValidationMessage,
    };
  }

  Sighting copyWith({
    String? id,
    String? userId,
    String? displayName,
    bool? isAnonymous,
    String? fishId,
    String? fishName,
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    SightingStatus? status,
    bool? isReported,
    String? geoValidationStatus,
    String? geoValidationMessage,
  }) {
    return Sighting(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      fishId: fishId ?? this.fishId,
      fishName: fishName ?? this.fishName,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isReported: isReported ?? this.isReported,
      geoValidationStatus: geoValidationStatus ?? this.geoValidationStatus,
      geoValidationMessage: geoValidationMessage ?? this.geoValidationMessage,
    );
  }
}