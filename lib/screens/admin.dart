// lib/screens/admin_panel.dart
//
// Admin Panel — Fish Sightings Moderation
//
// Firebase Realtime Database paths used:
//   user_sightings_temp/{id}   — pending / all user-submitted sightings
//   users/{uid}/role           — set to "admin" to grant admin access
//
// To grant admin access, set the user's role field in the RTDB:
//   users: { "USER_UID_HERE": { ..., "role": "admin" } }
//
// The screen guards itself — non-admins are shown an "Access Denied" view.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // add intl to pubspec.yaml if not present

// ──────────────────────────────────────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────────────────────────────────────

enum SightingStatus { pending, verified, rejected }

class SightingEntry {
  final String id;
  final String fishName;
  final String fishId;
  final String displayName;
  final String userId;
  final String notes;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final SightingStatus status;
  final bool isAnonymous;

  const SightingEntry({
    required this.id,
    required this.fishName,
    required this.fishId,
    required this.displayName,
    required this.userId,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
    required this.isAnonymous,
  });

  factory SightingEntry.fromSnapshot(String id, Map<dynamic, dynamic> data) {
    final rawStatus = data['status']?.toString() ?? 'pending';
    final status = SightingStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => SightingStatus.pending,
    );

    final rawTs = data['createdAt'];
    DateTime createdAt;
    if (rawTs is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      createdAt = DateTime.now();
    }

