import 'dart:async';
import 'package:flutter/foundation.dart';
import 'content_pipeline.dart';
import 'source_collector.dart';
import 'supabase_service.dart';

class ContentScheduler {
  static final ContentScheduler _instance = ContentScheduler._();
  factory ContentScheduler() => _instance;
  ContentScheduler._();

  final _pipeline = ContentPipeline();
  final _collector = SourceCollector();
  final _supabase = SupabaseService();

  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastRunAt;

  static const _intervalHours = 6;
  static const maxArticlesPerRun = 5;

  void start() {
    if (_timer != null) return;
    debugPrint('[KOK Scheduler] Starting (check every 30min, interval=${_intervalHours}h)');
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _checkAndRun());
    _checkAndRun();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkAndRun() async {
    if (_isRunning) {
      debugPrint('[KOK Scheduler] Skip: already running');
      return;
    }
    if (!_hasIntervalPassed()) {
      debugPrint('[KOK Scheduler] Skip: interval not passed (last=$_lastRunAt)');
      return;
    }

    try {
      final canRun = await _supabase.canRunPipeline();
      if (!canRun) {
        debugPrint('[KOK Scheduler] Skip: DB says cannot run (another run active)');
        return;
      }
    } catch (e) {
      debugPrint('[KOK Scheduler] Skip: canRunPipeline error: $e');
      return;
    }

    await runPipeline();
  }

  bool _hasIntervalPassed() {
    if (_lastRunAt == null) return true;
    return DateTime.now().difference(_lastRunAt!).inHours >= _intervalHours;
  }

  Future<void> runPipeline() async {
    if (_isRunning) return;
    _isRunning = true;

    String? runId;

    try {
      runId = await _supabase.startPipelineRun();

      final existingHashes = await _supabase.getProcessedHashes();
      _pipeline.loadProcessedHashes(existingHashes);

      final naverCandidates = await _collector.collectFromNaverNews();
      final youtubeCandidates = await _collector.collectFromYouTube();
      final allCandidates = [...naverCandidates, ...youtubeCandidates];

      final cards = await _pipeline.processNewsBatch(allCandidates);

      for (final card in cards) {
        final sources = card['original_sources'] as List?;
        if (sources != null) {
          for (final src in sources) {
            final s = src as Map<String, dynamic>;
            final url = s['url']?.toString() ?? '';
            if (url.isNotEmpty) {
              await _supabase.markUrlProcessed(_pipeline.hashUrl(url), url);
            }
          }
        }
      }

      // 7일 지난 기사 정리
      await _cleanupOldArticles();

      await _supabase.completePipelineRun(
        runId,
        candidatesFound: allCandidates.length,
        articlesGenerated: cards.length,
        articlesBlocked: allCandidates.length - cards.length,
        groqCalls: _pipeline.groqCallCount,
        geminiCalls: _pipeline.geminiCallCount,
      );

      _lastRunAt = DateTime.now();
      debugPrint('[KOK] Pipeline done: ${cards.length} articles, '
          'Groq=${_pipeline.groqCallCount}, Gemini=${_pipeline.geminiCallCount}');
    } catch (e) {
      debugPrint('[KOK] Pipeline failed: $e');
      if (runId != null) {
        await _supabase.failPipelineRun(runId, e.toString());
      }
    } finally {
      _isRunning = false;
      _pipeline.resetCallCounts();
    }
  }

  Future<void> _cleanupOldArticles() async {
    try {
      await _supabase.cleanupOldArticles();
      debugPrint('[KOK] Old articles cleaned up');
    } catch (e) {
      debugPrint('[KOK] Cleanup failed: $e');
    }
  }

  bool get isRunning => _isRunning;
  DateTime? get lastRunAt => _lastRunAt;
}
