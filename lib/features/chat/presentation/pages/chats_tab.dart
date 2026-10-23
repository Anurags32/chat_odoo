import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/data/providers/auth_api_provider.dart';
import '../../../auth/domain/models/api_user_model.dart';
import '../../../groups/data/providers/group_api_provider.dart';
import '../../../groups/domain/models/group_model.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';

class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({super.key});

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Direct, 2: Groups

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(usersApiProvider.notifier).fetchUsers();
      ref.read(groupApiProvider.notifier).fetchAllGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openUserChat(ApiUserModel user) {
    context.push('/chat', extra: user);
  }

  void _openGroupChat(GroupModel group) {
    context.push('/group-chat', extra: group);
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }

  void _showNewChatDialog(List<ApiUserModel> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'New Direct Conversation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return ListTile(
                        leading: UserAvatarWidget(user: u, radius: 20),
                        title: Text(
                          u.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          u.isOnline ? 'Online now' : (u.email ?? 'Offline'),
                          style: TextStyle(
                            color: u.isOnline
                                ? AppColors.online
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openUserChat(u);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersApiProvider);
    final groupState = ref.watch(groupApiProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final users = usersState.users;
    final groups = groupState.groups;

    final filteredUsers = users.where((u) {
      final q = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q);
    }).toList();

    final filteredGroups = groups.where((g) {
      return g.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final bool showDirect = _selectedFilterIndex == 0 || _selectedFilterIndex == 1;
    final bool showGroups = _selectedFilterIndex == 0 || _selectedFilterIndex == 2;

    final bool isLoading = usersState.isLoading && groupState.isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Create Group',
            onPressed: _showCreateGroupDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chats_tab_fab',
        onPressed: () => _showNewChatDialog(users),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search chats, groups, or messages...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Filter Chips (All, Direct, Groups)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip(0, 'All', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Direct (${filteredUsers.length})', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Groups (${filteredGroups.length})', isDark),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Conversations List
          Expanded(
            child: isLoading && users.isEmpty && groups.isEmpty
                ? const ChatListSkeleton()
                : RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        ref.read(usersApiProvider.notifier).fetchUsers(),
                        ref.read(groupApiProvider.notifier).fetchAllGroups(),
                      ]);
                    },
                    child: (showDirect && filteredUsers.isNotEmpty) ||
                            (showGroups && filteredGroups.isNotEmpty)
                        ? ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              // Group Conversations
                              if (showGroups && filteredGroups.isNotEmpty) ...[
                                if (_selectedFilterIndex == 0)
                                  _buildSectionLabel('GROUPS', isDark),
                                ...filteredGroups.map(
                                  (g) => _buildGroupTile(g, isDark),
                                ),
                                if (_selectedFilterIndex == 0)
                                  const SizedBox(height: 16),
                              ],

                              // Direct Conversations
                              if (showDirect && filteredUsers.isNotEmpty) ...[
                                if (_selectedFilterIndex == 0)
                                  _buildSectionLabel('DIRECT MESSAGES', isDark),
                                ...filteredUsers.map(
                                  (u) => _buildDirectChatTile(u, isDark),
                                ),
                              ],
                              const SizedBox(height: 80), // Padding for FAB
                            ],
                          )
                        : EmptyStateWidget(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No Conversations Yet',
                            subtitle:
                                'Start a one-to-one conversation with a contact or create a group to begin chatting.',
                            buttonText: 'New Chat',
                            onButtonPressed: () => _showNewChatDialog(users),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, bool isDark) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildGroupTile(GroupModel group, bool isDark) {
    final lastMessage = group.lastMessage ?? 'No messages yet';
    final lastDate = group.lastMessageTime != null
        ? DateFormat('h:mm a').format(group.lastMessageTime!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: ListTile(
        onTap: () => _openGroupChat(group),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.group_rounded, color: Colors.white, size: 24),
          ),
        ),
        title: Text(
          group.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastDate.isNotEmpty)
              Text(
                lastDate,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            if (group.unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${group.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDirectChatTile(ApiUserModel user, bool isDark) {
    final lastDate = user.lastMessageDate != null
        ? DateFormat('MMM d, h:mm a').format(user.lastMessageDate!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: ListTile(
        onTap: () => _openUserChat(user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: UserAvatarWidget(user: user, radius: 24),
        title: Text(
          user.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          user.isOnline ? 'Online now' : (user.email ?? 'Offline'),
          style: TextStyle(
            fontSize: 13,
            color: user.isOnline
                ? AppColors.online
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: lastDate.isNotEmpty
            ? Text(
                lastDate,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 12),
      ),
    ),
  );
}
}
