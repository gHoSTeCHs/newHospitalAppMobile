import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // Update with your Laravel API URL
  // final String baseUrl = 'http://127.0.0.1:8000/api';
  final String baseUrl = 'http://10.0.2.2:8000/api';

  // Store token in shared preferences
  Future<void> storeUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', user.token);
    await prefs.setInt('userId', user.id);
    await prefs.setString('userName', user.name);
    await prefs.setString('userEmail', user.email);
    await prefs.setString('hospitalCode', user.hospitalCode);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Get current user from preferences
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final id = prefs.getInt('userId');
    final name = prefs.getString('userName');
    final email = prefs.getString('userEmail');

    if (token != null && id != null && name != null && email != null) {
      return User(
        id: id,
        name: name,
        email: email,
        token: token,
        hospitalCode: '',
        isOnline: true,
      );
    }
    return null;
  }

  // Register user
  Future<User> register(
    String name,
    String email,
    String password,
    String hospitalCode,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'hospital_code': hospitalCode,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final userData = User.fromJson(jsonDecode(response.body));
      await storeUserData(userData);
      // print('Response structure: $userData');
      return userData;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Registration failed');
    }
  }

  // Login user
  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final userData = User.fromJson(jsonDecode(response.body));
      await storeUserData(userData);
      return userData;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Login failed');
    }
  }

  // Logout user
  Future<void> logout() async {
    final token = await getToken();

    if (token != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error logging out from server: $e');
        }
      }
    }

    // Clear local storage regardless of server response
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
