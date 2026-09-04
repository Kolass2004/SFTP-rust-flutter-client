import 'package:flutter/material.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/widgets/create_folder_dialog.dart';
import 'package:sftp_client/src/widgets/path_breadcrumbs.dart';

/// Opens a modal picker sheet allowing the user to select a destination folder
/// on either the remote server or local storage.
Future<String?> showDestinationFolderPicker(
  BuildContext context, {
  required bool isRemote,
  required String initialPath,
  required String title,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DestinationPickerSheet(
      isRemote: isRemote,
      initialPath: initialPath,
      title: title,
    ),
  );
}

class _DestinationPickerSheet extends StatefulWidget {
  final bool isRemote;
  final String initialPath;
  final String title;

  const _DestinationPickerSheet({
    required this.isRemote,
    required this.initialPath,
    required this.title,
  });

  @override
  State<_DestinationPickerSheet> createState() => _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  late String _currentPath;
  List<FileNode> _folders = [];
  bool _isLoading = true;
  bool _showHiddenFolders = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath.isEmpty ? '/' : widget.initialPath;
    _loadFolders(_currentPath);
  }

  Future<void> _loadFolders(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<FileNode> allNodes;
      if (widget.isRemote) {
        allNodes = await listRemoteDir(path: path, sortBy: SortBy.name);
      } else {
        allNodes = await listLocalDir(path: path, sortBy: SortBy.name);
      }

      // Filter directories (and hidden folders based on state)
      final dirsOnly = allNodes.where((n) {
        if (!n.isDir) return false;
        if (!_showHiddenFolders && n.name.startsWith('.')) return false;
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _currentPath = path;
          _folders = dirsOnly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _createNewFolder() async {
    final folderName = await showCreateFolderDialog(context);
    if (folderName != null && folderName.trim().isNotEmpty) {
      final target = _currentPath.endsWith('/')
          ? '$_currentPath${folderName.trim()}'
          : '$_currentPath/${folderName.trim()}';
      try {
        if (widget.isRemote) {
          await createRemoteDir(path: target);
        } else {
          await createLocalDir(path: target);
        }
        await _loadFolders(_currentPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.isRemote ? Icons.cloud_outlined : Icons.folder_open_rounded,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isRemote ? 'Remote Server Directory' : 'Local Device Directory',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _showHiddenFolders ? 'Hide Dot Folders' : 'Show Dot Folders',
                  icon: Icon(
                    _showHiddenFolders ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _showHiddenFolders = !_showHiddenFolders);
                    _loadFolders(_currentPath);
                  },
                ),
                IconButton(
                  tooltip: 'New Subfolder',
                  icon: const Icon(Icons.create_new_folder_outlined, color: AppTheme.primaryLight),
                  onPressed: _createNewFolder,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardDark),

          // Path Breadcrumbs
          PathBreadcrumbs(
            path: _currentPath,
            onPathSelected: (newPath) => _loadFolders(newPath),
          ),

          // Folder List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryViolet))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error loading folder: $_error',
                            style: const TextStyle(color: AppTheme.errorRed),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _folders.isEmpty
                        ? const Center(
                            child: Text(
                              'No subfolders in this directory',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemExtent: 62.0,
                            cacheExtent: 500.0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardDark),
                                ),
                                child: ListTile(
                                  onTap: () => _loadFolders(folder.path),
                                  leading: const Icon(
                                    Icons.folder_rounded,
                                    color: AppTheme.warningAmber,
                                    size: 24,
                                  ),
                                  title: Text(
                                    folder.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Bottom Action Bar to Confirm Selection
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceDark,
                border: Border(top: BorderSide(color: AppTheme.cardDark)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_currentPath),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    'Select "${_currentPath == '/' ? '/' : _currentPath.split('/').last}" As Destination',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryViolet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
