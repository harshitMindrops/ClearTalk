import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  // Physical device testing: backend should be reachable on your LAN.
  // Example: http://192.168.1.50:3002
  // Physical device test ke liye: apni PC ki LAN IP use karo
  static const String baseUrl = 'http://192.168.1.50:3002';


  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');

    final res = await http.post(
      uri,
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _decode(res);

    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Login failed');
    }

    return data;
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/signup');

    final res = await http.post(
      uri,
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    final data = _decode(res);

    if (res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Signup failed');
    }

    return data;
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = res.body.trim();
      if (body.isEmpty) return {};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

