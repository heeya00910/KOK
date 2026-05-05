import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_article.dart';
import '../models/comment.dart';
import '../models/user_profile.dart';
import '../core/constants/mock_data.dart';
import '../services/supabase_service.dart';
import '../services/content_scheduler.dart';

class AppProvider extends ChangeNotifier {
  String _language = 'en';
  List<NewsArticle> _articles = [];
  final Set<String> _selectedTags = {};
  final Set<String> _unlockedArticleIds = {};
  int _freeViewsRemaining = 3;
  bool _isLoading = false;
  int _adWatchCount = 0;
  String? _pendingUnlockArticleId;

  UserProfile _profile = UserProfile();
  final Map<String, List<UserComment>> _commentsByArticle = {};
  final Set<String> _likedCommentIds = {};

  bool _isAdmin = false;

  String get language => _language;
  List<NewsArticle> get articles => _articles;
  Set<String> get selectedTags => _selectedTags;
  int get freeViewsRemaining => _freeViewsRemaining;
  bool get isLoading => _isLoading;
  int get adWatchCount => _adWatchCount;
  String? get pendingUnlockArticleId => _pendingUnlockArticleId;
  UserProfile get profile => _profile;
  bool get isAdmin => _isAdmin;

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  List<NewsArticle> get filteredArticles {
    if (_selectedTags.isEmpty) return _articles;
    return _articles.where((a) => a.allTags.any((t) => _selectedTags.contains(t))).toList();
  }

  bool isArticleUnlocked(String articleId) {
    return _unlockedArticleIds.contains(articleId);
  }

  bool get canViewFree => _freeViewsRemaining > 0;

  List<UserComment> getCommentsForArticle(String articleId) {
    return _commentsByArticle[articleId] ?? [];
  }

  List<UserComment> get myComments {
    if (_profile.nickname.isEmpty) return [];
    final all = <UserComment>[];
    for (final comments in _commentsByArticle.values) {
      all.addAll(comments.where((c) => c.nickname == _profile.nickname));
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'en';
    _freeViewsRemaining = prefs.getInt('free_views') ?? 3;
    _profile = UserProfile(
      nickname: prefs.getString('nickname') ?? '',
      nationality: prefs.getString('nationality') ?? '',
      representativeFandom: prefs.getString('representative_fandom') ?? '',
      favoriteTags: prefs.getStringList('favorite_tags') ?? [],
    );

    final lastReset = prefs.getString('last_reset');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastReset != today) {
      _freeViewsRemaining = 3;
      _unlockedArticleIds.clear();
      await prefs.setInt('free_views', 3);
      await prefs.setString('last_reset', today);
    }

    await _checkAdminRole();
    await loadArticles();

    if (_isAdmin) {
      ContentScheduler().start();
    }

    notifyListeners();
  }

  // ── Admin ──

