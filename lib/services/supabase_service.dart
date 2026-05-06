import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_article.dart';
import '../models/comment.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _userId;

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

  // ── Admin: Articles ──

  Future<void> deleteArticle(String articleId) async {
    await _client.from('articles').delete().eq('id', articleId);
  }

  Future<void> updateArticle(String articleId, Map<String, dynamic> updates) async {
    await _client.from('articles').update(updates).eq('id', articleId);
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
              userId: json['user_id'] ?? '',
              nickname: json['nickname'] ?? '',
              nationality: json['nationality'] ?? '',
              fandom: json['fandom'] ?? '',
              content: json['content'] ?? '',
              createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
              editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at']) : null,
              likes: json['likes'] ?? 0,
            ))
        .toList();
  }

  Future<void> addComment(String articleId, String nickname, String content, {
    String nationality = '',
    String fandom = '',
  }) async {
    await _client.from('user_comments').insert({
      'article_id': articleId,
      'user_id': _userId,
      'nickname': nickname,
      'content': content,
      'nationality': nationality,
      'fandom': fandom,
    });
  }

  Future<void> updateComment(String commentId, String newContent) async {
    await _client.from('user_comments').update({
      'content': newContent,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', commentId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('user_comments').delete().eq('id', commentId);
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
              userId: json['user_id'] ?? '',
              nickname: json['nickname'] ?? '',
              nationality: json['nationality'] ?? '',
              fandom: json['fandom'] ?? '',
              content: json['content'] ?? '',
              createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
              editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at']) : null,
              likes: json['likes'] ?? 0,
            ))
        .toList();
  }

  // ── Admin: delete any comment ──

  Future<void> adminDeleteComment(String commentId) async {
    await _client.rpc('admin_delete_comment', params: {'target_comment_id': commentId});
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

  // ── Pipeline: insert article via RPC ──

  Future<String?> insertPipelineArticle(Map<String, dynamic> articleData) async {
    final res = await _client.rpc('insert_pipeline_article', params: {
      'article_data': articleData,
    });
    return res as String?;
  }

  // ── Pipeline scheduling ──

  Future<bool> canRunPipeline() async {
    final res = await _client.rpc('can_run_pipeline');
    return res == true;
  }

  Future<String> startPipelineRun() async {
    final res = await _client.from('pipeline_runs').insert({
      'status': 'running',
    }).select('id').single();
    return res['id'] as String;
  }

  Future<void> completePipelineRun(String runId, {
    required int candidatesFound,
    required int articlesGenerated,
    required int articlesBlocked,
    required int groqCalls,
    required int geminiCalls,
  }) async {
    await _client.from('pipeline_runs').update({
      'completed_at': DateTime.now().toIso8601String(),
      'candidates_found': candidatesFound,
      'articles_generated': articlesGenerated,
      'articles_blocked': articlesBlocked,
      'groq_calls': groqCalls,
      'gemini_calls': geminiCalls,
      'status': 'completed',
    }).eq('id', runId);
  }

  Future<void> failPipelineRun(String runId, String error) async {
    await _client.from('pipeline_runs').update({
      'completed_at': DateTime.now().toIso8601String(),
      'status': 'failed',
      'error_message': error,
    }).eq('id', runId);
  }

  Future<void> markUrlProcessed(String urlHash, String originalUrl) async {
    await _client.from('processed_urls').upsert({
      'url_hash': urlHash,
      'original_url': originalUrl,
    });
  }

  Future<void> cleanupOldArticles() async {
    await _client.rpc('cleanup_old_articles');
  }

  Future<Set<String>> getProcessedHashes() async {
    final res = await _client.from('processed_urls').select('url_hash');
    return (res as List).map((r) => r['url_hash'] as String).toSet();
  }

  // ── Chart ──

  Future<List<Map<String, dynamic>>> getWeeklyChart() async {
    final res = await _client.rpc('get_weekly_chart');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<int> getTodayVoteCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 999;
    final res = await _client.rpc('get_today_vote_count', params: {'p_user_id': userId});
    return (res as int?) ?? 0;
  }

  Future<bool> castVote(String artistName, {int maxVotes = 1}) async {
    final res = await _client.rpc('cast_chart_vote', params: {
      'p_artist_name': artistName,
      'p_max_votes': maxVotes,
    });
    return res == true;
  }

  // ── Artist Chat ──

  Future<List<Map<String, dynamic>>> getArtistChats(String artistName, {int limit = 100}) async {
    final res = await _client
        .from('artist_chats')
        .select()
        .eq('artist_name', artistName)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> sendArtistChat({
    required String artistName,
    required String nickname,
    required String message,
    String nationality = '',
    String fandom = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _client.from('artist_chats').insert({
      'artist_name': artistName,
      'user_id': userId,
      'nickname': nickname,
      'nationality': nationality,
      'fandom': fandom,
      'message': message,
    });
  }

  Future<void> updateArtistChat({
    required String chatId,
    required String newMessage,
  }) async {
    await _client.from('artist_chats')
        .update({'message': newMessage})
        .eq('id', chatId);
  }

  Future<void> deleteArtistChat(String chatId) async {
    await _client.from('artist_chats').delete().eq('id', chatId);
  }

  Future<void> cleanupOldChats() async {
    await _client.rpc('cleanup_old_chats');
  }
}
