import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Username')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Manage Access')),
        ],
        rows: vm.users.map((user) {
          final isSelf = user.uid == currentUid;
          return DataRow(cells: [
            DataCell(Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _roleColor(user.role).withValues(alpha: 0.2),
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
                const SizedBox(width: 8),
                Text(user.username),
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
            )),
            DataCell(Text(user.email)),
            DataCell(_RoleChip(role: user.role)),
            DataCell(
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: user.role,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  items: ['user', 'mod', 'admin']
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: isSelf || vm.usersProcessing
                      ? null
                      : (v) {
                          if (v != null) {
                            vm.updateUserRole(user.uid, v);
                          }
                        },
                ),
              ),
            ),
          ]);
        }).toList(),
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