    return SightingEntry(
      id: id,
      fishName: data['fishName']?.toString() ?? 'Unknown',
      fishId: data['fishId']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? 'Anonymous',
      userId: data['userId']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      status: status,
      isAnonymous: data['isAnonymous'] == true,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────────────────────────────────────

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _checkingAdmin = true;
  bool _isAdmin = false;

  List<SightingEntry> _allSightings = [];
  bool _loadingSightings = true;

  late TabController _tabController;

  // Filter tab index → status
  static const _tabs = ['Pending', 'Verified', 'Rejected', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _verifyAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Admin gate ──────────────────────────────────────────────────────────────

  Future<void> _verifyAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _checkingAdmin = false; _isAdmin = false; });
      return;
    }

    final snap = await _db.child('users').child(user.uid).child('role').get();
    final granted = snap.exists && snap.value?.toString() == 'admin';

    setState(() { _checkingAdmin = false; _isAdmin = granted; });

    if (granted) _listenToSightings();
  }

  // ── Real-time listener ──────────────────────────────────────────────────────

  void _listenToSightings() {
    _db.child('user_sightings_temp').onValue.listen((event) {
      if (!mounted) return;

      final List<SightingEntry> entries = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            entries.add(
              SightingEntry.fromSnapshot(
                key.toString(),
                value as Map<dynamic, dynamic>,
              ),
            );
          }
        });

        // Newest first
        entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      setState(() {
        _allSightings = entries;
        _loadingSightings = false;
      });
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _updateStatus(SightingEntry entry, SightingStatus newStatus) async {
    await _db
        .child('user_sightings_temp')
        .child(entry.id)
        .update({'status': newStatus.name});
  }

  Future<void> _deleteSighting(SightingEntry entry) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Sighting',
      message:
          'Permanently delete the sighting for "${entry.fishName}" by ${entry.isAnonymous ? "Anonymous" : entry.displayName}?\n\nThis cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;

    await _db.child('user_sightings_temp').child(entry.id).remove();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sighting deleted.')),
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = Colors.blue,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<SightingEntry> _filtered(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _allSightings
            .where((s) => s.status == SightingStatus.pending)
            .toList();
      case 1:
        return _allSightings
            .where((s) => s.status == SightingStatus.verified)
            .toList();
      case 2:
        return _allSightings
            .where((s) => s.status == SightingStatus.rejected)
            .toList();
      default:
        return _allSightings;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) return _buildAccessDenied();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.tealAccent,
          tabs: _tabs.map((t) {
            final count = t == 'All'
                ? _allSightings.length
                : _allSightings
                    .where((s) =>
                        s.status.name.toLowerCase() == t.toLowerCase())
                    .length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t),
                  const SizedBox(width: 4),
                  _BadgeCount(count: count, tab: t),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _loadingSightings
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: List.generate(
                _tabs.length,
                (i) => _SightingsList(
                  sightings: _filtered(i),
                  onVerify: (s) => _updateStatus(s, SightingStatus.verified),
                  onReject: (s) => _updateStatus(s, SightingStatus.rejected),
                  onDelete: _deleteSighting,
                  onPending: (s) => _updateStatus(s, SightingStatus.pending),
                ),
              ),
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have admin privileges.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sightings list
// ──────────────────────────────────────────────────────────────────────────────

class _SightingsList extends StatelessWidget {
  final List<SightingEntry> sightings;
  final ValueChanged<SightingEntry> onVerify;
  final ValueChanged<SightingEntry> onReject;
  final ValueChanged<SightingEntry> onDelete;
  final ValueChanged<SightingEntry> onPending;

  const _SightingsList({
    required this.sightings,
    required this.onVerify,
    required this.onReject,
    required this.onDelete,
    required this.onPending,
  });

  @override
  Widget build(BuildContext context) {
    if (sightings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No sightings here.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sightings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _SightingCard(
        entry: sightings[i],
        onVerify: onVerify,
        onReject: onReject,
        onDelete: onDelete,
        onPending: onPending,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sighting card
// ──────────────────────────────────────────────────────────────────────────────

class _SightingCard extends StatelessWidget {
  final SightingEntry entry;
  final ValueChanged<SightingEntry> onVerify;
  final ValueChanged<SightingEntry> onReject;
  final ValueChanged<SightingEntry> onDelete;
  final ValueChanged<SightingEntry> onPending;

  const _SightingCard({
    required this.entry,
    required this.onVerify,
    required this.onReject,
    required this.onDelete,
    required this.onPending,
  });

  Color get _statusColor {
    switch (entry.status) {
      case SightingStatus.verified:
        return Colors.green;
      case SightingStatus.rejected:
        return Colors.red;
      case SightingStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy · h:mm a');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.fishName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: entry.status, color: _statusColor),
              ],
            ),

            const SizedBox(height: 6),

            // ── Submitter ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  entry.isAnonymous ? Icons.visibility_off : Icons.person_outline,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  entry.isAnonymous
                      ? 'Anonymous'
                      : entry.displayName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Spacer(),
                Text(
                  df.format(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Coordinates ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${entry.latitude.toStringAsFixed(5)}, '
                  '${entry.longitude.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            // ── Notes ────────────────────────────────────────────────────────
            if (entry.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${entry.notes}"',
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700]),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Action buttons ───────────────────────────────────────────────
            _ActionButtons(
              entry: entry,
              onVerify: onVerify,
              onReject: onReject,
              onDelete: onDelete,
              onPending: onPending,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Action buttons — shown contextually based on current status
// ──────────────────────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final SightingEntry entry;
  final ValueChanged<SightingEntry> onVerify;
  final ValueChanged<SightingEntry> onReject;
  final ValueChanged<SightingEntry> onDelete;
  final ValueChanged<SightingEntry> onPending;

  const _ActionButtons({
    required this.entry,
    required this.onVerify,
    required this.onReject,
    required this.onDelete,
    required this.onPending,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Verify — shown when not already verified
        if (entry.status != SightingStatus.verified)
          _ActionChip(
            label: 'Verify',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            onTap: () => onVerify(entry),
          ),

        // Reject — shown when not already rejected
        if (entry.status != SightingStatus.rejected)
          _ActionChip(
            label: 'Reject',
            icon: Icons.cancel_outlined,
            color: Colors.orange,
            onTap: () => onReject(entry),
          ),

        // Reset to pending — shown when already actioned
        if (entry.status != SightingStatus.pending)
          _ActionChip(
            label: 'Reset',
            icon: Icons.refresh,
            color: Colors.blueGrey,
            onTap: () => onPending(entry),
          ),

        // Delete — always available
        _ActionChip(
          label: 'Delete',
          icon: Icons.delete_outline,
          color: Colors.red,
          onTap: () => onDelete(entry),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ──────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final SightingStatus status;
  final Color color;

  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.name[0].toUpperCase() + status.name.substring(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.07),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  final int count;
  final String tab;

  const _BadgeCount({required this.count, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final isPending = tab == 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPending ? Colors.white : Colors.white,
        ),
      ),
    );
  }
}