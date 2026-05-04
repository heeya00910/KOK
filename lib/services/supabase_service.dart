import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_article.dart';
import '../models/comment.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ── Articles ──

  Future<List<NewsArticle>> fetchArticles({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('articles')
        .select('*, top_reactions(*), source_links(*)')
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => _mapArticle(json)).toList();
  }

  NewsArticle _mapArticle(Map<String, dynamic> json) {
    final reactions = json['top_reactions'] is List
        ? (json['top_reactions'] as List)
        : <Map<String, dynamic>>[];

    final sources = json['source_links'] is List
        ? (json['source_links'] as List)
        : <Map<String, dynamic>>[];

    return NewsArticle(
      id: json['id'] ?? '',
      issueTitleEn: json['issue_title_en'] ?? '',
      issueTitleEs: json['issue_title_es'] ?? '',
      whatHappenedEn: json['what_happened_en'] ?? '',
      whatHappenedEs: json['what_happened_es'] ?? '',
      whyItMattersEn: json['why_it_matters_en'] ?? '',
      whyItMattersEs: json['why_it_matters_es'] ?? '',
      koreanReactionSummaryEn: json['korean_reaction_summary_en'] ?? '',
      koreanReactionSummaryEs: json['korean_reaction_summary_es'] ?? '',
      contextForFansEn: json['context_for_fans_en'] ?? '',
      contextForFansEs: json['context_for_fans_es'] ?? '',
      imageUrl: json['image_url'] ?? '',
      issueTags: List<String>.from(json['issue_tags'] ?? []),
      artistTags: List<String>.from(json['artist_tags'] ?? []),
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      sentiment: json['sentiment'] ?? 'neutral',
      reactionSampleSize: json['reaction_sample_size'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      topReactions: reactions
          .map((r) => TranslatedReaction(
                id: r['id'] ?? '',
                contentEn: r['content_en'] ?? '',
                contentEs: r['content_es'] ?? '',
                likes: r['likes'] ?? 0,
                source: r['source'] ?? '',
              ))
          .toList(),
      originalSources: sources
          .map((s) => SourceLink(
                title: s['title'] ?? '',
                url: s['url'] ?? '',
                type: s['type'] ?? 'article',
              ))
          .toList(),
    );
  }

  // ── User Comments ──

  Future<List<UserComment>> fetchComments(String articleId) async {
    final response = await _client
        .from('user_comments')
        .select()
        .eq('article_id', articleId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => UserComment(
              id: json['id'],
              articleId: json['article_id'],
              nickname: json['nickname'] ?? '',
              content: json['content'] ?? '',
              createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
              likes: json['likes'] ?? 0,
            ))
        .toList();
  }

  Future<void> addComment(String articleId, String nickname, String content) async {
    await _client.from('user_comments').insert({
      'article_id': articleId,
      'user_id': _userId,
      'nickname': nickname,
      'content': content,
    });
  }

  Future<void> likeComment(String commentId) async {
    await _client.rpc('increment_comment_likes', params: {'comment_id': commentId});
  }

  Future<List<UserComment>> fetchMyComments() async {
    if (_userId == null) return [];
    final response = await _client
        .from('user_comments')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => UserComment(
              id: json['id'],
              articleId: json['article_id'],
              nickname: json['nickname'] ?? '',
              content: json['content'] ?? '',
              createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
              likes: json['likes'] ?? 0,
            ))
        .toList();
  }

  // ── User Profile ──

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (_userId == null) return null;
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', _userId!)
        .maybeSingle();
    return response;
  }

  Future<void> upsertProfile({
    required String nickname,
    required String nationality,
    required List<String> favoriteTags,
  }) async {
    if (_userId == null) return;
    await _client.from('profiles').upsert({
      'id': _userId,
      'nickname': nickname,
      'nationality': nationality,
      'favorite_tags': favoriteTags,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
