import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import '../models/comment.dart';
import '../models/user_profile.dart';
import '../core/constants/mock_data.dart';

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

  String get language => _language;
  List<NewsArticle> get articles => _articles;
  Set<String> get selectedTags => _selectedTags;
  int get freeViewsRemaining => _freeViewsRemaining;
  bool get isLoading => _isLoading;
  int get adWatchCount => _adWatchCount;
  String? get pendingUnlockArticleId => _pendingUnlockArticleId;
  UserProfile get profile => _profile;

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

    await loadArticles();
    notifyListeners();
  }

  Future<void> loadArticles() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));
    _articles = MockData.sampleArticles;

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

  void addComment(String articleId, String content) {
    if (_profile.nickname.isEmpty) return;
    final comment = UserComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      articleId: articleId,
      nickname: _profile.nickname,
      content: content,
      createdAt: DateTime.now(),
    );
    _commentsByArticle.putIfAbsent(articleId, () => []);
    _commentsByArticle[articleId]!.insert(0, comment);
    notifyListeners();
  }

  void likeComment(String articleId, String commentId) {
    final comments = _commentsByArticle[articleId];
    if (comments != null) {
      final comment = comments.firstWhere((c) => c.id == commentId);
      comment.likes++;
      notifyListeners();
    }
  }

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
    } else {
      _profile.favoriteTags.add(tag);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_tags', _profile.favoriteTags);
    notifyListeners();
  }

  Future<void> _saveFreeViews() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('free_views', _freeViewsRemaining);
  }
}
