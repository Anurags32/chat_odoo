import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/channel_model.dart';

class AttachmentService {
  AttachmentService._();
  static final AttachmentService instance = AttachmentService._();

  final ImagePicker _imagePicker = ImagePicker();

  /// Pick a single image from Gallery or Camera with automatic compression
  Future<MessageAttachment?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final filename = image.name.isNotEmpty
          ? image.name
          : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      return MessageAttachment(
        filename: filename,
        mimetype: 'image/jpeg',
        data: base64String,
        fileSize: bytes.length,
      );
    } catch (e) {
      debugPrint('[AttachmentService] pickImage error: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  Future<List<MessageAttachment>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (images.isEmpty) return [];

      final attachments = <MessageAttachment>[];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        final filename = img.name.isNotEmpty
            ? img.name
            : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

        attachments.add(
          MessageAttachment(
            filename: filename,
            mimetype: 'image/jpeg',
            data: base64Encode(bytes),
            fileSize: bytes.length,
          ),
        );
      }
      return attachments;
    } catch (e) {
      debugPrint('[AttachmentService] pickMultipleImages error: $e');
      return [];
    }
  }

  /// Pick a video from gallery
  Future<MessageAttachment?> pickVideo({required ImageSource source}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (video == null) return null;

      final bytes = await video.readAsBytes();
      final filename = video.name.isNotEmpty
          ? video.name
          : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      return MessageAttachment(
        filename: filename,
        mimetype: 'video/mp4',
        data: base64Encode(bytes),
        fileSize: bytes.length,
      );
    } catch (e) {
      debugPrint('[AttachmentService] pickVideo error: $e');
      return null;
    }
  }

  /// Pick arbitrary document (PDF, DOCX, XLSX, TXT, ZIP, etc.)
  Future<MessageAttachment?> pickDocument() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'zip',
          'csv',
        ],
      );
      if (file == null) return null;

      final Uint8List bytes = file.path != null
          ? await File(file.path!).readAsBytes()
          : await file.xFile.readAsBytes();

      final ext = file.extension?.toLowerCase() ?? 'bin';
      final mimetype = _resolveMimeType(ext);

      return MessageAttachment(
        filename: file.name,
        mimetype: mimetype,
        data: base64Encode(bytes),
        fileSize: bytes.length,
      );
    } catch (e) {
      debugPrint('[AttachmentService] pickDocument error: $e');
      return null;
    }
  }

  /// Download (if needed), save to cache, and open the attachment using OpenFilex
  Future<bool> openAttachment(MessageAttachment attachment) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cachePath = '${tempDir.path}/${attachment.filename}';
      final file = File(cachePath);

      if (!await file.exists()) {
        if (attachment.data != null && attachment.data!.isNotEmpty) {
          final cleanBase64 = attachment.data!.contains(',')
              ? attachment.data!.split(',').last
              : attachment.data!;
          final bytes = base64Decode(cleanBase64);
          await file.writeAsBytes(bytes);
        } else if (attachment.id != null && attachment.id! > 0) {
          final downloadUrl =
              '${ApiConstants.serverUrl}/web/content/${attachment.id}?download=true';
          final response = await DioClient.instance.dio.get<List<int>>(
            downloadUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null) {
            await file.writeAsBytes(response.data!);
          } else {
            return false;
          }
        } else if (attachment.url != null && attachment.url!.isNotEmpty) {
          final response = await DioClient.instance.dio.get<List<int>>(
            attachment.url!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null) {
            await file.writeAsBytes(response.data!);
          } else {
            return false;
          }
        } else {
          return false;
        }
      }

      final openResult = await OpenFilex.open(cachePath);
      return openResult.type == ResultType.done;
    } catch (e) {
      debugPrint('[AttachmentService] openAttachment error: $e');
      return false;
    }
  }

  String _resolveMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}

