import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  final String baseUrl = 'http://10.0.2.2:8000/api';
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

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return (await _getToken()) != null;
  }

  Future<Response> getUsersWithSameHospitalId(int? id) async {
    await _setAuthHeaders();
    try {
      Response response = await _dio.get('/users/$id');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<Response> getConversations() async {
    await _setAuthHeaders();
    try {
      Response response = await _dio.get('/conversations');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  Future<Response> createConversation(
    String type,
    List<int> participants, {
    String? name,
  }) async {
    await _setAuthHeaders();
    try {
      Response response = await _dio.post(
        '/conversations/create',
        data: {'type': type, 'name': name, 'participants': participants},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  Future<Response> getConversationDetails(int conversationId) async {
    await _setAuthHeaders();
    try {
      Response response = await _dio.get('/conversations/$conversationId');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch conversation details: $e');
    }
  }

  Future<Response> updateConversation(int conversationId, String name) async {
    try {
      await _setAuthHeaders();
      Response response = await _dio.put(
        '/conversations/$conversationId',
        data: {'name': name},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to update conversation: $e');
    }
  }

  Future<Response> deleteConversation(int conversationId) async {
    await _setAuthHeaders();
    try {
      Response response = await _dio.delete('/conversations/$conversationId');
      return response;
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }
}
