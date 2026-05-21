import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;
import '../../models/fish.dart';

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
  List<String> _classLabels = [];
  static const int _inputSize = 224;
  int _outputSize = 0; // will be set after model loads

  // Mapping from label keywords to fish common names (same as before)
  final Map<String, List<String>> _keywordToFish = {
    'tuna': ['Yellowfin Tuna'],
    'yellowfin': ['Yellowfin Tuna'],
    'snapper': ['Red Snapper', 'Gray Snapper'],
    'red snapper': ['Red Snapper'],
    'gray snapper': ['Gray Snapper'],
    'grouper': ['Leopard Coral Grouper', 'Grouper'],
    'leopard coral grouper': ['Leopard Coral Grouper'],
    'mackerel': ['Long-jawed Mackerel', 'Mackerel Scad'],
    'long-jawed mackerel': ['Long-jawed Mackerel'],
    'scad': ['Mackerel Scad'],
    'carp': ['Common Carp'],
    'common carp': ['Common Carp'],
    'catfish': ['Manila Catfish'],
    'manila catfish': ['Manila Catfish'],
    'barracuda': ['Barracuda'],
    'butterflyfish': ['Butterflyfish'],
    'eel': ['Eel'],
    'parrotfish': ['Parrotfish'],
    'surgeonfish': ['Surgeonfish'],
    'pufferfish': ['Pufferfish'],
    'puffer': ['Pufferfish'],
    'porcupinefish': ['Porcupinefish'],
    'boxfish': ['Boxfish'],
    'seahorse': ['Seahorse'],
    'sea dragon': ['Sea Dragon'],
    'seadragon': ['Sea Dragon'],
    'jack': ['Jack', 'Trevally'],
    'trevally': ['Trevally'],
    'seabass': ['Asian Seabass'],
    'asian seabass': ['Asian Seabass'],
    'barramundi': ['Asian Seabass'],
    'bream': ['Threadfin Bream'],
    'emperor': ['Emperor'],
    'goatfish': ['Goatfish'],
    'rabbitfish': ['Rabbit Fish'],
    'moonfish': ['Moonfish'],
    'ribbonfish': ['Ribbonfish'],
    'pomfret': ['Pomfret'],
    'dolphinfish': ['Dolphinfish'],
    'salmon': ['Threadfin Salmon'],
    'bigeye': ['Red Bigeye'],
    'scat': ['Spotted Scat'],
    'halfbeak': ['Halfbeak'],
    'needlefish': ['Needlefish'],
    'flying fish': ['Flying Fish'],
    'flyingfish': ['Flying Fish'],
    'wrasse': ['Wrasse'],
    'sweetlip': ['Sweetlip'],
    'damselfish': ['Damselfish'],
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
  // Load model and read output size dynamically
  // --------------------------------------------------------------
  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/model (1).tflite');
      
      // Get output shape from the model itself
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      if (outputShape.length >= 2) {
        _outputSize = outputShape.last; // e.g., 40
      } else {
        throw Exception('Unexpected output shape: $outputShape');
      }
      
      // Load labels (should have exactly _outputSize lines)
      final labelString = await rootBundle.loadString('assets/models/labels.txt');
      _classLabels = labelString
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      
      if (_classLabels.length != _outputSize) {
        debugPrint('⚠️ Warning: labels count (${_classLabels.length}) != model output size ($_outputSize)');
      }
      
      debugPrint('✅ Model loaded: output size = $_outputSize');
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
  // Preprocess image to 224x224, normalized [-1,1]
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

    // Normalize to [-1, 1] (assuming model expects that)
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
  // Run inference (model outputs raw scores or probabilities)
  // --------------------------------------------------------------
  Future<void> _classifyImage(File imageFile) async {
    if (_interpreter == null) return;

    try {
      // Preprocess
      final flatInput = await _preprocessImage(imageFile);
      final input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0))));
      int idx = 0;
      for (int h = 0; h < _inputSize; h++) {
        for (int w = 0; w < _inputSize; w++) {
          for (int c = 0; c < 3; c++) {
            input[0][h][w][c] = flatInput[idx++];
          }
        }
      }

      // Output buffer with correct size (dynamic)
      final output = List.filled(1 * _outputSize, 0.0).reshape([1, _outputSize]);

      // Run inference
      _interpreter!.run(input, output);

      // Get raw output scores (could be logits or probabilities)
      final scores = output[0];

      // Convert to probabilities (if needed: if scores are not already in [0,1])
      // We'll apply softmax to be safe (it won't hurt if already probabilities)
      final probabilities = _softmax(scores);

      // Get top 5 predictions
      final topPredictions = _getTopPredictions(probabilities, 5);

      // Map to your fish species
      final matched = _mapToLocalFish(topPredictions);

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

  // Softmax conversion (safe even if input is already probabilities)
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map<double>((x) => x / sumExp).toList();
  }

  // Get top-K indices and labels (using actual model outputs)
  List<(String, double)> _getTopPredictions(List<double> probabilities, int topK) {
    final indices = List.generate(probabilities.length, (i) => i);
    indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    final result = <(String, double)>[];
    for (int i = 0; i < topK && i < indices.length; i++) {
      final idx = indices[i];
      if (idx < _classLabels.length) {
        result.add((_classLabels[idx], probabilities[idx]));
      }
    }
    return result;
  }

  // Map model output labels to your fish objects using keyword matching
  List<(Fish, double)> _mapToLocalFish(List<(String, double)> predictions) {
    final Map<Fish, double> scoreMap = {};

    for (var pred in predictions) {
      final label = pred.$1.toLowerCase();
      final confidence = pred.$2;

      // Find which fish keywords are contained in the label
      Set<String> matchedFishNames = {};
      for (var entry in _keywordToFish.entries) {
        final keyword = entry.key.toLowerCase();
        if (label.contains(keyword) || keyword.contains(label)) {
          matchedFishNames.addAll(entry.value);
        }
      }

      // Also split label into words (e.g., "red_snapper" -> ["red","snapper"])
      final words = label.split(RegExp(r'[ ,_-]+'));
      for (var word in words) {
        if (word.length < 3) continue;
        for (var entry in _keywordToFish.entries) {
          if (entry.key.contains(word) || word.contains(entry.key)) {
            matchedFishNames.addAll(entry.value);
          }
        }
      }

      // Add confidence to matching fish objects
      for (var fish in widget.allSpecies) {
        if (matchedFishNames.contains(fish.commonName)) {
          scoreMap[fish] = (scoreMap[fish] ?? 0.0) + confidence;
        }
      }
    }

    final matches = scoreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxScore = matches.isNotEmpty ? matches.first.value : 1.0;
    return matches
        .map((e) => (e.key, (e.value / maxScore).clamp(0.0, 1.0)))
        .toList();
  }

  // --------------------------------------------------------------
  // Manual search (unchanged)
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
  // UI BUILD (unchanged, omitted for brevity, but must be included)
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
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

  // All the UI helper methods (unchanged from your original)
  Widget _buildImagePreview() {
    return Container(
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
            children: _detectedLabels.take(6).map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
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
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildManualSearch() {
    return Container(
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        return Card(
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
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_statusMessage, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}