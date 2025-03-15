import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/models/message.dart';
import 'package:hospital_app/models/message_response.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MessageService {
  final String baseUrl = 'http://10.0.2.2:8000/api';
  // final String baseUrl = 'http://127.0.0.1:8000/api';
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8000/api',
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Fetch the auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Add the token dynamically to each request
  Future<void> _setAuthHeaders() async {
    String? token = await _getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<bool> isLoggedIn() async {
    return (await _getToken()) != null;
  }

  // Future<Response> getMessages(int conversationId) async {
  //   await _setAuthHeaders();

  //   try {
  //     Response response = await _dio.get('messages/$conversationId');
  //     return response;
  //   } catch (e) {
  //     throw Exception('Failed to fetch messages: $e');
  //   }
  // }

  Future<Message?> sendMessage(
    int conversationId,
    String content, {
    List<String>? filePaths,
  }) async {
    try {
      Map<String, dynamic> body = {'content': content};

      final response = await _dio.post('/messages/$conversationId', data: body);

      if (response.statusCode == 201) {
        final data = json.decode(response.data);
        return Message.fromJson(data['message']);
      }
      return null;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  Future<List<Message>> getMessages(
    int conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await _setAuthHeaders();

    try {
      final response = await _dio.get(
        '/messages/$conversationId?limit=$limit&offset=$offset',
      );

      if (response.statusCode == 200) {
        // Use the MessagesResponse model to parse the response
        final messagesResponse = MessagesResponse.fromJson(response.data);
        return messagesResponse.messages;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  Future<Message?> pasteMessages(
    String? type,
    int conversationId,
    List<File>? files,
    dynamic content,
    bool isAlert,
    bool isEmergency,
  ) async {
    await _setAuthHeaders();

    String finalType = (files == null || files.isEmpty) ? 'text' : 'file';

    try {
      final response = await _dio.post(
        '/messages/$conversationId',
        data: {
          'message_type': finalType,
          'is_alert': isAlert,
          'is_emergency': isEmergency,
          'content': content ?? '',
        },
      );

      if (response.statusCode == 201) {
        return Message.fromJson(response.data['message']);
      }
      return null;
    } catch (e) {
      debugPrint("Error sending message: $e");
      return null;
    }
  }

  // Send message with file
  Future sendfile(
    List<PlatformFile> files,
    int conversationId,
    bool isAlert,
    bool isEmergency,
  ) async {
    await _setAuthHeaders();
    final formData = FormData();

    try {
      formData.fields.add(MapEntry('message_type', "file"));
      formData.fields.add(MapEntry('is_alert', isAlert.toString()));
      formData.fields.add(MapEntry('is_emergency', isEmergency.toString()));

      for (var file in files) {
        if (file.path != null) {
          formData.files.add(
            MapEntry(
              'file',
              await MultipartFile.fromFile(file.path!, filename: file.name),
            ),
          );
        }
      }

      final response = await _dio.post(
        '/messages/$conversationId',
        data: formData,
      );

      debugPrint('Upload response: ${response.data}');
    } catch (e) {
      debugPrint("Error sending message: $e");
      return null;
    }
  }

  // New send files
  Future<Message?> sendFiles(
    List<PlatformFile> files,
    int conversationId,
    String content,
    bool isAlert,
    bool isEmergency, {
    Function(String fileName, double progress)? onProgress,
  }) async {
    await _setAuthHeaders();
    final formData = FormData();

    try {
      formData.fields.add(MapEntry('message_type', "file"));
      formData.fields.add(MapEntry('is_alert', isAlert.toString()));
      formData.fields.add(MapEntry('is_emergency', isEmergency.toString()));
      formData.fields.add(MapEntry('content', content));

      for (var file in files) {
        if (file.path != null) {
          formData.files.add(
            MapEntry(
              'file',
              await MultipartFile.fromFile(file.path!, filename: file.name),
            ),
          );
        }
      }

      final response = await _dio.post(
        '/messages/$conversationId',
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null) {
            // Assuming equal progress for all files for simplicity
            for (var file in files) {
              onProgress(file.name, sent / total);
            }
          }
        },
      );

      if (response.statusCode == 201) {
        return Message.fromJson(response.data['message']);
      }
      return null;
    } catch (e) {
      debugPrint("Error sending files: $e");
      return null;
    }
  }
}
