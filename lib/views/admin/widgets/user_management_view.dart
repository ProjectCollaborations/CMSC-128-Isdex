import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../models/app_user.dart';

class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final currentUid = authVm.user?.uid;

    if (vm.usersProcessing && vm.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.users.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: vm.users.length,
      itemBuilder: (context, index) {
        final user = vm.users[index];
        final isSelf = user.uid == currentUid;
        return _UserCard(user: user, isSelf: isSelf);
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isSelf;

  const _UserCard({required this.user, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AdminViewModel>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _roleColor(user.role).withOpacity(0.2),
              child: Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _roleColor(user.role),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (isSelf)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Chip(
                            label: Text('You',
                                style: TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RoleChip(role: user.role),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: isSelf
                  ? const Text('(You)',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey))
                  : DropdownButtonFormField<String>(
                      value: user.role,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      items: ['user', 'mod', 'admin']
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: vm.usersProcessing
                          ? null
                          : (v) {
                              if (v != null) {
                                vm.updateUserRole(user.uid, v);
                              }
                            },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'admin' => Colors.red,
      'mod' => Colors.blue,
      _ => Colors.grey,
    };
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (role) {
      'admin' => (Colors.red[100]!, Colors.red[900]!),
      'mod' => (Colors.blue[100]!, Colors.blue[900]!),
      _ => (Colors.grey[100]!, Colors.grey[900]!),
    };
    return Chip(
      label: Text(role,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
