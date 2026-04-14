import 'package:flutter/material.dart';
import 'map_screen.dart';

class FishDetailPage extends StatelessWidget {
  final Map<dynamic, dynamic> fish;

  const FishDetailPage({super.key, required this.fish});

  // ── IUCN status → color mapping ───────────────────────────────────────────
  static const Map<String, Color> _statusColors = {
    'Extinct (EX)':               Color(0xFF000000),
    'Extinct in the Wild (EW)':   Color(0xFF4A0080),
    'Critically Endangered (CR)': Color(0xFFCC0000),
    'Endangered (EN)':            Color(0xFFE65C00),
    'Vulnerable (VU)':            Color(0xFFE6A800),
    'Near Threatened (NT)':       Color(0xFF2E8B57),
    'Least Concern (LC)':         Color(0xFF006400),
    'Data Deficient (DD)':        Color(0xFF607D8B),
    'Not Evaluated (NE)':         Color(0xFF9E9E9E),
  };

  // Short abbreviation shown inside the badge dot overlay on the image
  static const Map<String, String> _statusAbbr = {
    'Extinct':              'EX',
    'Extinct in the Wild':  'EW',
    'Critically':           'CR',
    'Endangered':           'EN',
    'Vulnerable':           'VU',
    'Near':                 'NT',
    'Least':                'LC',
    'Data':                 'DD',
    'Not':                  'NE',
  };

  Color _statusColor(String? status) {
    if (status == null) return const Color(0xFF9E9E9E);
    for (final key in _statusColors.keys) {
      if (status.contains(key.split(' ').first)) return _statusColors[key]!;
    }
    return const Color(0xFF9E9E9E);
  }

  String _statusAbbreviation(String? status) {
    if (status == null) return 'NE';
    for (final key in _statusAbbr.keys) {
      if (status.contains(key)) return _statusAbbr[key]!;
    }
    return 'NE';
  }

  @override
  Widget build(BuildContext context) {
    final String? status = fish['conservationStatus']?.toString();
    final Color statusColor = _statusColor(status);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
            ),

            // ── Scrollable content ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish name
                    Center(
                      child: Text(
                        fish['commonName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Fish Image with status badge overlay ─────────────────
                    Stack(
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
                          child: (fish['imageUrl'] != null &&
                                  fish['imageUrl'].toString().isNotEmpty)
                              ? Image.asset(
                                  fish['imageUrl'],
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

                        // ── Conservation badge overlaid on image (top-right) ──
                        if (status != null)
                          Positioned(
                            top: 24,
                            right: 8,
                            child: _buildImageBadge(status, statusColor),
                          ),
                      ],
                    ),

                    // ── Inline status strip (below image, above tabs) ─────────
                    if (status != null) ...[
                      _buildStatusStrip(status, statusColor),
                      const SizedBox(height: 16),
                    ],

                    // Tabs
                    _buildTabSection(context),

                    const SizedBox(height: 24),

                    // Common Name
                    _buildInfoSection('Common Name', fish['commonName'] ?? 'Unknown'),

                    // Scientific Name
                    _buildInfoRow('Scientific Name', fish['scientificName'] ?? 'N/A'),

                    // Local Name
                    _buildInfoRow('Local Name', fish['localName'] ?? 'N/A'),

                    const SizedBox(height: 24),

                    // Size Range
                    _buildSectionHeader('Size Range'),
                    const SizedBox(height: 8),
                    Text(
                      fish['sizeRange'] ?? 'N/A',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),

                    const SizedBox(height: 24),

                    // Identifying Features
                    _buildSectionHeader('Identifying Features'),
                    const SizedBox(height: 8),
                    if (fish['identifyingFeatures'] != null)
                      ...List.from(fish['identifyingFeatures']).map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700])),
                              Expanded(
                                child: Text(
                                  feature.toString(),
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      Text(
                        'No identifying features listed',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),

                    const SizedBox(height: 24),

                    // Habitat
                    _buildSectionHeader('Habitat'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(fish['habitat'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.blue[50],
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Conservation Status (full detail card) ───────────────
                    _buildConservationStatusSection(),

                    // Distribution
                    if (fish['distribution'] != null) ...[
                      _buildSectionHeader('Distribution'),
                      const SizedBox(height: 8),
                      Text(
                        fish['distribution'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small pill badge overlaid on the fish image ────────────────────────────
  Widget _buildImageBadge(String status, Color color) {
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            abbr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Horizontal status strip between image and tabs ────────────────────────
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.45)),
            ),
            child: Text(
              'IUCN Red List',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full conservation detail card (bottom of scroll) ──────────────────────
  Widget _buildConservationStatusSection() {
    final String? status  = fish['conservationStatus']?.toString();
    final String? details = fish['conservationDetails']?.toString();
    final color           = _statusColor(status);
    final lightColor      = color.withOpacity(0.10);

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
              // Badge row
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status ?? 'Not Evaluated (NE)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Text(
                      'IUCN Red List',
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // ── IUCN threat scale ──────────────────────────────────────────
              const SizedBox(height: 12),
              _buildIucnScale(status),

              // Details
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: color.withOpacity(0.25), height: 1),
                const SizedBox(height: 10),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── IUCN threat-level scale bar ────────────────────────────────────────────
  Widget _buildIucnScale(String? currentStatus) {
    // Ordered from least to most severe (left → right)
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
        Text(
          'Threat Level',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: levels.map((entry) {
            final abbr  = entry.$1;
            final color = entry.$2;
            final isActive = abbr == currentAbbr;

            return Expanded(
              child: Column(
                children: [
                  // Colored segment
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isActive ? 10 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isActive ? color : color.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    abbr,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? color : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────
  Widget _buildTabSection(BuildContext context) {
    return Row(
      children: [
        _buildTab('Information', true, () {}),
        _buildTab('Map', false, () {
          final String? fishId = fish['fishId']?.toString();
          if (fishId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No fishId found for this fish')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapScreen(
                fishId: fishId,
                fishName: fish['commonName'] ?? 'Fish',
              ),
            ),
          );
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
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}