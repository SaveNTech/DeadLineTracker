class AppUser {
  final String id;
  final String email;
  final String username;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        isActive: json['is_active'] as bool,
      );
}
