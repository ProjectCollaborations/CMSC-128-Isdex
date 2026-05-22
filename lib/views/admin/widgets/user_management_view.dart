import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/status_chip.dart';
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
            DataCell(StatusChip(label: user.role, color: _roleColor(user.role))),
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
      'admin' => AppTheme.error,
      'mod' => AppTheme.navy500,
      _ => AppTheme.textSecondary,
    };
  }
}

