class UserComment {
  final String id;
  final String articleId;
  final String nickname;
  final String content;
  final DateTime createdAt;
  int likes;

  UserComment({
    required this.id,
    required this.articleId,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.likes = 0,
  });
}