  Future<void> _checkAdminRole() async {
    final uid = _userId;
    if (uid == null) {
      _isAdmin = false;
      debugPrint('[KOK] Admin check: no user logged in');
      return;
    }
    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      debugPrint('[KOK] Admin check: uid=$uid, email=$email');

      final res = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();

      if (res == null) {
        debugPrint('[KOK] Admin check: no profile found — creating...');
        await Supabase.instance.client.from('profiles').insert({
          'id': uid,
          'role': 'user',
        });
        final refreshed = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .maybeSingle();
        _isAdmin = refreshed != null && refreshed['role'] == 'admin';
      } else {
        _isAdmin = res['role'] == 'admin';
      }

      debugPrint('[KOK] Admin check result: $_isAdmin (role=${res?['role']})');
    } catch (e) {
      debugPrint('[KOK] Admin check failed: $e');
      _isAdmin = false;
    }
  }

  Future<void> adminDeleteArticle(String articleId) async {
    if (!_isAdmin) return;
    try {
      await Supabase.instance.client
          .from('articles')
          .delete()
          .eq('id', articleId);
    } catch (_) {}
    _articles.removeWhere((a) => a.id == articleId);
    _commentsByArticle.remove(articleId);
    notifyListeners();
  }

  Future<void> adminEditArticle(String articleId, Map<String, dynamic> updates) async {
    if (!_isAdmin) return;
    try {
      await Supabase.instance.client
          .from('articles')
          .update(updates)
          .eq('id', articleId);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> adminDeleteComment(String articleId, String commentId) async {
    if (!_isAdmin) return;
    try {
      await Supabase.instance.client
          .from('user_comments')
          .delete()
          .eq('id', commentId);
    } catch (_) {}
    final comments = _commentsByArticle[articleId];
    if (comments != null) {
      comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }
  }

  // ── Articles ──

  Future<void> loadArticles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await SupabaseService().fetchArticles();
      debugPrint('[KOK] Loaded ${fetched.length} articles from Supabase');
      if (fetched.isNotEmpty) {
        _articles = fetched;
      } else {
        debugPrint('[KOK] No articles in DB, using sample data');
        _articles = MockData.sampleArticles;
      }
    } catch (e) {
      debugPrint('[KOK] Article fetch failed: $e — using sample data');
      _articles = MockData.sampleArticles;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _language = _language == 'en' ? 'es' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _language);
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void clearTags() {
    _selectedTags.clear();
    notifyListeners();
  }

  // ── Free views / ad unlock ──

  bool tryViewArticle(String articleId) {
    if (_unlockedArticleIds.contains(articleId)) return true;

    if (_freeViewsRemaining > 0) {
      _freeViewsRemaining--;
      _unlockedArticleIds.add(articleId);
      _saveFreeViews();
      notifyListeners();
      return true;
    }

    return false;
  }

  void startUnlockFlow(String articleId) {
    _pendingUnlockArticleId = articleId;
    _adWatchCount = 0;
    notifyListeners();
  }

  void onAdWatched() {
    _adWatchCount++;
    if (_adWatchCount >= 2 && _pendingUnlockArticleId != null) {
      _unlockedArticleIds.add(_pendingUnlockArticleId!);
      _pendingUnlockArticleId = null;
      _adWatchCount = 0;
    }
    notifyListeners();
  }

  void cancelUnlockFlow() {
    _pendingUnlockArticleId = null;
    _adWatchCount = 0;
    notifyListeners();
  }

  // ── Comments ──

  bool isMyComment(UserComment comment) {
    final uid = _userId;
    if (uid != null && comment.userId.isNotEmpty) {
      return comment.userId == uid;
    }
    return _profile.nickname.isNotEmpty && comment.nickname == _profile.nickname;
  }

  void addComment(String articleId, String content) {
    if (_profile.nickname.isEmpty) return;
    final fandom = _profile.representativeFandom;
    final comment = UserComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      articleId: articleId,
      userId: _userId ?? '',
      nickname: _profile.nickname,
      nationality: _profile.nationality,
      fandom: fandom,
      content: content,
      createdAt: DateTime.now(),
    );
    _commentsByArticle.putIfAbsent(articleId, () => []);
    _commentsByArticle[articleId]!.insert(0, comment);
    notifyListeners();
  }

  bool hasLikedComment(String commentId) => _likedCommentIds.contains(commentId);

  void likeComment(String articleId, String commentId) {
    final comments = _commentsByArticle[articleId];
    if (comments == null) return;
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;

    if (_likedCommentIds.contains(commentId)) {
      _likedCommentIds.remove(commentId);
      comments[idx].likes = (comments[idx].likes - 1).clamp(0, 999999);
    } else {
      _likedCommentIds.add(commentId);
      comments[idx].likes++;
    }
    notifyListeners();
  }

  void editComment(String articleId, String commentId, String newContent) {
    final comments = _commentsByArticle[articleId];
    if (comments == null) return;
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    if (!isMyComment(comments[idx])) return;
    comments[idx].content = newContent;
    comments[idx].editedAt = DateTime.now();
    notifyListeners();
  }

  void deleteComment(String articleId, String commentId) {
    final comments = _commentsByArticle[articleId];
    if (comments == null) return;
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    if (!isMyComment(comments[idx]) && !_isAdmin) return;
    comments.removeAt(idx);
    notifyListeners();
  }

  // ── Profile ──

  Future<void> updateNickname(String nickname) async {
    _profile.nickname = nickname;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', nickname);
    notifyListeners();
  }

  Future<void> updateNationality(String nationality) async {
    _profile.nationality = nationality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nationality', nationality);
    notifyListeners();
  }

  Future<void> toggleFavoriteTag(String tag) async {
    if (_profile.favoriteTags.contains(tag)) {
      _profile.favoriteTags.remove(tag);
      if (_profile.representativeFandom == tag) {
        _profile.representativeFandom = '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('representative_fandom', '');
      }
    } else {
      _profile.favoriteTags.add(tag);
      if (_profile.representativeFandom.isEmpty) {
        _profile.representativeFandom = tag;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('representative_fandom', tag);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_tags', _profile.favoriteTags);
    notifyListeners();
  }

  Future<void> updateRepresentativeFandom(String tag) async {
    _profile.representativeFandom = tag;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('representative_fandom', tag);
    notifyListeners();
  }

  Future<void> _saveFreeViews() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('free_views', _freeViewsRemaining);
  }
}
