import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;
import '../../models/fish.dart';
import 'dart:math';

class FishImageSearchScreen extends StatefulWidget {
  final List<Fish> allSpecies;
  const FishImageSearchScreen({super.key, required this.allSpecies});

  @override
  State<FishImageSearchScreen> createState() => _FishImageSearchScreenState();
}

class _FishImageSearchScreenState extends State<FishImageSearchScreen> {
  File? _imageFile;
  List<Fish> _matchedFish = [];
  List<String> _detectedLabels = [];
  bool _isLoading = false;
  bool _isModelReady = false;
  String _statusMessage = '';
  final TextEditingController _searchController = TextEditingController();

  Interpreter? _interpreter;
  List<String> _imagenetLabels = [];
  static const int _inputSize = 224;
  static const int _outputSize = 1001; // ImageNet output classes

  // Expanded mapping from ImageNet keywords to your fish species.
  // Keys are lowercase keywords (often singular), values are lists of exact fish common names.
  final Map<String, List<String>> _keywordToFish = {
    // Tuna family
    'tuna': ['Yellowfin Tuna', 'Tuna'],
    'yellowfin': ['Yellowfin Tuna'],

    // Snappers
    'snapper': ['Red Snapper', 'Gray Snapper'],
    'red snapper': ['Red Snapper'],
    'gray snapper': ['Gray Snapper'],

    // Groupers
    'grouper': ['Leopard Coral Grouper', 'Grouper'],
    'leopard coral grouper': ['Leopard Coral Grouper'],

    // Mackerels & Scads
    'mackerel': ['Long-jawed Mackerel', 'Mackerel Scad', 'Mackerel'],
    'long-jawed mackerel': ['Long-jawed Mackerel'],
    'scad': ['Mackerel Scad'],

    // Carps
    'carp': ['Common Carp', 'Carp'],
    'common carp': ['Common Carp'],

    // Catfish
    'catfish': ['Manila Catfish', 'Catfish'],
    'manila catfish': ['Manila Catfish'],

    // Barracuda
    'barracuda': ['Barracuda'],

    // Butterflyfish
    'butterflyfish': ['Butterflyfish'],
    'butterfly fish': ['Butterflyfish'],

    // Eel
    'eel': ['Eel'],

    // Parrotfish
    'parrotfish': ['Parrotfish'],
    'parrot fish': ['Parrotfish'],

    // Surgeonfish
    'surgeonfish': ['Surgeonfish'],
    'surgeon fish': ['Surgeonfish'],

    // Pufferfish
    'pufferfish': ['Pufferfish'],
    'puffer': ['Pufferfish'],

    // Porcupinefish
    'porcupinefish': ['Porcupinefish'],
    'porcupine fish': ['Porcupinefish'],

    // Boxfish
    'boxfish': ['Boxfish'],
    'box fish': ['Boxfish'],

    // Seahorse
    'seahorse': ['Seahorse'],

    // Sea Dragon
    'sea dragon': ['Sea Dragon'],
    'seadragon': ['Sea Dragon'],

    // Jacks & Trevally
    'jack': ['Jack', 'Trevally'],
    'trevally': ['Trevally'],
    'crevalle': ['Jack'],

    // Seabass
    'seabass': ['Asian Seabass'],
    'asian seabass': ['Asian Seabass'],
    'barramundi': ['Asian Seabass'],

    // Bream
    'bream': ['Threadfin Bream'],
    'threadfin bream': ['Threadfin Bream'],

    // Emperor
    'emperor': ['Emperor'],
    'emperor fish': ['Emperor'],

    // Goatfish
    'goatfish': ['Goatfish'],
    'goat fish': ['Goatfish'],

    // Rabbitfish
    'rabbitfish': ['Rabbit Fish'],
    'rabbit fish': ['Rabbit Fish'],

    // Moonfish
    'moonfish': ['Moonfish'],
    'moon fish': ['Moonfish'],

    // Ribbonfish
    'ribbonfish': ['Ribbonfish'],
    'ribbon fish': ['Ribbonfish'],

    // Pomfret
    'pomfret': ['Pomfret'],

    // Dolphinfish (Mahi-Mahi)
    'dolphinfish': ['Dolphinfish'],
    'mahi': ['Dolphinfish'],

    // Salmon
    'salmon': ['Threadfin Salmon'],
    'threadfin salmon': ['Threadfin Salmon'],

    // Bigeye
    'bigeye': ['Red Bigeye'],
    'red bigeye': ['Red Bigeye'],

    // Scat
    'scat': ['Spotted Scat'],
    'spotted scat': ['Spotted Scat'],

    // Halfbeak
    'halfbeak': ['Halfbeak'],
    'half beak': ['Halfbeak'],

    // Needlefish
    'needlefish': ['Needlefish'],
    'needle fish': ['Needlefish'],

    // Flying fish
    'flying fish': ['Flying Fish'],
    'flyingfish': ['Flying Fish'],

    // Wrasse
    'wrasse': ['Wrasse'],

    // Sweetlip
    'sweetlip': ['Sweetlip'],

    // Damselfish
    'damselfish': ['Damselfish'],
    'damsel fish': ['Damselfish'],

    // Goldstripe Sardinella
    'sardinella': ['Goldstripe Sardinella'],
    'goldstripe sardinella': ['Goldstripe Sardinella'],
    'sardine': ['Goldstripe Sardinella'],
  };

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // --------------------------------------------------------------
  // Model loading
  // --------------------------------------------------------------
  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/model (1).tflite');
      final labelString = await rootBundle.loadString('assets/models/labels (1).txt');
      _imagenetLabels = labelString
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      debugPrint('✅ Loaded ${_imagenetLabels.length} ImageNet labels');
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

