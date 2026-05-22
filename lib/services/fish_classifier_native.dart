import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;

class FishClassifier {
  Interpreter? _interpreter;
  List<String> _classLabels = [];
  int _outputSize = 0;
  static const int _inputSize = 224;

  bool get isReady => _interpreter != null;

  Future<void> init({
    required String modelAsset,
    required String labelsAsset,
  }) async {
    _interpreter = await Interpreter.fromAsset(modelAsset);

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    if (outputShape.length >= 2) {
      _outputSize = outputShape.last;
    } else {
      throw Exception('Unexpected output shape: $outputShape');
    }

    final labelString = await rootBundle.loadString(labelsAsset);
    _classLabels = labelString
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (_classLabels.length != _outputSize) {
      debugPrint(
        'Warning: labels count (${_classLabels.length}) != model output size ($_outputSize)',
      );
    }
  }

  List<(String, double)> classify(Uint8List imageBytes, List<String> classLabels) {
    if (_interpreter == null) return [];

    final input = _preprocess(imageBytes);

    final output = List.filled(1 * _outputSize, 0.0).reshape([1, _outputSize]);

    _interpreter!.run(input, output);

    final scores = output[0];
    final probabilities = _softmax(scores);
    final topPredictions = _getTopPredictions(probabilities, 5);

    return topPredictions
        .map((e) => (classLabels[e.$1], e.$2))
        .toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  List<dynamic> _preprocess(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    final scale = _inputSize / (image.width < image.height ? image.width : image.height);
    int newWidth = (image.width * scale).round();
    int newHeight = (image.height * scale).round();
    image = img.copyResize(image, width: newWidth, height: newHeight);

    final cropX = (image.width - _inputSize) ~/ 2;
    final cropY = (image.height - _inputSize) ~/ 2;
    image = img.copyCrop(image, x: cropX, y: cropY, width: _inputSize, height: _inputSize);

    final flatInput = Float32List(1 * _inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        flatInput[idx++] = (pixel.r / 127.5) - 1.0;
        flatInput[idx++] = (pixel.g / 127.5) - 1.0;
        flatInput[idx++] = (pixel.b / 127.5) - 1.0;
      }
    }

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0)),
      ),
    );
    idx = 0;
    for (int h = 0; h < _inputSize; h++) {
      for (int w = 0; w < _inputSize; w++) {
        for (int c = 0; c < 3; c++) {
          input[0][h][w][c] = flatInput[idx++];
        }
      }
    }
    return input;
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map<double>((x) => x / sumExp).toList();
  }

  List<(int, double)> _getTopPredictions(List<double> probabilities, int topK) {
    final indices = List.generate(probabilities.length, (i) => i);
    indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    final result = <(int, double)>[];
    for (int i = 0; i < topK && i < indices.length; i++) {
      final idx = indices[i];
      if (idx < _classLabels.length && probabilities[idx] > 0.01) {
        result.add((idx, probabilities[idx]));
      }
    }
    return result;
  }
}
