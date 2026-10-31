import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/models/channel_model.dart';

class ChatApiService {
  final DioClient _dioClient = DioClient.instance;

  // Create or Get Channel
  Future<ApiResponse<ChannelResponse>> createChannel({
    required int partnerId,
    int? channelId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'partner_id': partnerId,
        // Backend Odoo controller requires 'channel_id' key to be present;
        // if omitted, it defaults to '' and does ('id', 'in', ''.split(',')) -> [''] which breaks PostgreSQL.
        'channel_id': (channelId != null && channelId > 0) ? channelId : null,
      };

      final response = await _dioClient.post(
        ApiConstants.createChannel,
        data: payload,
      );

      if (response.statusCode == 200) {
        final channelResponse = ChannelResponse.fromJson(response.data);

        return ApiResponse.success(
          channelResponse,
          message: 'Channel created successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to create channel',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error']?.toString() ??
                e.response?.data['message']?.toString())
          : null;
      return ApiResponse.error(
        msg ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  // Send Message
  Future<ApiResponse<SendMessageResponse>> sendMessage({
    required int channelId,
    required String body,
    List<MessageAttachment>? attachments,
  }) async {
    try {
      final data = {'channel_id': channelId, 'body': body};

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        data['attachments'] = attachments.map((a) => a.toJson()).toList();
      }

      final response = await _dioClient.post(
        ApiConstants.sendMessage,
        data: data,
      );

      if (response.statusCode == 200) {
        final sendMessageResponse = SendMessageResponse.fromJson(response.data);

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
}
