import 'package:flutter/material.dart';
import '../../../auth/data/services/auth_api_service.dart';
import '../../../auth/domain/models/api_user_model.dart';
import '../../../../core/widgets/user_avatar_widget.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AuthApiService _authApiService = AuthApiService();
  List<ApiUserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _authApiService.getUsers();

    if (response.isSuccess && response.data != null) {
      setState(() {
        _users = response.data!.users;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: UserAvatarWidget(
            user: user,
            radius: 24,
          ),
          title: Text(user.name),
          subtitle: Text(user.email),
          trailing: _buildStatusChip(user.imStatus),
          onTap: () {
            // Handle user tap
            _showUserDetails(user);
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'online':
        color = Colors.green;
        label = 'Online';
        break;
      case 'away':
        color = Colors.orange;
        label = 'Away';
        break;
      case 'offline':
      default:
        color = Colors.grey;
        label = 'Offline';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _showUserDetails(ApiUserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: UserAvatarWidget(
                user: user,
                radius: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text('Email: ${user.email}'),
            Text('ID: ${user.id}'),
            Text('Partner ID: ${user.partnerId}'),
            Text('Status: ${user.imStatus}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
