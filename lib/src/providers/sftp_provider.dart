import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';
import 'package:sftp_client/src/rust/api/sftp_session.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class SftpState {
  final ConnectionStatus status;
  final String? activeHost;
  final String? activeUser;
  final String currentPath;
  final List<FileNode> files;
  final SortBy sortBy;
  final String? errorMessage;
  final List<String> history;

  SftpState({
    this.status = ConnectionStatus.disconnected,
    this.activeHost,
    this.activeUser,
    this.currentPath = '/',
    this.files = const [],
    this.sortBy = SortBy.name,
    this.errorMessage,
    this.history = const ['/'],
  });

  SftpState copyWith({
    ConnectionStatus? status,
    String? activeHost,
    String? activeUser,
    String? currentPath,
    List<FileNode>? files,
    SortBy? sortBy,
    String? errorMessage,
    List<String>? history,
  }) {
    return SftpState(
      status: status ?? this.status,
      activeHost: activeHost ?? this.activeHost,
      activeUser: activeUser ?? this.activeUser,
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      sortBy: sortBy ?? this.sortBy,
      errorMessage: errorMessage,
      history: history ?? this.history,
    );
  }
}

class SftpNotifier extends StateNotifier<SftpState> {
  Timer? _keepAliveTimer;

  SftpNotifier() : super(SftpState());

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (state.status == ConnectionStatus.connected) {
        await pingSftp();
      }
    });
  }

  /// Connect to SFTP server with credentials.
  Future<ConnectResult> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      activeHost: host,
      activeUser: username,
      errorMessage: null,
    );

    final res = await connectSftp(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    if (res.success) {
      final initialPath = res.homeDir.isNotEmpty ? res.homeDir : '/';
      state = state.copyWith(
        status: ConnectionStatus.connected,
        currentPath: initialPath,
        history: [initialPath],
      );
      _startKeepAlive();
      await loadDirectory(initialPath);
    } else {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: res.message,
      );
    }

    return res;
  }

  /// Disconnect from remote SFTP server.
  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
    await disconnectSftp();
    state = SftpState();
  }

  /// Load files in specified remote directory.
  Future<void> loadDirectory(String path) async {
    if (state.status != ConnectionStatus.connected) return;

    try {
      final nodes = await listRemoteDir(path: path, sortBy: state.sortBy);
      state = state.copyWith(
        currentPath: path,
        files: nodes,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Navigate into a subdirectory.
  Future<void> navigateTo(String path) async {
    final history = List<String>.from(state.history)..add(path);
    state = state.copyWith(history: history);
    await loadDirectory(path);
  }

  /// Navigate up one directory level.
  Future<void> navigateUp() async {
    final current = state.currentPath;
    if (current == '/' || current.isEmpty) return;

    final parts = current.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      await navigateTo('/');
      return;
    }
    parts.removeLast();
    final parent = '/${parts.join('/')}';
    await navigateTo(parent.isEmpty ? '/' : parent);
  }

  /// Set sorting option and reload.
  void setSortBy(SortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
    loadDirectory(state.currentPath);
  }

  /// Create remote folder.
  Future<bool> createFolder(String folderName) async {
    final fullPath = state.currentPath.endsWith('/')
        ? '${state.currentPath}$folderName'
        : '${state.currentPath}/$folderName';

    try {
      await createRemoteDir(path: fullPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Delete remote file or folder.
  Future<bool> deleteItem(FileNode item) async {
    try {
      if (item.isDir) {
        await deleteRemoteDir(path: item.path);
      } else {
        await deleteRemoteFile(path: item.path);
      }
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Rename remote file or directory.
  Future<bool> renameItem(FileNode item, String newName) async {
    final parentDir = item.path.substring(0, item.path.lastIndexOf('/'));
    final newPath = parentDir.isEmpty ? '/$newName' : '$parentDir/$newName';

    try {
      await renameRemote(oldPath: item.path, newPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Move remote file or directory to a target remote folder.
  Future<bool> moveItem(FileNode item, String targetDir) async {
    final newPath = targetDir.endsWith('/')
        ? '$targetDir${item.name}'
        : '$targetDir/${item.name}';
    try {
      await renameRemote(oldPath: item.path, newPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Copy remote file to a target remote folder.
  Future<bool> copyItem(FileNode item, String targetDir) async {
    final newPath = targetDir.endsWith('/')
        ? '$targetDir${item.name}'
        : '$targetDir/${item.name}';
    try {
      await copyRemote(srcPath: item.path, dstPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final sftpProvider = StateNotifierProvider<SftpNotifier, SftpState>((ref) {
  return SftpNotifier();
});
