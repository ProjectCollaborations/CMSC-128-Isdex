// lib/screens/fish_image_search.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;
import 'fish_detail_page.dart';
import '../data/models/fish.dart';

class FishImageSearch extends StatefulWidget {
  final List<Fish> allFish;
  const FishImageSearch({super.key, required this.allFish});

  @override
  State<FishImageSearch> createState() => _FishImageSearchState();
}

class _FishImageSearchState extends State<FishImageSearch> {
  File? _imageFile;
  List<Fish> _matchedFish = [];
  List<String> _detectedLabels = [];
  bool _isLoading = false;
  bool _isModelReady = false;
  String _statusMessage = '';
  final TextEditingController _searchController = TextEditingController();
  Interpreter? _interpreter;
  List<String> _labels = [];
  static const int _inputSize = 224;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/1.tflite');
      
      final labelString = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelString.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      debugPrint('✅ Label count: ${_labels.length}'); // ← add this
      
      debugPrint('✅ TFLite model loaded with ${_labels.length} labels');
      setState(() {
        _isModelReady = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load model: $e');
      setState(() {
        _statusMessage = 'AI model failed to load. Please restart the app.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isModelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI model is loading, please wait...')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() {
      _imageFile = imageFile;
      _isLoading = true;
      _matchedFish = [];
      _detectedLabels = [];
      _statusMessage = 'Identifying fish...';
    });

    await _classifyImage(imageFile);
  }

  /// Preprocess image: resize to 224x224, normalize to [-1,1], return flat Float32List
  Future<Float32List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize while preserving aspect ratio, then center crop
    final scale = _inputSize / (image.width < image.height ? image.width : image.height);
    int newWidth = (image.width * scale).round();
    int newHeight = (image.height * scale).round();
    image = img.copyResize(image, width: newWidth, height: newHeight);

    final cropX = (image.width - _inputSize) ~/ 2;
    final cropY = (image.height - _inputSize) ~/ 2;
    image = img.copyCrop(image, x: cropX, y: cropY, width: _inputSize, height: _inputSize);

    // Flattened float list of size 1 * 224 * 224 * 3
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        // Normalize to [-1, 1] (MobileNetV2 expects this)
        input[idx++] = (pixel.r / 127.5) - 1.0;
        input[idx++] = (pixel.g / 127.5) - 1.0;
        input[idx++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return input;
  }

    Future<void> _classifyImage(File imageFile) async {
    if (_interpreter == null) return;

    try {
      final flatInput = await _preprocessImage(imageFile);

      final input4D = List.generate(1, (_) =>
        List.generate(_inputSize, (_) =>
          List.generate(_inputSize, (_) =>
            List.filled(3, 0.0))));

      int idx = 0;
      for (int h = 0; h < _inputSize; h++) {
        for (int w = 0; w < _inputSize; w++) {
          for (int c = 0; c < 3; c++) {
            input4D[0][h][w][c] = flatInput[idx++];
          }
        }
      }

      // ✅ Match actual model output size (1001 ImageNet classes)
        final output = List.generate(1, (_) => List.filled(1001, 0.0));
        _interpreter!.run(input4D, output);
        final predictions = _getTopPredictions(output[0], 5);

      setState(() {
        _detectedLabels = predictions
            .map((p) => '${p.$1} (${(p.$2 * 100).toStringAsFixed(0)}%)')
            .toList();
        _matchedFish = _matchAgainstDatabase(
            predictions.map((p) => p.$1).toList(), predictions);
        _statusMessage =
            _matchedFish.isEmpty ? 'No exact match found. Try manual search.' : '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Classification error: $e');
      setState(() {
        _statusMessage = 'Classification failed. Please try manual search.';
        _isLoading = false;
      });
    }
  }
  List<(String, double)> _getTopPredictions(List<double> probabilities, int topK) {
    final indices = List.generate(probabilities.length, (i) => i);
    indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    final result = <(String, double)>[];
    for (int i = 0; i < topK && i < indices.length; i++) {
      final idx = indices[i];

      // ✅ Skip indices that are out of bounds for our labels list
      if (idx >= _labels.length) continue;

      result.add((_labels[idx], probabilities[idx]));
    }
    return result;
  }

  List<Fish> _matchAgainstDatabase(List<String> predictedLabels, List<(String, double)> predictionsWithConfidence) {
    final Map<Fish, double> scoreMap = {};

    for (var fish in widget.allFish) {
      double totalScore = 0;
      final common = fish.commonName.toLowerCase();
      final scientific = fish.scientificName.toLowerCase();
      final local = fish.localName.toLowerCase();

      for (var pred in predictionsWithConfidence) {
        final label = pred.$1.toLowerCase();
        final confidence = pred.$2;

        if (common == label) totalScore += 100 * confidence;
        else if (scientific == label) totalScore += 80 * confidence;
        else if (local == label) totalScore += 70 * confidence;
        else if (common.contains(label) || label.contains(common)) totalScore += 10 * confidence;
        else if (scientific.contains(label) || label.contains(scientific)) totalScore += 8 * confidence;
        else if (local.contains(label) || label.contains(local)) totalScore += 6 * confidence;
      }

      if (totalScore > 0) scoreMap[fish] = totalScore;
    }

    final matches = scoreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return matches.take(10).map((e) => e.key).toList();
  }

  void _performManualSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a fish name to search')),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 100), () {
      final matches = widget.allFish.where((fish) {
        return fish.commonName.toLowerCase().contains(query) ||
               fish.scientificName.toLowerCase().contains(query) ||
               fish.localName.toLowerCase().contains(query);
      }).toList();

      if (mounted) {
        setState(() {
          _matchedFish = matches;
          _detectedLabels = [query];
          _statusMessage = matches.isEmpty ? 'No fish found matching "$query"' : '';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _interpreter?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allFish.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Search by Photo')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('No fish data available. Please restart the app.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search by Photo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Image preview area
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Take or select a photo of a fish',
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'AI will identify the fish offline',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // AI predictions
                  if (_detectedLabels.isNotEmpty && !_isLoading && _imageFile != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'AI Predictions:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _detectedLabels.map((label) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // OR divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Manual search section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search, size: 20, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            const Text('Manual Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Search by common name, scientific name, or local name:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  hintText: 'Enter fish name...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (_) => _performManualSearch(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _performManualSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Search'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Loading indicator
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing image with AI...'),
                        ],
                      ),
                    ),

                  // Results count
                  if (_matchedFish.isNotEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Found ${_matchedFish.length} matching fish',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),

                  // Results list
                  if (_matchedFish.isNotEmpty && !_isLoading)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _matchedFish.length,
                      itemBuilder: (context, i) {
                        final fish = _matchedFish[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FishDetailPage(fish: fish)),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: fish.imageUrl.isNotEmpty
                                        ? Image.asset(
                                            fish.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(Icons.broken_image, color: Colors.grey[400], size: 30);
                                            },
                                          )
                                        : Icon(Icons.set_meal, color: Colors.blue[300], size: 30),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fish.commonName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(fish.scientificName, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(fish.habitat, style: TextStyle(fontSize: 10, color: Colors.blue[800], fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // No results message
                  if (_statusMessage.isNotEmpty && !_isLoading && _matchedFish.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(_statusMessage, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}