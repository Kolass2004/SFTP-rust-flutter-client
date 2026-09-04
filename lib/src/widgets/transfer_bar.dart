import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sftp_client/src/providers/transfer_provider.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/utils/formatters.dart';

class TransferBar extends ConsumerWidget {
  final VoidCallback onTap;

  const TransferBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferProvider);

    if (state.transfers.isEmpty) return const SizedBox.shrink();

    final activeCount = state.activeCount;
    final totalSpeed = Formatters.formatSpeed(state.totalSpeedBytesPerSec);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, -4)),
          ],
          border: const Border(top: BorderSide(color: AppTheme.cardDark, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? AppTheme.primaryViolet.withValues(alpha: 0.2)
                    : AppTheme.successGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activeCount > 0 ? Icons.sync_rounded : Icons.check_circle_rounded,
                color: activeCount > 0 ? AppTheme.primaryLight : AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeCount > 0
                        ? 'Transferring $activeCount file(s) • $totalSpeed'
                        : 'All transfers finished',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.transfers.length} total transfers in queue',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