  // --------------------------------------------------------------
  // Image picker
  // --------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    if (!_isModelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI model is still loading, please wait...')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
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

  // --------------------------------------------------------------
  // Image preprocessing (224x224, RGB normalized to [-1, 1])
  // --------------------------------------------------------------
  Future<Float32List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize keeping aspect ratio, then center crop to 224x224
    final scale = _inputSize / (image.width < image.height ? image.width : image.height);
    int newWidth = (image.width * scale).round();
    int newHeight = (image.height * scale).round();
    image = img.copyResize(image, width: newWidth, height: newHeight);

    final cropX = (image.width - _inputSize) ~/ 2;
    final cropY = (image.height - _inputSize) ~/ 2;
    image = img.copyCrop(image, x: cropX, y: cropY, width: _inputSize, height: _inputSize);

    // Normalize pixel values to [-1, 1]
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[idx++] = (pixel.r / 127.5) - 1.0;
        input[idx++] = (pixel.g / 127.5) - 1.0;
        input[idx++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return input;
  }

  // --------------------------------------------------------------
  // Run inference and map results to local fish
  // --------------------------------------------------------------
  Future<void> _classifyImage(File imageFile) async {
    if (_interpreter == null) return;

    try {
      // 1. Preprocess image
      final flatInput = await _preprocessImage(imageFile);
      // Reshape to [1, 224, 224, 3] as expected by the model
      final input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0))));
      int idx = 0;
      for (int h = 0; h < _inputSize; h++) {
        for (int w = 0; w < _inputSize; w++) {
          for (int c = 0; c < 3; c++) {
            input[0][h][w][c] = flatInput[idx++];
          }
        }
      }

      // 2. Create output tensor (1001 classes)
      final output = List.filled(1 * 50, 0.0).reshape([1, 50]);

      // 3. Run inference
      _interpreter!.run(input, output);

      // 4. Convert raw logits to probabilities (softmax)
      final probabilities = _softmax(output[0]);

      // 5. Get top 10 predictions
      final topPredictions = _getTopPredictions(probabilities, 10);

      // 6. Map ImageNet labels to your fish species
      final matched = _mapToLocalFish(topPredictions);

      // 7. Update UI
      setState(() {
        if (matched.isEmpty) {
          _statusMessage = 'No matching fish found. Try manual search.';
          _matchedFish = [];
          _detectedLabels = [];
        } else {
          _matchedFish = matched.map((e) => e.$1).toList();
          _detectedLabels = matched.map((e) => '${e.$1.commonName} (${(e.$2 * 100).toStringAsFixed(1)}%)').toList();
          _statusMessage = '';
        }
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

  // Softmax conversion
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map<double>((x) => x / sumExp).toList();
  }
  // Get top-K indices and labels
  List<(String, double)> _getTopPredictions(List<double> probabilities, int topK) {
    final indices = List.generate(probabilities.length, (i) => i);
    indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    final result = <(String, double)>[];
    for (int i = 0; i < topK && i < indices.length; i++) {
      final idx = indices[i];
      if (idx < _imagenetLabels.length && probabilities[idx] > 0.01) {
        result.add((_imagenetLabels[idx], probabilities[idx]));
      }
    }
    return result;
  }

  // Map ImageNet labels to your fish list using keyword matching
  List<(Fish, double)> _mapToLocalFish(List<(String, double)> predictions) {
    final Map<Fish, double> scoreMap = {};

    for (var pred in predictions) {
      final imagenetLabel = pred.$1.toLowerCase();
      final confidence = pred.$2;

      // Find which fish keywords are contained in the ImageNet label
      Set<String> matchedFishNames = {};
      for (var entry in _keywordToFish.entries) {
        final keyword = entry.key.toLowerCase();
        if (imagenetLabel.contains(keyword) || keyword.contains(imagenetLabel)) {
          matchedFishNames.addAll(entry.value);
        }
      }

      // Also try to match directly by splitting the label (e.g., "tuna, yellowfin")
      final words = imagenetLabel.split(RegExp(r'[ ,_-]+'));
      for (var word in words) {
        if (word.length < 3) continue;
        for (var entry in _keywordToFish.entries) {
          if (entry.key.contains(word) || word.contains(entry.key)) {
            matchedFishNames.addAll(entry.value);
          }
        }
      }

      // Now assign confidence to actual fish objects
      for (var fish in widget.allSpecies) {
        if (matchedFishNames.contains(fish.commonName)) {
          scoreMap[fish] = (scoreMap[fish] ?? 0.0) + confidence;
        }
      }
    }

    // Sort by total confidence
    final matches = scoreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Normalize scores to [0,1] relative to the highest score
    final maxScore = matches.isNotEmpty ? matches.first.value : 1.0;
    return matches
        .map((e) => (e.key, (e.value / maxScore).clamp(0.0, 1.0)))
        .toList();
  }

  // --------------------------------------------------------------
  // Manual search
  // --------------------------------------------------------------
  void _performManualSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a fish name to search')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Simulate async search (could be instant but we add a small delay for UX)
    Future.delayed(const Duration(milliseconds: 100), () {
      final matches = widget.allSpecies.where((fish) {
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

  void _navigateToFishDetail(Fish fish) {
    context.push('/fish/${fish.id}');
  }

  @override
  void dispose() {
    _interpreter?.close();
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // UI BUILD (unchanged, but kept for completeness)
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search by Photo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildImagePreview(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  if (_detectedLabels.isNotEmpty && !_isLoading && _imageFile != null)
                    _buildLabelsSection(),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildManualSearch(),
                  const SizedBox(height: 16),
                  if (_isLoading) _buildLoadingIndicator(),
                  if (_matchedFish.isNotEmpty && !_isLoading)
                    _buildResultsCount(),
                  if (_matchedFish.isNotEmpty && !_isLoading)
                    _buildResultsList(),
                  if (_statusMessage.isNotEmpty && !_isLoading && _matchedFish.isEmpty)
                    _buildNoResults(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surface),
      ),
      child: _imageFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 8),
                Text(
                  'Take or select a photo of a fish',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI will identify the fish offline',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
    );
  }

  Widget _buildLabelsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppTheme.navy500),
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
            children: _detectedLabels.take(6).map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.teal200),
                ),
                child: Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[800])),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildManualSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, size: 20, color: AppTheme.navy500),
              const SizedBox(width: 8),
              const Text('Manual Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search by common name, scientific name, or local name:',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
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
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing image with AI...'),
        ],
      ),
    );
  }

  Widget _buildResultsCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Found ${_matchedFish.length} matching fish',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _matchedFish.length,
      itemBuilder: (context, i) {
        final fish = _matchedFish[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _navigateToFishDetail(fish),
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
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              fish.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.set_meal, color: Colors.blue[300], size: 30),
                            ),
                          )
                        : Icon(Icons.set_meal, color: Colors.blue[300], size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(fish.commonName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            if (i < _detectedLabels.length)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)),
                                child: Text(_detectedLabels[i], style: TextStyle(fontSize: 11, color: Colors.green[800])),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(fish.scientificName, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
                          child: Text(fish.habitat, style: TextStyle(fontSize: 10, color: Colors.blue[800], fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(_statusMessage, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}