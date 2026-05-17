class IucnResult {
  final String conservationStatus;
  final String category;
  final String? populationTrend;
  final String? iucnUrl;

  const IucnResult({
    required this.conservationStatus,
    required this.category,
    this.populationTrend,
    this.iucnUrl,
  });

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

  static const IucnResult unknown = IucnResult(
    conservationStatus: 'Not Evaluated (NE)',
    category: 'NE',
  );
}
