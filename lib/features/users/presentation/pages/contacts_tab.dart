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
import '../../../call/data/models/call_model.dart';
import '../../../call/data/providers/call_provider.dart';

class ContactsTab extends ConsumerStatefulWidget {
  const ContactsTab({super.key});

  @override
  ConsumerState<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends ConsumerState<ContactsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(usersApiProvider.notifier).fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initiateCall(ApiUserModel user, CallType type) {
    ref.read(callManagerProvider.notifier).startCall(
          calleePartnerId: user.partnerId,
          calleeName: user.name,
          callType: type,
        );
    if (type == CallType.video) {
      context.push('/video-call', extra: {'callee_name': user.name, 'partner_id': user.partnerId});
    } else {
      context.push('/audio-call', extra: {'callee_name': user.name, 'partner_id': user.partnerId});
    }
  }

  void _openChat(ApiUserModel user) {
    context.push('/chat', extra: user);
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersApiProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredUsers = usersState.users.where((user) {
      final query = _searchQuery.toLowerCase();
      final nameMatches = user.name.toLowerCase().contains(query);
      final emailMatches = (user.email ?? '').toLowerCase().contains(query);
      return nameMatches || emailMatches;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(usersApiProvider.notifier).fetchUsers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search contacts by name or email...',
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

          // Count & Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredUsers.length} ${filteredUsers.length == 1 ? 'Contact' : 'Contacts'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.online,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${filteredUsers.where((u) => u.isOnline).length} Online',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.online,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Contact List
          Expanded(
            child: usersState.isLoading && usersState.users.isEmpty
                ? const ChatListSkeleton()
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(usersApiProvider.notifier).fetchUsers();
                    },
                    child: filteredUsers.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.people_outline_rounded,
                            title: _searchQuery.isEmpty ? 'No Contacts Found' : 'No Results',
                            subtitle: _searchQuery.isEmpty
                                ? 'No users are currently available on this Odoo database.'
                                : 'Try searching with a different name or email address.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return _buildContactCard(user, isDark);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(ApiUserModel user, bool isDark) {
    String subtitleText;
    if (user.isOnline) {
      subtitleText = 'Online now';
    } else if (user.lastMessageDate != null) {
      subtitleText = 'Active ${DateFormat('MMM d, h:mm a').format(user.lastMessageDate!)}';
    } else {
      subtitleText = user.email ?? 'Offline';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openChat(user),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                UserAvatarWidget(
                  user: user,
                  radius: 24,
                  showOnlineIndicator: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: user.isOnline ? FontWeight.w600 : FontWeight.normal,
                          color: user.isOnline
                              ? AppColors.online
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio Call Button
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      color: AppColors.primary,
                      tooltip: 'Audio Call',
                      onPressed: () => _initiateCall(user, CallType.audio),
                    ),
                    // Video Call Button
                    IconButton(
                      icon: const Icon(Icons.videocam_outlined, size: 22),
                      color: AppColors.accentTeal,
                      tooltip: 'Video Call',
                      onPressed: () => _initiateCall(user, CallType.video),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
