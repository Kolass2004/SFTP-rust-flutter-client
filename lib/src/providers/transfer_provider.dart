import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sftp_client/src/rust/api/transfer.dart';

class TransferItem {
  final String id;
  final String fileName;
  final TransferDirection direction;
  final String localPath;
  final String remotePath;
  final TransferProgress? progress;
  final bool isCancelled;

  TransferItem({
    required this.id,
    required this.fileName,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    this.progress,
    this.isCancelled = false,
  });

  TransferItem copyWith({
    TransferProgress? progress,
    bool? isCancelled,
  }) {
    return TransferItem(
      id: id,
      fileName: fileName,
      direction: direction,
      localPath: localPath,
      remotePath: remotePath,
      progress: progress ?? this.progress,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

class TransferState {
  final List<TransferItem> transfers;

  TransferState({this.transfers = const []});

  int get activeCount => transfers.where((t) => t.progress != null && !t.progress!.isComplete && !t.isCancelled && t.progress!.error.isEmpty).length;
  
  double get totalSpeedBytesPerSec => transfers
      .where((t) => t.progress != null && !t.progress!.isComplete && !t.isCancelled)
      .fold(0.0, (sum, t) => sum + (t.progress?.speedBytesPerSec ?? 0.0));
}

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(TransferState());

  final Map<String, StreamSubscription<TransferProgress>> _subscriptions = {};

  /// Enqueue an upload (Local -> Remote).
  void startUpload({
    required String localPath,
    required String remotePath,
    required String fileName,
  }) {
    final id = 'upload_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final fullRemotePath = remotePath.endsWith('/')
        ? '$remotePath$fileName'
        : '$remotePath/$fileName';

    final item = TransferItem(
      id: id,
      fileName: fileName,
      direction: TransferDirection.localToRemote,
      localPath: localPath,
      remotePath: fullRemotePath,
    );

    _initTransfer(item);
  }

  /// Enqueue a download (Remote -> Local).
  void startDownload({
    required String remotePath,
    required String localPath,
    required String fileName,
  }) {
    final id = 'download_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final fullLocalPath = '$localPath/$fileName';

    final item = TransferItem(
      id: id,
      fileName: fileName,
      direction: TransferDirection.remoteToLocal,
      localPath: fullLocalPath,
      remotePath: remotePath,
    );

    _initTransfer(item);
  }

  void _initTransfer(TransferItem item) {
    state = TransferState(transfers: [...state.transfers, item]);

    try {
      final stream = transferFile(
        transferId: item.id,
        direction: item.direction,
        localPath: item.localPath,
        remotePath: item.remotePath,
      );

      final sub = stream.listen(
        (progress) {
          _updateProgress(item.id, progress);
        },
        onError: (err) {
          _handleError(item.id, err.toString());
        },
      );

      _subscriptions[item.id] = sub;
    } catch (e) {
      _handleError(item.id, e.toString());
    }
  }

  void _updateProgress(String id, TransferProgress progress) {
    final updated = state.transfers.map((t) {
      if (t.id == id) {
        return t.copyWith(progress: progress);
      }
      return t;
    }).toList();

    state = TransferState(transfers: updated);

    if (progress.isComplete) {
      _subscriptions[id]?.cancel();
      _subscriptions.remove(id);
    }
  }

  void _handleError(String id, String error) {
    final updated = state.transfers.map((t) {
      if (t.id == id) {
        final currentProg = t.progress;
        final newProg = TransferProgress(
          transferId: id,
          fileName: t.fileName,
          totalBytes: currentProg?.totalBytes ?? BigInt.zero,
          transferredBytes: currentProg?.transferredBytes ?? BigInt.zero,
          percentage: currentProg?.percentage ?? 0.0,
          speedBytesPerSec: 0.0,
          etaSeconds: 0.0,
          isComplete: true,
          error: error,
        );
        return t.copyWith(progress: newProg);
      }
      return t;
    }).toList();

    state = TransferState(transfers: updated);
    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);
  }

  /// Cancel an active transfer.
  Future<void> cancel(String id) async {
    await cancelTransfer(transferId: id);

    final updated = state.transfers.map((t) {
      if (t.id == id) {
        return t.copyWith(isCancelled: true);
      }
      return t;
    }).toList();

    state = TransferState(transfers: updated);
    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);
  }

  /// Clear finished/cancelled transfers from the list.
  void clearCompleted() {
    final active = state.transfers.where((t) {
      if (t.isCancelled) return false;
      if (t.progress == null) return true;
      return !t.progress!.isComplete;
    }).toList();

    state = TransferState(transfers: active);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier();
});
