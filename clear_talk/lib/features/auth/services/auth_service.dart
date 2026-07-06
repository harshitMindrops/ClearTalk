import 'package:clear_talk/data/auth/auth_api.dart';
import 'package:clear_talk/data/auth/token_storage.dart';

class AuthService {
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await AuthApi.login(email: email, password: password);
    final token = res['token'];
    if (token == null || token is! String) {
      throw Exception(res['message'] ?? 'Login failed');
    }

    final user = res['user'] as Map<String, dynamic>?;
    if (user == null) throw Exception('Login failed: no user data');

    await TokenStorage.saveToken(token);
    await TokenStorage.saveUserInfo(
      userId: user['id'].toString(),
      name: user['name'].toString(),
    );
  }

  static Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await AuthApi.signup(name: name, email: email, password: password);

    // Signup response bhi token + user return karta hai, toh seedha login karo
    final token = res['token'];
    if (token != null && token is String) {
      final user = res['user'] as Map<String, dynamic>?;
      if (user != null) {
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUserInfo(
          userId: user['id'].toString(),
          name: user['name'].toString(),
        );
      }
    }
  }
}
