import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/group_model.dart';

class GroupsNotifier extends StateNotifier<List<GroupModel>> {
  GroupsNotifier() : super([]) {
    loadGroups();
  }

  void loadGroups() {
    state = _getDummyGroups();
  }

  void createGroup(GroupModel group) {
    state = [...state, group];
  }

  void deleteGroup(String groupId) {
    state = state.where((group) => group.id != groupId).toList();
  }

  void updateGroup(GroupModel updatedGroup) {
    state = state.map((group) {
      return group.id == updatedGroup.id ? updatedGroup : group;
    }).toList();
  }

  void addMemberToGroup(String groupId, String userId) {
    state = state.map((group) {
      if (group.id == groupId) {
        final updatedMembers = [...group.memberIds, userId];
        return GroupModel(
          id: group.id,
          name: group.name,
          description: group.description,
          avatar: group.avatar,
          memberIds: updatedMembers,
          createdBy: group.createdBy,
          createdAt: group.createdAt,
          lastMessage: group.lastMessage,
          lastMessageTime: group.lastMessageTime,
        );
      }
      return group;
    }).toList();
  }

  void addMembersToGroup(String groupId, List<String> userIds) {
    state = state.map((group) {
      if (group.id == groupId) {
        final updatedMembers = [...group.memberIds, ...userIds];
        return GroupModel(
          id: group.id,
          name: group.name,
          description: group.description,
          avatar: group.avatar,
          memberIds: updatedMembers,
          createdBy: group.createdBy,
          createdAt: group.createdAt,
          lastMessage: group.lastMessage,
          lastMessageTime: group.lastMessageTime,
        );
      }
      return group;
    }).toList();
  }

  void removeMemberFromGroup(String groupId, String userId) {
    state = state.map((group) {
      if (group.id == groupId) {
        final updatedMembers = group.memberIds
            .where((id) => id != userId)
            .toList();
        return GroupModel(
          id: group.id,
          name: group.name,
          description: group.description,
          avatar: group.avatar,
          memberIds: updatedMembers,
          createdBy: group.createdBy,
          createdAt: group.createdAt,
          lastMessage: group.lastMessage,
          lastMessageTime: group.lastMessageTime,
        );
      }
      return group;
    }).toList();
  }

  List<GroupModel> _getDummyGroups() {
    return [
      GroupModel(
        id: 'g1',
        name: 'Flutter Developers',
        description: 'Discussion about Flutter development',
        avatar: '💻',
        memberIds: ['1', '2', '3', '5'],
        createdBy: '1',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastMessage: 'Anyone working on animations?',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      GroupModel(
        id: 'g2',
        name: 'Project Team',
        description: 'Main project discussion group',
        avatar: '🚀',
        memberIds: ['1', '2', '4', '6', '7'],
        createdBy: '2',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastMessage: 'Meeting at 3 PM today',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      GroupModel(
        id: 'g3',
        name: 'Design Team',
        description: 'UI/UX discussions',
        avatar: '🎨',
        memberIds: ['2', '4', '8'],
        createdBy: '4',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        lastMessage: 'New mockups are ready',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      GroupModel(
        id: 'g4',
        name: 'Weekend Plans',
        description: 'Fun and casual chats',
        avatar: '🎉',
        memberIds: ['1', '3', '5', '7', '8'],
        createdBy: '5',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastMessage: 'Who is up for a movie?',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }
}

final groupsProvider = StateNotifierProvider<GroupsNotifier, List<GroupModel>>(
  (ref) => GroupsNotifier(),
);
