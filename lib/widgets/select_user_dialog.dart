import 'package:flutter/material.dart';
import 'package:hospital_app/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectUserDialog extends StatefulWidget {
  const SelectUserDialog({super.key});

  @override
  _SelectUserDialogState createState() => _SelectUserDialogState();
}

class _SelectUserDialogState extends State<SelectUserDialog> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('userId'); // Use hospital_id, not user_id

    if (userId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hospital ID not found')));
      return;
    }

    try {
      final response = await _chatService.getUsersWithSameHospitalId(userId);
      final List users = response.data['data'] ?? [];

      setState(() {
        _users = List<Map<String, dynamic>>.from(users);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select a user to chat'),
      content:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(
                width: double.maxFinite,
                height: 300,
                child:
                    _users.isEmpty
                        ? const Center(child: Text('No users found'))
                        : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  'https://randomuser.me/api/portraits/men/32.jpg',
                                ),
                              ),
                              title: Text(user['name']),
                              onTap:
                                  () => Navigator.of(
                                    context,
                                  ).pop(user['id'].toString()),
                            );
                          },
                        ),
              ),
    );
  }
}
