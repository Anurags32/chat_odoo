import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/group_model.dart';
import '../../data/providers/groups_provider.dart';
import '../../../chat/domain/models/user_model.dart';
import '../../../users/data/providers/users_provider.dart';

class ViewMembersScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const ViewMembersScreen({super.key, required this.group});

  @override
  ConsumerState<ViewMembersScreen> createState() => _ViewMembersScreenState();
}

class _ViewMembersScreenState extends ConsumerState<ViewMembersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = ref.watch(usersProvider);
    final groups = ref.watch(groupsProvider);
    final currentGroup = groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );

    final members = allUsers.where((user) {
      return currentGroup.memberIds.contains(user.id) ||
          currentGroup.memberIds.contains('currentUser');
    }).toList();

    final filteredMembers = members.where((member) {
      return member.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Members'),
            Text(
              '${currentGroup.memberCount} members',
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              _showAddMemberDialog(currentGroup);
            },
            tooltip: 'Add Member',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100), // Space for transparent AppBar
            _buildSearchBar(),
            _buildGroupInfo(currentGroup),
            Expanded(child: _buildMembersList(filteredMembers, currentGroup)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search members...',
          prefixIcon: const Icon(Icons.search, color: AppColors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.offWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupInfo(GroupModel group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(group.avatar, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group.description,
                  style: const TextStyle(fontSize: 14, color: AppColors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(List<UserModel> members, GroupModel group) {
    if (members.isEmpty) {
      return const Center(
        child: Text(
          'No members found',
          style: TextStyle(color: AppColors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final delay = index * 50;
        final isAdmin = group.createdBy == member.id;

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                (delay / 1000).clamp(0.0, 1.0),
                ((delay + 300) / 1000).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: member.isOnline
                          ? AppColors.buttonGradient
                          : const LinearGradient(
                              colors: [AppColors.grey, AppColors.lightGrey],
                            ),
                      border: member.profilePicture != null
                          ? Border.all(
                              color: member.isOnline
                                  ? AppColors.purple1
                                  : AppColors.grey,
                              width: 2,
                            )
                          : null,
                    ),
                    child: member.profilePicture != null
                        ? ClipOval(
                            child: Image.network(
                              member.profilePicture!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    member.avatar,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: Text(
                                        member.avatar,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    );
                                  },
                            ),
                          )
                        : Center(
                            child: Text(
                              member.avatar,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                  ),
                  if (member.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purple1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    member.status,
                    style: const TextStyle(fontSize: 14, color: AppColors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: member.isOnline
                              ? AppColors.purple1
                              : AppColors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: !isAdmin
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.grey),
                      onSelected: (value) {
                        if (value == 'remove') {
                          _showRemoveMemberDialog(member, group);
                        } else if (value == 'message') {
                          // Navigate to personal chat
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Message ${member.name}'),
                              backgroundColor: AppColors.purple1,
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'message',
                          child: Row(
                            children: [
                              Icon(Icons.message, color: AppColors.purple1),
                              SizedBox(width: 12),
                              Text('Message'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: AppColors.error),
                              SizedBox(width: 12),
                              Text('Remove'),
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberDialog(GroupModel group) {
    final allUsers = ref.read(usersProvider);
    final currentMemberIds = group.memberIds;
    final availableUsers = allUsers.where((user) {
      return !currentMemberIds.contains(user.id);
    }).toList();

    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All users are already members of this group!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        availableUsers: availableUsers,
        onAddMembers: (selectedUserIds) {
          // Add members to group using the provider
          ref
              .read(groupsProvider.notifier)
              .addMembersToGroup(group.id, selectedUserIds);

          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${selectedUserIds.length} member${selectedUserIds.length > 1 ? 's' : ''} added successfully!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  void _showRemoveMemberDialog(UserModel member, GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Remove member from group using the provider
                  ref
                      .read(groupsProvider.notifier)
                      .removeMemberFromGroup(group.id, member.id);

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${member.name} removed from group'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final List<UserModel> availableUsers;
  final Function(List<String>) onAddMembers;

  const _AddMemberDialog({
    required this.availableUsers,
    required this.onAddMembers,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = widget.availableUsers.where((user) {
      return user.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildSelectionInfo(),
            const SizedBox(height: 16),
            Expanded(child: _buildUsersList(filteredUsers)),
            const SizedBox(height: 16),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: AppColors.buttonGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_add, color: AppColors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Add Members',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search users...',
        prefixIcon: const Icon(Icons.search, color: AppColors.grey),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.grey),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSelectionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple1.withValues(alpha: 0.1),
            AppColors.purple1.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.purple1, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedUserIds.length} user${_selectedUserIds.length != 1 ? 's' : ''} selected',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.purple1,
              ),
            ),
          ),
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedUserIds.clear();
                });
              },
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.purple1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<UserModel> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: AppColors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = _selectedUserIds.contains(user.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.purple1 : Colors.transparent,
              width: 2,
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedUserIds.add(user.id);
                } else {
                  _selectedUserIds.remove(user.id);
                }
              });
            },
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: user.isOnline
                        ? AppColors.buttonGradient
                        : const LinearGradient(
                            colors: [AppColors.grey, AppColors.lightGrey],
                          ),
                    border: user.profilePicture != null
                        ? Border.all(
                            color: user.isOnline
                                ? AppColors.purple1
                                : AppColors.grey,
                            width: 2,
                          )
                        : null,
                  ),
                  child: user.profilePicture != null
                      ? ClipOval(
                          child: Image.network(
                            user.profilePicture!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  user.avatar,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: Text(
                                  user.avatar,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            user.avatar,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            activeColor: AppColors.purple1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: _selectedUserIds.isEmpty
                ? null
                : AppColors.buttonGradient,
            color: _selectedUserIds.isEmpty
                ? AppColors.grey.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _selectedUserIds.isEmpty
                  ? null
                  : () {
                      widget.onAddMembers(_selectedUserIds.toList());
                    },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 20, color: AppColors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add ${_selectedUserIds.isEmpty ? '' : '(${_selectedUserIds.length})'}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
