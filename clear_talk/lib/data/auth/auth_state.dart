class AuthState {
  final String token;
  final String userId;
  final String email;
  final String name;

  const AuthState({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
  });

  factory AuthState.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    final user = json['user'] as Map<String, dynamic>;
    return AuthState(
      token: token,
      userId: user['id'].toString(),
      email: user['email'].toString(),
      name: user['name'].toString(),
    );
  }
}

