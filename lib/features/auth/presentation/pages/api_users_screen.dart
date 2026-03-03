import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../data/providers/auth_api_provider.dart';
import '../../domain/models/api_user_model.dart';
import '../../../chat/presentation/pages/real_chat_screen.dart';
import '../../../groups/data/providers/group_api_provider.dart';
import '../../../groups/domain/models/group_model.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';

class ApiUsersScreen extends ConsumerStatefulWidget {
  const ApiUsersScreen({super.key});

  @override
  ConsumerState<ApiUsersScreen> createState() => _ApiUsersScreenState();
}

class _ApiUsersScreenState extends ConsumerState<ApiUsersScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabController = TabController(length: 2, vsync: this);
    _animationController.forward();

    // Reset search when tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchController.clear();
          _searchQuery = '';
        });
      }
    });

    // Fetch users on init
    Future.microtask(() {
      ref.read(usersApiProvider.notifier).fetchUsers();
      ref.read(groupApiProvider.notifier).fetchAllGroups();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersApiProvider);
    final authState = ref.watch(authProvider);

    // Listen to errors
    ref.listen<UsersState>(usersApiProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(usersApiProvider.notifier).clearError();
      }
    });

    final filteredUsers = usersState.users.where((user) {
      return user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(authState),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100),
            SizedBox(
              height:100,
              child:_buildTabBar(),
            ),
            
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsersTab(usersState, filteredUsers),
                  _buildGroupsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1 
          ? _buildCreateGroupButton() 
          : _buildRefreshButton(),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthState authState) {
    String capitalizeFirst(String text) {
  if (text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text('API Users'),
          if (authState.loginData != null)
         Text(
  capitalizeFirst(authState.loginData!.userName ?? ''),
),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(),
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.purple1,
        unselectedLabelColor: AppColors.white,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.person, size: 20),
            text: 'Users',
          ),
          Tab(
            icon: Icon(Icons.group, size: 20),
            text: 'Groups',
          ),
        ],
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
          hintText: _tabController.index == 0 ? 'Search users...' : 'Search groups...',
          prefixIcon: const Icon(Icons.search, color: AppColors.purple1),
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

  Widget _buildUserCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            '$count ${count == 1 ? 'User' : 'Users'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.purple1),
          SizedBox(height: 16),
          Text(
            'Loading users...',
            style: TextStyle(fontSize: 16, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.purple1.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 60,
              color: AppColors.purple1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search',
            style: TextStyle(fontSize: 14, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(UsersState usersState, List<ApiUserModel> filteredUsers) {
    if (usersState.isLoading) {
      return _buildLoadingState();
    }
    
    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildUserCount(filteredUsers.length),
        Expanded(child: _buildUsersList(filteredUsers)),
      ],
    );
  }

  Widget _buildGroupsTab() {
    final groupState = ref.watch(groupApiProvider);
    final groups = groupState.groups;
    final filteredGroups = groups.where((group) {
      return group.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (groupState.isLoading) {
      return _buildLoadingState();
    }

    if (filteredGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.purple1.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_off,
                size: 60,
                color: AppColors.purple1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No groups found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first group!',
              style: TextStyle(fontSize: 14, color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return _buildGroupsList(filteredGroups);
  }

  Widget _buildGroupsList(List<GroupModel> groups) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return InkWell(
      onTap: () {
        context.push(AppRouter.groupChat, extra: group);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppColors.buttonGradient,
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.buttonGradient,
                  ),
                  child: Center(
                    child: Text(
                      group.avatar ?? '👥',
                      style: const TextStyle(fontSize: 28),
                    ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.memberCount} members',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList(List<ApiUserModel> users) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final delay = index * 50;

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
          child: _buildUserCard(user),
        );
      },
    );
  }

  Widget _buildUserCard(ApiUserModel user) {
    return InkWell(
      onTap: () {
        // Navigate to real chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RealChatScreen(user: user),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppColors.buttonGradient,
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: user.isOnline
                        ? AppColors.buttonGradient
                        : const LinearGradient(
                            colors: [AppColors.grey, AppColors.lightGrey],
                          ),
                  ),
                  child: UserAvatarWidget(
                    user: user,
                    radius: 28,
                    showOnlineIndicator: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkGrey,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: user.isOnline
                                  ? AppColors.success
                                  : AppColors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.imStatus.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: AppColors.purple1,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Partner ID: ${user.partnerId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.purple1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purple1.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.purple1,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return FloatingActionButton(
      onPressed: () {
        if (_tabController.index == 0) {
          ref.read(usersApiProvider.notifier).fetchUsers();
        } else {
          ref.read(groupApiProvider.notifier).fetchAllGroups();
        }
      },
      backgroundColor: AppColors.purple1,
      child: const Icon(Icons.refresh, color: AppColors.white),
    );
  }

  Widget _buildCreateGroupButton() {
    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const CreateGroupDialog(),
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          gradient: AppColors.buttonGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: AppColors.white,
          size: 28,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: AppColors.buttonGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Logout', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Logout',
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
