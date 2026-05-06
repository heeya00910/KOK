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
    debugPrint('[KOK Scheduler] Started — check every 30min, generate every ${_intervalHours}h');
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _checkAndRun());
    // 로그인 시 즉시 실행하지 않음 — 주기에 맞춰서만 자동 실행
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkAndRun() async {
    if (_isRunning) return;
    if (!_hasIntervalPassed()) return;

    try {
      final canRun = await _supabase.canRunPipeline();
      if (!canRun) {
        debugPrint('[KOK Scheduler] Skip: another pipeline run is active in DB');
        return;
      }
    } catch (e) {
      debugPrint('[KOK Scheduler] canRunPipeline error: $e');
      return;
    }

    await runPipeline();
  }

  bool _hasIntervalPassed() {
    if (_lastRunAt == null) return true;
    return DateTime.now().difference(_lastRunAt!).inHours >= _intervalHours;
  }

  Future<void> runPipeline() async {
    if (_isRunning) {
      debugPrint('[KOK Scheduler] Pipeline already running, skipping');
      return;
    }
    _isRunning = true;
    _pipeline.clearCache();

    String? runId;
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[KOK] ═══════════════════════════════════');
      debugPrint('[KOK] Pipeline START');
      debugPrint('[KOK] ═══════════════════════════════════');

      // 1) DB lock
      runId = await _supabase.startPipelineRun();
      debugPrint('[KOK] Pipeline run registered: $runId');

      // 2) Load processed URLs + chart bonus
      final existingHashes = await _supabase.getProcessedHashes();
      _pipeline.loadProcessedHashes(existingHashes);

      try {
        final chartData = await _supabase.getWeeklyChart();
        SourceCollector.loadChartBonus(chartData);
        debugPrint('[KOK] Chart bonus loaded: ${chartData.length} artists');
      } catch (e) {
        debugPrint('[KOK] Chart bonus load skipped: $e');
      }

      // 3) Collect from sources
      debugPrint('[KOK] ── Collecting sources ──');
      final naverCandidates = await _collector.collectFromNaverNews();
      debugPrint('[KOK] Naver: ${naverCandidates.length} candidates');

      final youtubeCandidates = await _collector.collectFromYouTube();
      debugPrint('[KOK] YouTube: ${youtubeCandidates.length} candidates');

      final allCandidates = [...naverCandidates, ...youtubeCandidates];
      debugPrint('[KOK] Total candidates: ${allCandidates.length}');

      if (allCandidates.isEmpty) {
        debugPrint('[KOK] No candidates found — check API keys in .env');
        await _supabase.completePipelineRun(runId,
          candidatesFound: 0, articlesGenerated: 0, articlesBlocked: 0,
          groqCalls: 0, geminiCalls: 0);
        return;
      }

      // 4) Process through AI pipeline
      debugPrint('[KOK] ── AI Processing ──');
      final cards = await _pipeline.processNewsBatch(allCandidates);

      // 5) Mark URLs as processed
      for (final card in cards) {
        final sources = card['original_sources'] as List?;
        if (sources != null) {
          for (final src in sources) {
            final s = src as Map<String, dynamic>;
            final url = s['url']?.toString() ?? '';
            if (url.isNotEmpty) {
              try {
                await _supabase.markUrlProcessed(_pipeline.hashUrl(url), url);
              } catch (_) {}
            }
          }
        }
      }

      // 6) Cleanup old articles
      await _cleanupOldArticles();

      // 7) Complete run
      await _supabase.completePipelineRun(runId,
        candidatesFound: allCandidates.length,
        articlesGenerated: cards.length,
        articlesBlocked: allCandidates.length - cards.length,
        groqCalls: _pipeline.groqCallCount,
        geminiCalls: _pipeline.geminiCallCount,
      );

      _lastRunAt = DateTime.now();
      stopwatch.stop();

      debugPrint('[KOK] ═══════════════════════════════════');
      debugPrint('[KOK] Pipeline DONE in ${stopwatch.elapsed.inSeconds}s');
      debugPrint('[KOK]   Articles: ${cards.length}');
      debugPrint('[KOK]   Groq calls: ${_pipeline.groqCallCount}');
      debugPrint('[KOK]   Gemini calls: ${_pipeline.geminiCallCount}');
      debugPrint('[KOK] ═══════════════════════════════════');
    } catch (e, st) {
      stopwatch.stop();
      debugPrint('[KOK] Pipeline FAILED in ${stopwatch.elapsed.inSeconds}s: $e');
      debugPrint('[KOK] Stack: ${st.toString().split('\n').take(5).join('\n')}');
      if (runId != null) {
        try {
          await _supabase.failPipelineRun(runId, e.toString());
        } catch (_) {}
      }
    } finally {
      _isRunning = false;
      _pipeline.resetCallCounts();
    }
  }

  Future<void> _cleanupOldArticles() async {
    try {
      await _supabase.cleanupOldArticles();
      debugPrint('[KOK] Old articles (>14 days) cleaned up');
    } catch (e) {
      debugPrint('[KOK] Cleanup failed: $e');
    }
  }

  bool get isRunning => _isRunning;
  DateTime? get lastRunAt => _lastRunAt;
}
