class UserComment {
  final String id;
  final String articleId;
  final String userId;
  final String nickname;
  final String nationality;
  final String fandom;
  String content;
  final DateTime createdAt;
  DateTime? editedAt;
  int likes;

  UserComment({
    required this.id,
    required this.articleId,
    this.userId = '',
    required this.nickname,
    this.nationality = '',
    this.fandom = '',
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.likes = 0,
  });

  bool get isEdited => editedAt != null;
}
