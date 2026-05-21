import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../../core/constants/app_theme.dart';
import '../../core/widgets/app_card.dart';
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
  String _statusMessage = '';
  final TextEditingController _searchController = TextEditingController();

  late ImageLabeler _imageLabeler;

  @override
  void initState() {
    super.initState();
    _initializeImageLabeler();
  }

  void _initializeImageLabeler() {
    final options = ImageLabelerOptions(
      confidenceThreshold: 0.5,
    );
    _imageLabeler = ImageLabeler(options: options);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final imageFile = File(picked.path);

    setState(() {
      _imageFile = imageFile;
      _isLoading = true;
      _matchedFish = [];
      _detectedLabels = [];
      _statusMessage = 'Analyzing image with ML Kit...';
    });

    try {
      await _recognizeFishWithMLKit(imageFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Recognition failed. Please try manual search below:';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recognizeFishWithMLKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);

      final List<ImageLabel> labels =
          await _imageLabeler.processImage(inputImage);

      if (labels.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'No objects detected. Try a clearer photo or search manually:';
            _isLoading = false;
          });
        }
        return;
      }

      List<String> detectedLabels = [];
      for (ImageLabel label in labels) {
        if (label.confidence > 0.5) {
          detectedLabels.add(label.label.toLowerCase());
        }
      }

      detectedLabels = detectedLabels.toSet().toList();

      final fishKeywords = ['fish', 'marine', 'sea', 'aquatic', 'swimming'];
      for (var keyword in fishKeywords) {
        if (!detectedLabels.contains(keyword)) {
          detectedLabels.add(keyword);
        }
      }

      setState(() {
        _detectedLabels = detectedLabels;
        _matchedFish = _matchAgainstDatabase(detectedLabels);
        _statusMessage = _matchedFish.isEmpty
            ? 'No matching fish found. Try manual search:'
            : '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Recognition error. Please try manual search:';
          _isLoading = false;
        });
      }
    }
  }

  List<Fish> _matchAgainstDatabase(List<String> detectedLabels) {
    Set<Fish> uniqueMatches = {};

    for (var fish in widget.allSpecies) {
      final common = fish.commonName.toLowerCase();
      final scientific = fish.scientificName.toLowerCase();
      final local = fish.localName.toLowerCase();
      final habitat = fish.habitat.toLowerCase();

      for (var label in detectedLabels) {
        if (common.contains(label) ||
            label.contains(common) ||
            scientific.contains(label) ||
            label.contains(scientific) ||
            local.contains(label) ||
            label.contains(local) ||
            habitat.contains(label)) {
          uniqueMatches.add(fish);
          break;
        }
      }
    }

    var matches = uniqueMatches.toList();
    matches.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      for (var label in detectedLabels) {
        final commonA = a.commonName.toLowerCase();
        final commonB = b.commonName.toLowerCase();

        if (label == commonA) scoreA += 10;
        if (label == commonB) scoreB += 10;
        if (commonA.contains(label)) scoreA += 3;
        if (commonB.contains(label)) scoreB += 3;

        final scientificA = a.scientificName.toLowerCase();
        final scientificB = b.scientificName.toLowerCase();
        if (scientificA.contains(label)) scoreA += 5;
        if (scientificB.contains(label)) scoreB += 5;
      }

      return scoreB.compareTo(scoreA);
    });

    return matches.take(10).toList();
  }

  void _performManualSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a fish name to search')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
          _statusMessage = matches.isEmpty
              ? 'No fish found matching "$query"'
              : '';
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
    _imageLabeler.close();
    _searchController.dispose();
    super.dispose();
  }

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
                  if (_detectedLabels.isNotEmpty &&
                      !_isLoading &&
                      _imageFile != null)
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
                  if (_statusMessage.isNotEmpty &&
                      !_isLoading &&
                      _matchedFish.isEmpty)
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
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
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
                  'ML Kit will analyze the image offline',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            onPressed:
                _isLoading ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _isLoading ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
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
                'ML Kit Detected:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _detectedLabels.take(6).map((label) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.teal200),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppTheme.navy700),
                ),
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
          child: Text(
            'OR',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
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
              const Text(
                'Manual Search',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _performManualSearch(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _performManualSearch,
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
          Text('Analyzing image with ML Kit...'),
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
          padding: const EdgeInsets.all(12),
          onTap: () => _navigateToFishDetail(fish),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
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
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.set_meal,
                            color: AppTheme.teal200,
                            size: 30,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.set_meal,
                        color: AppTheme.teal200,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fish.commonName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fish.scientificName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.teal50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        fish.habitat,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.navy700,
                          fontWeight: FontWeight.w500,
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
          Text(
            _statusMessage,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
