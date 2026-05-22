import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/fish.dart';
import '../../services/fish_classifier.dart';

class FishImageSearchScreen extends StatefulWidget {
  final List<Fish> allSpecies;
  const FishImageSearchScreen({super.key, required this.allSpecies});

  @override
  State<FishImageSearchScreen> createState() => _FishImageSearchScreenState();
}

class _FishImageSearchScreenState extends State<FishImageSearchScreen> {
  Uint8List? _imageBytes;
  List<Fish> _matchedFish = [];
  List<String> _detectedLabels = [];
  bool _isLoading = false;
  bool _isModelReady = false;
  String _statusMessage = '';
  final TextEditingController _searchController = TextEditingController();

  final FishClassifier _classifier = FishClassifier();

  // Confidence tuning
  static const double _minConfidence = 0.35;

  // Expanded mapping from ImageNet keywords to your fish species.
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

  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      await _classifier.init(
        modelAsset: 'assets/models/model (1).tflite',
        labelsAsset: 'assets/models/labels (1).txt',
      );
      debugPrint('✅ Model loaded');
      setState(() {
        _isModelReady = true;
        _isLoading = false;
      });
    } on UnsupportedError {
      debugPrint('ℹ️ AI classification not available on this platform');
      setState(() {
        _isModelReady = false;
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

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _isLoading = true;
      _matchedFish = [];
      _detectedLabels = [];
      _statusMessage = 'Identifying fish...';
    });

    await _classifyImage(bytes);
  }

  Future<void> _classifyImage(Uint8List bytes) async {
    try {
      final predictions = _classifier.classify(bytes, []);
      final matched = _mapToLocalFish(predictions);
      final filtered = matched.where((e) => e.$2 >= _minConfidence).toList();

      setState(() {
        if (filtered.isEmpty) {
          _statusMessage = 'No confident match (below ${(_minConfidence * 100).toInt()}%). Try manual search.';
          _matchedFish = [];
          _detectedLabels = [];
        } else {
          _matchedFish = filtered.map((e) => e.$1).toList();
          _detectedLabels = filtered.map((e) => '${e.$1.commonName} (${(e.$2 * 100).toStringAsFixed(1)}%)').toList();
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
    _classifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // UI BUILD (your original working UI, no AppTheme errors)
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
                  if (_detectedLabels.isNotEmpty && !_isLoading && _imageBytes != null)
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: _imageBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
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