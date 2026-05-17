class Fish {
  final String id;
  final String commonName;
  final String scientificName;
  final String localName;
  final String habitat;
  final String sizeRange;
  final List<String> identifyingFeatures;
  final String imageUrl;
  final String conservationStatus;
  final String conservationDetails;
  final String distribution;

  const Fish({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.localName,
    required this.habitat,
    required this.sizeRange,
    required this.identifyingFeatures,
    required this.imageUrl,
    required this.conservationStatus,
    required this.conservationDetails,
    required this.distribution,
  });

  factory Fish.fromMap(String id, Map<dynamic, dynamic> map) {
    List<String> parseFeatures(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return Fish(
      id: id,
      commonName: map['commonName']?.toString() ?? '',
      scientificName: map['scientificName']?.toString() ?? '',
      localName: map['localName']?.toString() ?? '',
      habitat: map['habitat']?.toString() ?? '',
      sizeRange: map['sizeRange']?.toString() ?? '',
      identifyingFeatures: parseFeatures(map['identifyingFeatures']),
      imageUrl: map['imageUrl']?.toString() ?? '',
      conservationStatus: map['conservationStatus']?.toString() ?? '',
      conservationDetails: map['conservationDetails']?.toString() ?? '',
      distribution: map['distribution']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'commonName': commonName,
        'scientificName': scientificName,
        'localName': localName,
        'habitat': habitat,
        'sizeRange': sizeRange,
        'identifyingFeatures': identifyingFeatures,
        'imageUrl': imageUrl,
        'conservationStatus': conservationStatus,
        'conservationDetails': conservationDetails,
        'distribution': distribution,
      };

  Fish copyWith({
    String? id,
    String? commonName,
    String? scientificName,
    String? localName,
    String? habitat,
    String? sizeRange,
    List<String>? identifyingFeatures,
    String? imageUrl,
    String? conservationStatus,
    String? conservationDetails,
    String? distribution,
  }) {
    return Fish(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      localName: localName ?? this.localName,
      habitat: habitat ?? this.habitat,
      sizeRange: sizeRange ?? this.sizeRange,
      identifyingFeatures: identifyingFeatures ?? this.identifyingFeatures,
      imageUrl: imageUrl ?? this.imageUrl,
      conservationStatus: conservationStatus ?? this.conservationStatus,
      conservationDetails: conservationDetails ?? this.conservationDetails,
      distribution: distribution ?? this.distribution,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fish && id == other.id && commonName == other.commonName;

  @override
  int get hashCode => Object.hash(id, commonName);
}
