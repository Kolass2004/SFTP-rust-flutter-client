import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sftp_client/src/providers/transfer_provider.dart';
import 'package:sftp_client/src/rust/api/transfer.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/utils/formatters.dart';

class TransferManagerSheet extends ConsumerWidget {
  const TransferManagerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Sheet Drag Handle & Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryViolet.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: AppTheme.primaryLight, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Transfer Manager',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.transfers.any((t) => t.progress?.isComplete == true || t.isCancelled))
                  IconButton(
                    tooltip: 'Clear Finished',
                    icon: const Icon(Icons.clear_all_rounded, color: AppTheme.accentCyan, size: 22),
                    onPressed: () => ref.read(transferProvider.notifier).clearCompleted(),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardDark),

          // Total Speed Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.surfaceDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: AppTheme.accentCyan, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Speed: ${Formatters.formatSpeed(state.totalSpeedBytesPerSec)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '${state.activeCount} active',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // Transfer List
          Expanded(
            child: state.transfers.isEmpty
                ? const Center(
                    child: Text(
                      'No active or recent file transfers',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.transfers.length,
                    itemBuilder: (context, index) {
                      final item = state.transfers[index];
                      final prog = item.progress;
                      final isUpload = item.direction == TransferDirection.localToRemote;
                      final isError = prog != null && prog.error.isNotEmpty;
                      final isDone = prog != null && prog.isComplete && !isError;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isError
                                ? AppTheme.errorRed.withValues(alpha: 0.4)
                                : isDone
                                    ? AppTheme.successGreen.withValues(alpha: 0.3)
                                    : AppTheme.cardDark,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isUpload
                                        ? AppTheme.primaryViolet.withValues(alpha: 0.2)
                                        : AppTheme.accentCyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isUpload ? Icons.upload_rounded : Icons.download_rounded,
                                    color: isUpload ? AppTheme.primaryLight : AppTheme.accentCyan,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isError
                                            ? 'Error: ${prog.error}'
                                            : item.isCancelled
                                                ? 'Cancelled'
                                                : isDone
                                                    ? 'Completed • ${Formatters.formatBytes(prog.totalBytes.toInt())}'
                                                    : '${Formatters.formatBytes(prog?.transferredBytes.toInt() ?? 0)} of ${Formatters.formatBytes(prog?.totalBytes.toInt() ?? 0)} • ${Formatters.formatSpeed(prog?.speedBytesPerSec ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isError
                                              ? AppTheme.errorRed
                                              : item.isCancelled
                                                  ? AppTheme.warningAmber
                                                  : isDone
                                                      ? AppTheme.successGreen
                                                      : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isDone && !isError && !item.isCancelled)
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: AppTheme.errorRed, size: 20),
                                    onPressed: () => ref.read(transferProvider.notifier).cancel(item.id),
                                  )
                              ],
                            ),
                            if (!isDone && !isError && !item.isCancelled) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: (prog?.percentage ?? 0.0) / 100.0,
                                backgroundColor: AppTheme.cardDark,
                                color: isUpload ? AppTheme.primaryViolet : AppTheme.accentCyan,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(prog?.percentage ?? 0.0).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  Text(
                                    'ETA: ${Formatters.formatEta(prog?.etaSeconds ?? 0)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
