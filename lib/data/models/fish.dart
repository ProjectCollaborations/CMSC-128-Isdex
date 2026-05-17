// lib/data/models/fish.dart
import 'package:flutter/foundation.dart';

@immutable
class Fish {
  final String key;
  final String fishId;
  final String commonName;
  final String scientificName;
  final String localName;
  final String habitat;
  final String sizeRange;
  final String imageUrl;
  final List<String> identifyingFeatures;
  final String conservationStatus;
  final String conservationDetails;
  final String distribution;

  const Fish({
    required this.key,
    required this.fishId,
    required this.commonName,
    required this.scientificName,
    required this.localName,
    required this.habitat,
    required this.sizeRange,
    required this.imageUrl,
    required this.identifyingFeatures,
    required this.conservationStatus,
    required this.conservationDetails,
    required this.distribution,
  });

  /// Factory method to create Fish from Firebase snapshot.
  factory Fish.fromSnapshot(String key, Map<dynamic, dynamic> data) {
    return Fish(
      key: key,
      fishId: data['fishId']?.toString() ?? key,
      commonName: data['commonName']?.toString() ?? 'Unknown',
      scientificName: data['scientificName']?.toString() ?? 'N/A',
      localName: data['localName']?.toString() ?? 'N/A',
      habitat: data['habitat']?.toString() ?? 'Unknown',
      sizeRange: data['sizeRange']?.toString() ?? 'N/A',
      imageUrl: data['imageUrl']?.toString() ?? '',
      identifyingFeatures: _parseFeatures(data['identifyingFeatures']),
      conservationStatus: data['conservationStatus']?.toString() ?? 'Not Evaluated (NE)',
      conservationDetails: data['conservationDetails']?.toString() ?? '',
      distribution: data['distribution']?.toString() ?? '',
    );
  }

  static List<String> _parseFeatures(dynamic features) {
    if (features == null) return [];
    if (features is List) {
      return features.map((e) => e.toString()).toList();
    }
    if (features is String && features.isNotEmpty) {
      return features.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  /// Convert to map for Firebase storage.
  Map<String, dynamic> toMap() {
    return {
      'fishId': fishId,
      'commonName': commonName,
      'scientificName': scientificName,
      'localName': localName,
      'habitat': habitat,
      'sizeRange': sizeRange,
      'imageUrl': imageUrl,
      'identifyingFeatures': identifyingFeatures,
      'conservationStatus': conservationStatus,
      'conservationDetails': conservationDetails,
      'distribution': distribution,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Fish && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}