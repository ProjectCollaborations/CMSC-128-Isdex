import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/fish_detail_viewmodel.dart';
import '../../models/fish.dart';
import '../../core/constants/app_theme.dart';
import '../../services/iucn_service.dart';

class FishDetailScreen extends StatefulWidget {
  final String fishId;

  const FishDetailScreen({super.key, required this.fishId});

  @override
  State<FishDetailScreen> createState() => _FishDetailScreenState();
}

class _FishDetailScreenState extends State<FishDetailScreen> {
  IucnResult? _iucnData;
  bool _iucnLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FishDetailViewModel>().loadFish(widget.fishId);
    });
  }

  Future<void> _loadIucnStatus(String scientificName) async {
    if (scientificName.isEmpty) {
      if (mounted) setState(() => _iucnLoading = false);
      return;
    }
    final result = await IucnService.getStatus(scientificName);
    if (mounted) {
      setState(() {
        _iucnData = result;
        _iucnLoading = false;
      });
    }
  }

  String? get _status {
    if (_iucnData != null && _iucnData != IucnResult.unknown) {
      return _iucnData!.conservationStatus;
    }
    final vm = context.read<FishDetailViewModel>();
    return vm.fish?.conservationStatus;
  }

  Color _statusColor(String? status) {
    if (status == null) return const Color(0xFF9E9E9E);
    final colors = AppTheme.statusColors;
    for (final key in colors.keys) {
      if (status.contains(key.split(' ').first)) return colors[key]!;
    }
    return const Color(0xFF9E9E9E);
  }

  static const Map<String, String> _statusAbbr = {
    'Extinct in': 'EW',
    'Extinct': 'EX',
    'Critically': 'CR',
    'Endangered': 'EN',
    'Vulnerable': 'VU',
    'Near': 'NT',
    'Least': 'LC',
    'Data': 'DD',
    'Not': 'NE',
  };

  String _statusAbbreviation(String? status) {
    if (status == null) return 'NE';
    for (final key in _statusAbbr.keys) {
      if (status.contains(key)) return _statusAbbr[key]!;
    }
    return 'NE';
  }

  IconData _trendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'decreasing':
        return Icons.trending_down;
      case 'increasing':
        return Icons.trending_up;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FishDetailViewModel>();

    if (vm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (vm.error != null || vm.fish == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(vm.error ?? 'Fish not found')),
      );
    }

    final fish = vm.fish!;

    if (_iucnLoading && _iucnData == null) {
      _loadIucnStatus(fish.scientificName);
    }

    final Color statusColor = _statusColor(_status);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildContent(fish, statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.blue),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue[50],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Fish Information Page',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Fish fish, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            fish.commonName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        _buildImageSection(fish, statusColor),
        const SizedBox(height: 16),
        if (_iucnLoading)
          _buildLoadingStrip()
        else if (_status != null)
          _buildStatusStrip(_status!, statusColor),
        const SizedBox(height: 16),
        _buildTabSection(fish, statusColor),
        const SizedBox(height: 24),
        _buildInfoCard('Common Name', fish.commonName),
        _buildInfoRow('Scientific Name', fish.scientificName),
        _buildInfoRow('Local Name', fish.localName),
        const SizedBox(height: 24),
        _buildSectionHeader('Size Range'),
        const SizedBox(height: 8),
        Text(
          fish.sizeRange,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Identifying Features'),
        const SizedBox(height: 8),
        if (fish.identifyingFeatures.isNotEmpty)
          ...fish.identifyingFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[700])),
                    Expanded(
                      child: Text(feature,
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ),
                  ],
                ),
              ))
        else
          Text('No identifying features listed',
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(height: 24),
        _buildSectionHeader('Habitat'),
        const SizedBox(height: 8),
        Chip(
          label: Text(fish.habitat, style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.blue[50],
          side: const BorderSide(color: Colors.blue),
        ),
        const SizedBox(height: 24),
        _buildConservationStatusSection(fish, statusColor),
        if (fish.distribution.isNotEmpty) ...[
          _buildSectionHeader('Distribution'),
          const SizedBox(height: 8),
          Text(fish.distribution,
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildImageSection(Fish fish, Color statusColor) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: fish.imageUrl.isNotEmpty
              ? Image.asset(
                  fish.imageUrl,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_outlined,
                          size: 100, color: Colors.grey),
                    );
                  },
                )
              : const Center(
                  child: Icon(Icons.image_outlined,
                      size: 100, color: Colors.grey),
                ),
        ),
        Positioned(
          top: 24,
          right: 8,
          child: _iucnLoading
              ? _buildLoadingBadge()
              : _buildImageBadge(_status, statusColor),
        ),
      ],
    );
  }

  Widget _buildLoadingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Colors.white),
          ),
          SizedBox(width: 5),
          Text('...', style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLoadingStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
          const SizedBox(width: 10),
          Text('Loading conservation status\u2026',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildImageBadge(String? status, Color color) {
    final abbr = _statusAbbreviation(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(abbr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(String status, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.45)),
            ),
            child: Text('IUCN Red List',
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(Fish fish, Color statusColor) {
    return Row(
      children: [
        _buildTab('Information', true, () {}),
        _buildTab('Map', false, () {
          context.push('/map', extra: {
            'fishName': fish.commonName,
            'fishId': fish.id,
          });
        }),
      ],
    );
  }

  Widget _buildTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            )),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildConservationStatusSection(Fish fish, Color color) {
    if (_iucnLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Conservation Status'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    final lightColor = color.withOpacity(0.10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Conservation Status'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: lightColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      _status ?? 'Not Evaluated (NE)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text('IUCN Red List',
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              _buildIucnScale(_status),
              if (_iucnData?.populationTrend != null) ...[
                const SizedBox(height: 10),
                Divider(color: color.withOpacity(0.25), height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(_trendIcon(_iucnData!.populationTrend!),
                      size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                      'Population trend: ${_iucnData!.populationTrend}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                ]),
              ],
              if (fish.conservationDetails.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: color.withOpacity(0.25), height: 1),
                const SizedBox(height: 10),
                Text(fish.conservationDetails,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5)),
              ],
              if (_iucnData?.iucnUrl != null) ...[
                const SizedBox(height: 10),
                Text(
                    'Source: IUCN Red List  \u2022  ${_iucnData!.iucnUrl}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[400])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIucnScale(String? currentStatus) {
    final levels = [
      ('LC', const Color(0xFF006400)),
      ('NT', const Color(0xFF2E8B57)),
      ('VU', const Color(0xFFE6A800)),
      ('EN', const Color(0xFFE65C00)),
      ('CR', const Color(0xFFCC0000)),
      ('EW', const Color(0xFF4A0080)),
      ('EX', const Color(0xFF000000)),
    ];
    final currentAbbr = _statusAbbreviation(currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threat Level',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: levels.map((entry) {
            final abbr = entry.$1;
            final levelColor = entry.$2;
            final isActive = abbr == currentAbbr;
            return Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isActive ? 10 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? levelColor
                          : levelColor.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(abbr,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? levelColor
                            : Colors.grey[400],
                      )),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
