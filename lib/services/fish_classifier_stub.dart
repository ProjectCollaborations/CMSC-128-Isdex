import 'dart:typed_data';

class FishClassifier {
  bool get isReady => false;

  Future<void> init({
    required String modelAsset,
    required String labelsAsset,
  }) async {
    throw UnsupportedError('AI fish classification is not available on this platform.');
  }

  List<(String, double)> classify(Uint8List imageBytes, List<String> classLabels) {
    return [];
  }

  void dispose() {}
}
