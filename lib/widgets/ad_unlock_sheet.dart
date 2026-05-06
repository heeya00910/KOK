import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';

class AdUnlockSheet extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AdUnlockSheet({super.key, required this.onUnlocked});

  @override
  State<AdUnlockSheet> createState() => _AdUnlockSheetState();
}

class _AdUnlockSheetState extends State<AdUnlockSheet> {
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    AdService().loadRewardedAd();
  }

  Future<void> _watchAd(AppProvider provider) async {
    setState(() => _isLoadingAd = true);

    final success = await AdService().showRewardedAd(
      onRewarded: () {
        provider.onAdWatched();
        if (provider.adWatchCount >= 2) {
          if (mounted) {
            Navigator.pop(context);
            widget.onUnlocked();
          }
        }
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad not ready. Please try again.'),
          backgroundColor: KokColors.error,
        ),
      );
    }

    if (mounted) setState(() => _isLoadingAd = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lang = provider.language;
    final adsWatched = provider.adWatchCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: KokColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: KokColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KokColors.gradientStart, KokColors.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            lang == 'es' ? 'Desbloquear articulo' : 'Unlock Article',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: KokColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'es'
                ? 'Mira 2 anuncios cortos para leer este articulo'
                : 'Watch 2 short ads to read this article',
            style: const TextStyle(fontSize: 14, color: KokColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildProgressDots(adsWatched),
          const SizedBox(height: 24),
          if (adsWatched < 2) ...[
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isLoadingAd ? null : () => _watchAd(provider),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white.withAlpha(20))),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [KokColors.gradientStart, KokColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isLoadingAd
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            lang == 'es'
                                ? 'Ver anuncio ${adsWatched + 1} de 2'
                                : 'Watch Ad ${adsWatched + 1} of 2',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onUnlocked();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KokColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  lang == 'es' ? 'Leer ahora!' : 'Read Now!',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              provider.cancelUnlockFlow();
              Navigator.pop(context);
            },
            child: Text(
              lang == 'es' ? 'Cancelar' : 'Cancel',
              style: const TextStyle(color: KokColors.textMuted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProgressDots(int completed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isDone = index < completed;
        final isCurrent = index == completed;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDone
                      ? const LinearGradient(colors: [KokColors.success, Color(0xFF059669)])
                      : isCurrent
                          ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
                          : null,
                  color: (!isDone && !isCurrent) ? KokColors.surfaceLight : null,
                  border: (!isDone && !isCurrent) ? Border.all(color: KokColors.border) : null,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: isDone || isCurrent ? Colors.white : KokColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ad ${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDone ? KokColors.success : KokColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
