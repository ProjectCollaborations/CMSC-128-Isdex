import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/admin_viewmodel.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    // Trigger user load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().refreshUsers();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final currentUserId = _authService.currentUser?.uid;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Text(
            'Total Registered Users: ${vm.users.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.users.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No users found.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                          columnSpacing: 24,
                          horizontalMargin: 12,
                          dividerThickness: 0.8,
                          columns: const [
                            DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Current Role', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Manage Access', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: vm.users.map((user) {
                            final isCurrentUser = user['uid'] == currentUserId;
                            
                            return DataRow(
                              cells: [
                                DataCell(Text(user['username'] ?? 'Unknown')),
                                DataCell(Text(user['email'] ?? 'No Email')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: user['role'] == 'admin'
                                          ? Colors.red[100]
                                          : (user['role'] == 'mod' ? Colors.orange[100] : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (user['role'] ?? 'user').toString().toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: user['role'] == 'admin'
                                            ? Colors.red[900]
                                            : (user['role'] == 'mod' ? Colors.orange[900] : Colors.grey[800]),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  isCurrentUser
                                      ? const Text('Cannot edit own role', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                                      : DropdownButton<String>(
                                          value: user['role'] ?? 'user',
                                          items: const [
                                            DropdownMenuItem(value: 'user', child: Text('Standard User')),
                                            DropdownMenuItem(value: 'mod', child: Text('Moderator')),
                                            DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                                          ],
                                          onChanged: (newRole) {
                                            if (newRole != null) {
                                              _confirmRoleChange(context, user['uid'], user['username'], newRole);
                                            }
                                          },
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
  
  Future<void> _confirmRoleChange(BuildContext context, String uid, String username, String newRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change User Role'),
        content: Text('Change role for "$username" to $newRole?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final vm = context.read<AdminViewModel>();
      await vm.updateUserRole(uid, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to $newRole!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}