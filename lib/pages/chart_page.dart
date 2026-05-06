import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../services/ad_service.dart';
import '../services/supabase_service.dart';
import '../widgets/artist_symbol.dart';
import 'artist_chat_page.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final _supabase = SupabaseService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _chart = [];
  bool _isLoading = true;
  int _todayVoteCount = 0;
  int _maxVotes = 1;
  int _adWatchCount = 0;
  bool _isVoting = false;
  String? _selectedArtist;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;
  String _searchQuery = '';

  static const _votableArtists = [
    'BTS', 'BLACKPINK', 'Stray Kids', 'SEVENTEEN', 'KATSEYE',
    'Jung Kook', 'Lisa', 'Jennie', 'Rosé',
    'NewJeans', 'aespa', 'ENHYPEN', 'TWICE',
    'IVE', 'LE SSERAFIM', 'TXT', 'ATEEZ', 'NCT', 'RIIZE',
    'BABYMONSTER', 'EXO',
    'ITZY', 'NMIXX', 'ILLIT', 'TWS', 'KISS OF LIFE',
    'ZEROBASEONE', 'BOYNEXTDOOR', 'MONSTA X', 'TREASURE',
    '(G)I-DLE', 'Red Velvet', 'Kep1er', 'Jimin', 'V', 'SUGA',
    'Jisoo', 'IU', 'izna', 'Hearts2Hearts', 'MEOVV',
  ];

  static Color _artistColor(String name) {
    final style = ArtistSymbol.artistSymbols[name];
    return style?.gradient.first ?? KokColors.primary;
  }

  List<String> get _filteredVotableArtists {
    if (_searchQuery.isEmpty) return _votableArtists;
    final q = _searchQuery.toLowerCase();
    return _votableArtists.where((a) => a.toLowerCase().contains(q)).toList();
  }

  bool get _canVote => _todayVoteCount < _maxVotes;
  int get _votesRemaining => _maxVotes - _todayVoteCount;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.getWeeklyChart(),
        _supabase.getTodayVoteCount(),
      ]);
      if (mounted) {
        setState(() {
          _chart = results[0] as List<Map<String, dynamic>>;
          _todayVoteCount = results[1] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final nextMonday = now.add(Duration(days: (DateTime.monday - now.weekday + 7) % 7));
    final resetTime = DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
    var diff = resetTime.difference(now);
    if (diff.isNegative || diff.inSeconds == 0) diff = const Duration(days: 7);
    if (mounted) setState(() => _timeUntilReset = diff);
  }

  Future<void> _castVote(String artistName) async {
    if (_isVoting || !_canVote) return;
    setState(() => _isVoting = true);

    try {
      final success = await _supabase.castVote(artistName, maxVotes: _maxVotes);
      if (success && mounted) {
        setState(() => _todayVoteCount++);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voted for $artistName!'), backgroundColor: KokColors.success),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote limit reached'), backgroundColor: KokColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e'), backgroundColor: KokColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _watchAdForVote() async {
    if (!mounted) return;

    final progress = _adWatchCount % 3 + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.play_circle_outline_rounded, color: KokColors.accent, size: 22),
            const SizedBox(width: 8),
            Text('Watch Ad ($progress/3)',
                style: const TextStyle(color: KokColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Watch 3 ads to earn +1 bonus vote.',
                style: TextStyle(color: KokColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 3,
                minHeight: 6,
                backgroundColor: KokColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation(KokColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: KokColors.textMuted.withAlpha(180))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KokColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Watch', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await AdService().showRewardedAd(
      onRewarded: () {
        setState(() {
          _adWatchCount++;
          if (_adWatchCount % 3 == 0) {
            _maxVotes++;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('+1 bonus vote earned!'), backgroundColor: KokColors.success),
            );
          }
        });
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.'), backgroundColor: KokColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCountdown(),
            const SizedBox(height: 8),
            if (_canVote) _buildVoteSection(),
            if (!_canVote) _buildAdBanner(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: KokColors.primary))
                  : _chart.isEmpty
                      ? _buildEmptyState()
                      : _buildChartList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [KokColors.primary, KokColors.accent],
            ).createShader(bounds),
            child: Text(
              'FANDOM CHART',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: KokColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KokColors.border, width: 0.5),
            ),
            child: Text(
              'WEEKLY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: KokColors.primary, letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    final d = _timeUntilReset.inDays;
    final h = _timeUntilReset.inHours % 24;
    final m = _timeUntilReset.inMinutes % 60;
    final s = _timeUntilReset.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [KokColors.primary.withAlpha(15), KokColors.accent.withAlpha(15)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: KokColors.textSecondary),
            const SizedBox(width: 8),
            Text('Resets in ',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: KokColors.textSecondary)),
            Text('${d}d ${h}h ${m}m ${s}s',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w800, color: KokColors.primary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _canVote ? KokColors.success.withAlpha(30) : KokColors.textMuted.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _canVote ? '$_votesRemaining VOTE${_votesRemaining > 1 ? 'S' : ''} LEFT' : 'VOTED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: _canVote ? KokColors.success : KokColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteSection() {
    final filtered = _filteredVotableArtists;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cast your vote',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
              const Spacer(),
              if (_selectedArtist != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedArtist = null),
                  child: Text('Clear', style: TextStyle(fontSize: 12, color: KokColors.textMuted.withAlpha(150))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 13, color: KokColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search artist...',
              hintStyle: TextStyle(color: KokColors.textMuted.withAlpha(100), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: KokColors.textMuted.withAlpha(120)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                      child: Icon(Icons.close_rounded, size: 16, color: KokColors.textMuted.withAlpha(120)),
                    )
                  : null,
              filled: true,
              fillColor: KokColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: filtered.isEmpty
                ? Center(child: Text('No match', style: TextStyle(fontSize: 12, color: KokColors.textMuted.withAlpha(120))))
                : GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.35,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final name = filtered[i];
                      final selected = _selectedArtist == name;
                      final color = _artistColor(name);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedArtist = name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? color.withAlpha(30) : KokColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? color : KokColors.border,
                              width: selected ? 1.5 : 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ArtistSymbol(artistName: name, size: 22),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        color: selected ? color : KokColors.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedArtist != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVoting ? null : () => _castVote(_selectedArtist!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _artistColor(_selectedArtist!),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isVoting
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Vote for $_selectedArtist',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    final adsUntilVote = 3 - (_adWatchCount % 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        onTap: _watchAdForVote,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [KokColors.accent.withAlpha(20), KokColors.primary.withAlpha(20)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KokColors.accent.withAlpha(60), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.play_circle_filled_rounded, color: KokColors.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Want more votes?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
                    Text('Watch $adsUntilVote more ad${adsUntilVote > 1 ? 's' : ''} to earn +1 vote',
                        style: TextStyle(fontSize: 11, color: KokColors.textMuted.withAlpha(180))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: KokColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('WATCH', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: KokColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _chart.length,
        itemBuilder: (_, i) => _buildChartItem(_chart[i], i),
      ),
    );
  }

  Widget _buildChartItem(Map<String, dynamic> entry, int index) {
    final name = entry['artist_name'] as String? ?? '';
    final votes = entry['vote_count'] as int? ?? 0;
    final rank = entry['rank'] as int? ?? (index + 1);

    final isTop3 = rank <= 3;
    final rankColors = [KokColors.primary, KokColors.accent, KokColors.warning];
    final rankColor = isTop3 ? rankColors[rank - 1] : KokColors.textMuted;

    final maxVotes = _chart.isNotEmpty ? (_chart.first['vote_count'] as int? ?? 1) : 1;
    final barWidth = maxVotes > 0 ? (votes / maxVotes) : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtistChatPage(artistName: name)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isTop3 ? rankColor.withAlpha(8) : KokColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTop3 ? rankColor.withAlpha(60) : KokColors.border,
            width: isTop3 ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('#$rank',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: isTop3 ? 18 : 15, fontWeight: FontWeight.w900, color: rankColor)),
            ),
            const SizedBox(width: 10),
            ArtistSymbol(artistName: name, size: isTop3 ? 36 : 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                                color: KokColors.textPrimary)),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 14, color: KokColors.textMuted.withAlpha(100)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 4,
                      backgroundColor: KokColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(rankColor.withAlpha(180)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatVotes(votes),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: isTop3 ? rankColor : KokColors.textSecondary)),
                Text('votes', style: TextStyle(fontSize: 10, color: KokColors.textMuted.withAlpha(150))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_vote_rounded, size: 48, color: KokColors.textMuted.withAlpha(80)),
          const SizedBox(height: 12),
          Text('No votes this week yet',
              style: TextStyle(fontSize: 15, color: KokColors.textMuted.withAlpha(150))),
          const SizedBox(height: 4),
          const Text('Be the first to vote!',
              style: TextStyle(fontSize: 13, color: KokColors.textMuted)),
        ],
      ),
    );
  }

  String _formatVotes(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
