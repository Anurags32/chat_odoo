import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/group_api_service.dart';
import '../../domain/models/group_model.dart';

final groupApiServiceProvider = Provider<GroupApiService>((ref) {
  return GroupApiService();
});

// Group State
class GroupState {
  final List<GroupModel> groups;
  final bool isLoading;
  final bool isCreating;
  final String? error;

  GroupState({
    this.groups = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.error,
  });

  GroupState copyWith({
    List<GroupModel>? groups,
    bool? isLoading,
    bool? isCreating,
    String? error,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: error,
    );
  }
}

// Group Messages State
class GroupMessagesState {
  final List<GroupMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final int? currentGroupId;

  GroupMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.currentGroupId,
  });

  GroupMessagesState copyWith({
    List<GroupMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    int? currentGroupId,
  }) {
    return GroupMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      currentGroupId: currentGroupId ?? this.currentGroupId,
    );
  }
}

// Group Notifier
class GroupNotifier extends StateNotifier<GroupState> {
  final GroupApiService _groupApiService;

  GroupNotifier(this._groupApiService) : super(GroupState());

  Future<GroupModel?> createGroup({
    required String groupName,
    required List<int> partnerIds,
  }) async {
    state = state.copyWith(isCreating: true, error: null);

    final response = await _groupApiService.createGroup(
      groupName: groupName,
      partnerIds: partnerIds,
    );

    if (response.success && response.data != null) {
      final newGroup = response.data!.group;
      state = state.copyWith(
        groups: [...state.groups, newGroup],
        isCreating: false,
      );
      return newGroup;
    } else {
      state = state.copyWith(
        isCreating: false,
        error: response.message,
      );
      return null;
    }
  }

  void addGroup(GroupModel group) {
    state = state.copyWith(
      groups: [...state.groups, group],
    );
  }

  void updateGroup(GroupModel updatedGroup) {
    state = state.copyWith(
      groups: state.groups.map((group) {
        return group.channelId == updatedGroup.channelId ? updatedGroup : group;
      }).toList(),
    );
  }
}

// Group Messages Notifier
class GroupMessagesNotifier extends StateNotifier<GroupMessagesState> {
  final GroupApiService _groupApiService;

  GroupMessagesNotifier(this._groupApiService) : super(GroupMessagesState());

  Future<void> loadMessages(int channelId) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentGroupId: channelId,
    );

    final response = await _groupApiService.getGroupMessages(
      channelId: channelId,
    );

    if (response.success && response.data != null) {
      state = state.copyWith(
        messages: response.data!.messages,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.message,
      );
    }
  }

  Future<bool> sendMessage({
    required int channelId,
    required String body,
  }) async {
    state = state.copyWith(isSending: true, error: null);

    final response = await _groupApiService.sendGroupMessage(
      channelId: channelId,
      body: body,
    );

    if (response.success) {
      // Reload messages to get the new message
      await loadMessages(channelId);
      state = state.copyWith(isSending: false);
      return true;
    } else {
      state = state.copyWith(
        isSending: false,
        error: response.message,
      );
      return false;
    }
  }

  void clearMessages() {
    state = GroupMessagesState();
  }
}

// Providers
final groupApiProvider = StateNotifierProvider<GroupNotifier, GroupState>((ref) {
  final groupApiService = ref.watch(groupApiServiceProvider);
  return GroupNotifier(groupApiService);
});

final groupMessagesProvider = StateNotifierProvider<GroupMessagesNotifier, GroupMessagesState>((ref) {
  final groupApiService = ref.watch(groupApiServiceProvider);
  return GroupMessagesNotifier(groupApiService);
});
