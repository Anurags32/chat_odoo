import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/models/group_model.dart';
import '../../../chat/domain/models/channel_model.dart';

class GroupApiService {
  final DioClient _dioClient = DioClient.instance;

  // Get All Groups
  Future<ApiResponse<GetAllGroupsResponse>> getAllGroups() async {
    try {
      final response = await _dioClient.get(
        ApiConstants.getAllGroups,
      );

      if (response.statusCode == 200) {
        final groupsResponse = GetAllGroupsResponse.fromJson(response.data);

        return ApiResponse.success(
          groupsResponse,
          message: 'Groups fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch groups',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Create Group
  Future<ApiResponse<CreateGroupResponse>> createGroup({
    required String groupName,
    required List<int> partnerIds,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.createGroup,
        data: {
          'group_name': groupName,
          'partner_ids': partnerIds,
        },
      );

      if (response.statusCode == 200) {
        final createGroupResponse = CreateGroupResponse.fromJson(response.data);

        return ApiResponse.success(
          createGroupResponse,
          message: 'Group created successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to create group',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Send Group Message
  Future<ApiResponse<SendGroupMessageResponse>> sendGroupMessage({
    required int channelId,
    required String body,
    List<MessageAttachment>? attachments,
  }) async {
    try {
      final data = {
        'channel_id': channelId,
        'body': body,
      };

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        data['attachments'] = attachments.map((a) => a.toJson()).toList();
      }

      final response = await _dioClient.post(
        ApiConstants.sendGroupMessage,
        data: data,
      );

      if (response.statusCode == 200) {
        final sendMessageResponse = SendGroupMessageResponse.fromJson(response.data);

        return ApiResponse.success(
          sendMessageResponse,
          message: 'Message sent successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to send message',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Get Group Messages
  Future<ApiResponse<GetGroupMessagesResponse>> getGroupMessages({
    required int channelId,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.getGroupMessages,
        data: {
          'channel_id': channelId,
        },
      );

      if (response.statusCode == 200) {
        final messagesResponse = GetGroupMessagesResponse.fromJson(response.data);

        return ApiResponse.success(
          messagesResponse,
          message: 'Messages fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch messages',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Leave Group
  Future<ApiResponse<LeaveGroupResponse>> leaveGroup({
    required int channelId,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.leaveGroup,
        data: {
          'channel_id': channelId,
        },
      );

      if (response.statusCode == 200) {
        final leaveResponse = LeaveGroupResponse.fromJson(response.data);

        return ApiResponse.success(
          leaveResponse,
          message: leaveResponse.message,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to leave group',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }
}
