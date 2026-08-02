/// The authenticated user of the zova app.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarEmoji = '🚀',
    this.learnedLanguage = 'English',
    this.nativeLanguage = 'Persian',
    this.level = 'beginner',
  });

  final String id;
  final String email;
  final String? displayName;
  final String avatarEmoji;
  final String learnedLanguage;
  final String nativeLanguage;
  final String level;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarEmoji,
    String? learnedLanguage,
    String? nativeLanguage,
    String? level,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      learnedLanguage: learnedLanguage ?? this.learnedLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      level: level ?? this.level,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarEmoji: (json['avatar_emoji'] as String?) ?? '🚀',
      learnedLanguage: (json['learned_language'] as String?) ?? 'English',
      nativeLanguage: (json['native_language'] as String?) ?? 'Persian',
      level: (json['level'] as String?) ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_emoji': avatarEmoji,
      'learned_language': learnedLanguage,
      'native_language': nativeLanguage,
      'level': level,
    };
  }
}
