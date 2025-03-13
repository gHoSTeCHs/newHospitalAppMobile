import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

  Future<Response> getMessages(int conversationId) async {
    await _setAuthHeaders();

    try {
      Response response = await _dio.get('messages/$conversationId');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

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
      print('Error sending message: $e');
      return null;
    }
  }

  Future<List<Message>> gM(
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
      print('Error fetching messages: $e');
      return [];
    }
  }

  Future pasteMessages(
    String? type,
    int conversationId,
    List<File>? files,
    dynamic content,
    bool isAlert,
    bool isEmergency,
  ) async {
    await _setAuthHeaders();

    try {
      final response = await _dio.post(
        '/messages/$conversationId',
        data: {
          'message_type': type,
          "is_alert": isAlert,
          "is_emergency": isEmergency,
          "content": content,
        },
      );

      if (response.statusCode == 201) {
        return Message.fromJson(response.data['message']);
      }
      return null;
    } catch (e) {
      return e;
    }
  }

  Future sendFilesWithMessage(
    int conversationId,
    List<File> files,
    String content,
    bool isAlert,
    bool isEmergency,
  ) async {
    await _setAuthHeaders();

    try {
      final response = await _dio.post(
        '/messages/$conversationId',
        data: {
          'message_type': "file",
          "is_alert": isAlert,
          "is_emergency": isEmergency,
          "content": content,
          'file': await MultipartFile.fromFile(
            files[0].path,
            filename: files[0].path.split('/').last,
          ),
        },
      );
      if (response.statusCode == 201) {
        return Message.fromJson(response.data['message']);
      }
    } catch (e) {
      print('Error sending files: $e');
      return e;
    }
    return null;
  }
}
