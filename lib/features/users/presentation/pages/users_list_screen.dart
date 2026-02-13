import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../chat/domain/models/user_model.dart';
import '../../data/providers/users_provider.dart';
import '../widgets/user_card.dart';
import '../../../groups/domain/models/group_model.dart';
import '../../../groups/data/providers/groups_provider.dart';
import '../../../groups/presentation/widgets/group_card.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUserOnline = true; // User's own online status

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
    final users = ref.watch(usersProvider);
    final filteredUsers = users.where((user) {
      return user.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Chats'),
        actions: [
          // Online/Offline Toggle
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: _isUserOnline
                  ? AppColors.buttonGradient
                  : LinearGradient(
                      colors: [AppColors.grey, AppColors.darkGrey],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isUserOnline ? AppColors.purple1 : AppColors.grey)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isUserOnline = !_isUserOnline;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isUserOnline
                          ? 'You are now Online'
                          : 'You are now Offline',
                    ),
                    backgroundColor: _isUserOnline
                        ? AppColors.success
                        : AppColors.grey,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.white.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUserOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100), // Space for transparent AppBar
            _buildStylishTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsersTab(users, filteredUsers),
                  _buildGroupsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylishTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple1.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.darkGrey,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(25),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Users'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Groups'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(List<UserModel> users, List<UserModel> filteredUsers) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildOnlineUsersSection(users),
        Expanded(child: _buildUsersList(filteredUsers)),
      ],
    );
  }

  Widget _buildGroupsTab() {
    final groups = ref.watch(groupsProvider);
    final filteredGroups = groups.where((group) {
      return group.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildGroupSearchBar(),
        Expanded(child: _buildGroupsList(filteredGroups)),
      ],
    );
  }

  Widget _buildGroupSearchBar() {
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
          hintText: 'Search groups...',
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

  Widget _buildGroupsList(List<GroupModel> groups) {
    if (groups.isEmpty) {
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
              child: const Icon(Icons.group, size: 60, color: AppColors.purple1),
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
              'Create a group to get started!',
              style: TextStyle(fontSize: 14, color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showCreateGroupDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: AppColors.white),
                        SizedBox(width: 8),
                        Text(
                          'Create Group',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
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
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80, left: 0, right: 0),
          itemCount: groups.length,
          itemBuilder: (context, index) {
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
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.3, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (delay / 1000).clamp(0.0, 1.0),
                          ((delay + 300) / 1000).clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                child: GroupCard(
                  group: groups[index],
                  onTap: () => _navigateToGroupChat(groups[index]),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple1.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _showCreateGroupDialog,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.add, color: AppColors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToGroupChat(GroupModel group) {
    context.push(AppRouter.groupChat, extra: group);
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(
        onCreateGroup: (name, description, avatar, memberIds) {
          final newGroup = GroupModel(
            id: 'g${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            description: description,
            avatar: avatar,
            memberIds: memberIds,
            createdBy: 'currentUser',
            createdAt: DateTime.now(),
          );
          ref.read(groupsProvider.notifier).createGroup(newGroup);
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Group "$name" created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
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
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineUsersSection(List<UserModel> users) {
    final onlineUsers = users.where((user) => user.isOnline).toList();

    if (onlineUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Online Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: onlineUsers.length,
              itemBuilder: (context, index) {
                final user = onlineUsers[index];
                return _buildOnlineUserAvatar(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineUserAvatar(UserModel user) {
    return GestureDetector(
      onTap: () => _navigateToChat(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.buttonGradient,
                  ),
                  child: Center(
                    child: Text(
                      user.avatar,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: AppColors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
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
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (delay / 1000).clamp(0.0, 1.0),
                      ((delay + 300) / 1000).clamp(0.0, 1.0),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
            child: UserCard(
              user: users[index],
              onTap: () => _navigateToChat(users[index]),
            ),
          ),
        );
      },
    );
  }

  void _navigateToChat(UserModel user) {
    context.push(AppRouter.chat, extra: user);
  }
}
