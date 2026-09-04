import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';

class LocalStorageState {
  final String currentPath;
  final List<FileNode> files;
  final SortBy sortBy;
  final bool isLoading;
  final String? errorMessage;
  final List<String> history;

  LocalStorageState({
    this.currentPath = '',
    this.files = const [],
    this.sortBy = SortBy.name,
    this.isLoading = false,
    this.errorMessage,
    this.history = const [],
  });

  LocalStorageState copyWith({
    String? currentPath,
    List<FileNode>? files,
    SortBy? sortBy,
    bool? isLoading,
    String? errorMessage,
    List<String>? history,
  }) {
    return LocalStorageState(
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      history: history ?? this.history,
    );
  }
}

class LocalStorageNotifier extends StateNotifier<LocalStorageState> {
  LocalStorageNotifier() : super(LocalStorageState()) {
    initLocalDirectory();
  }

  /// Initialize local storage root (Downloads or Application Documents directory).
  Future<void> initLocalDirectory() async {
    state = state.copyWith(isLoading: true);
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final initialPath = dir.path;
      state = state.copyWith(
        currentPath: initialPath,
        history: [initialPath],
        isLoading: false,
      );
      await loadDirectory(initialPath);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to access local storage: $e',
      );
    }
  }

  /// Load files in specified local directory.
  Future<void> loadDirectory(String path) async {
    state = state.copyWith(isLoading: true);
    try {
      final nodes = await listLocalDir(path: path, sortBy: state.sortBy);
      state = state.copyWith(
        currentPath: path,
        files: nodes,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Navigate to a subdirectory.
  Future<void> navigateTo(String path) async {
    final history = List<String>.from(state.history)..add(path);
    state = state.copyWith(history: history);
    await loadDirectory(path);
  }

  /// Navigate up one directory level.
  Future<void> navigateUp() async {
    final current = state.currentPath;
    if (current.isEmpty) return;

    final dir = Directory(current);
    final parent = dir.parent.path;
    if (parent != current && parent.isNotEmpty) {
      await navigateTo(parent);
    }
  }

  /// Set sorting order.
  void setSortBy(SortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
    loadDirectory(state.currentPath);
  }

  /// Create local directory.
  Future<bool> createFolder(String folderName) async {
    final path = '${state.currentPath}/$folderName';
    try {
      await createLocalDir(path: path);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Delete local file or directory.
  Future<bool> deleteItem(FileNode item) async {
    try {
      await deleteLocal(path: item.path);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Rename local item.
  Future<bool> renameItem(FileNode item, String newName) async {
    final parentDir = Directory(item.path).parent.path;
    final newPath = '$parentDir/$newName';

    try {
      await renameLocal(oldPath: item.path, newPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Move local file or directory to a target folder.
  Future<bool> moveItem(FileNode item, String targetDir) async {
    final newPath = '$targetDir/${item.name}';
    try {
      await renameLocal(oldPath: item.path, newPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Copy local file to a target folder.
  Future<bool> copyItem(FileNode item, String targetDir) async {
    final newPath = '$targetDir/${item.name}';
    try {
      await copyLocal(srcPath: item.path, dstPath: newPath);
      await loadDirectory(state.currentPath);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final localStorageProvider =
    StateNotifierProvider<LocalStorageNotifier, LocalStorageState>((ref) {
  return LocalStorageNotifier();
});
