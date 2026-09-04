import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sftp_client/src/providers/local_storage_provider.dart';
import 'package:sftp_client/src/providers/sftp_provider.dart';
import 'package:sftp_client/src/providers/transfer_provider.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';
import 'package:sftp_client/src/screens/transfer_manager_screen.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/widgets/create_folder_dialog.dart';
import 'package:sftp_client/src/widgets/destination_picker_dialog.dart';
import 'package:sftp_client/src/widgets/file_grid_tile.dart';
import 'package:sftp_client/src/widgets/file_tile.dart';
import 'package:sftp_client/src/widgets/path_breadcrumbs.dart';
import 'package:sftp_client/src/widgets/transfer_bar.dart';

class FileBrowserScreen extends ConsumerStatefulWidget {
  final VoidCallback onDisconnect;

  const FileBrowserScreen({super.key, required this.onDisconnect});

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;
  bool _showHiddenFiles = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showTransferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransferManagerSheet(),
    );
  }

  Future<void> _createNewFolderInCurrentTab() async {
    final folderName = await showCreateFolderDialog(context);
    if (folderName != null && folderName.trim().isNotEmpty) {
      if (_tabController.index == 0) {
        await ref.read(sftpProvider.notifier).createFolder(folderName);
      } else {
        await ref.read(localStorageProvider.notifier).createFolder(folderName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sftpState = ref.watch(sftpProvider);
    final localState = ref.watch(localStorageProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_tabController.index == 0) {
          // Remote SFTP Tab Navigation
          if (sftpState.currentPath != '/' && sftpState.currentPath.isNotEmpty) {
            await ref.read(sftpProvider.notifier).navigateUp();
            return;
          }
        } else {
          // Local Storage Tab Navigation
          if (localState.currentPath.isNotEmpty) {
            final parent = Directory(localState.currentPath).parent.path;
            if (parent != localState.currentPath &&
                parent.isNotEmpty &&
                parent != '/') {
              await ref.read(localStorageProvider.notifier).navigateUp();
              return;
            }
          }
        }

        // At root directory level: confirm before exit
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit app'),
                backgroundColor: AppTheme.surfaceDark,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Exit App
        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sftpState.activeHost != null
                    ? '${sftpState.activeUser}@${sftpState.activeHost}'
                    : 'SFTP File Manager',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Connected (SSH/SFTP)',
                    style: TextStyle(fontSize: 11, color: AppTheme.successGreen),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, color: AppTheme.primaryLight),
              tooltip: 'New Folder',
              onPressed: _createNewFolderInCurrentTab,
            ),

            // Grouped AppBar Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.primaryLight),
              tooltip: 'Options',
              color: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.cardDark),
              ),
              onSelected: (val) async {
                switch (val) {
                  case 'toggle_view':
                    setState(() => _isGridView = !_isGridView);
                    break;
                  case 'toggle_hidden':
                    setState(() => _showHiddenFiles = !_showHiddenFiles);
                    break;
                  case 'sort_name':
                    if (_tabController.index == 0) {
                      ref.read(sftpProvider.notifier).setSortBy(SortBy.name);
                    } else {
                      ref.read(localStorageProvider.notifier).setSortBy(SortBy.name);
                    }
                    break;
                  case 'sort_date':
                    if (_tabController.index == 0) {
                      ref.read(sftpProvider.notifier).setSortBy(SortBy.date);
                    } else {
                      ref.read(localStorageProvider.notifier).setSortBy(SortBy.date);
                    }
                    break;
                  case 'sort_size':
                    if (_tabController.index == 0) {
                      ref.read(sftpProvider.notifier).setSortBy(SortBy.size);
                    } else {
                      ref.read(localStorageProvider.notifier).setSortBy(SortBy.size);
                    }
                    break;
                  case 'refresh':
                    if (_tabController.index == 0) {
                      ref.read(sftpProvider.notifier).loadDirectory(sftpState.currentPath);
                    } else {
                      ref.read(localStorageProvider.notifier).loadDirectory(localState.currentPath);
                    }
                    break;
                  case 'disconnect':
                    await ref.read(sftpProvider.notifier).disconnect();
                    widget.onDisconnect();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_view',
                  child: Row(
                    children: [
                      Icon(
                        _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        color: AppTheme.primaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isGridView ? 'List View' : 'Grid View',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_hidden',
                  child: Row(
                    children: [
                      Icon(
                        _showHiddenFiles ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppTheme.accentCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _showHiddenFiles ? 'Hide Hidden Files' : 'Show Hidden Files',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  enabled: false,
                  height: 28,
                  child: Text(
                    'SORT BY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'sort_name',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha_rounded, color: AppTheme.textSecondary, size: 18),
                      SizedBox(width: 12),
                      Text('Name', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sort_date',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: AppTheme.textSecondary, size: 18),
                      SizedBox(width: 12),
                      Text('Date Modified', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sort_size',
                  child: Row(
                    children: [
                      Icon(Icons.data_usage_rounded, color: AppTheme.textSecondary, size: 18),
                      SizedBox(width: 12),
                      Text('Size', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, color: AppTheme.primaryLight, size: 20),
                      SizedBox(width: 12),
                      Text('Refresh Folder', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.power_settings_new_rounded, color: AppTheme.errorRed, size: 20),
                      SizedBox(width: 12),
                      Text('Disconnect', style: TextStyle(color: AppTheme.errorRed, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryViolet,
            indicatorWeight: 3,
            labelColor: AppTheme.primaryLight,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(
                icon: Icon(Icons.cloud_rounded, size: 20),
                text: 'Remote Server',
              ),
              Tab(
                icon: Icon(Icons.phone_android_rounded, size: 20),
                text: 'Local Storage',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filter / Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Filter files in current folder...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Remote Tab
                    _buildFilePane(
                      path: sftpState.currentPath,
                      files: sftpState.files,
                      isRemote: true,
                      errorMessage: sftpState.errorMessage,
                      onPathSelected: (p) => ref.read(sftpProvider.notifier).navigateTo(p),
                      onItemTap: (item) {
                        if (item.isDir) {
                          ref.read(sftpProvider.notifier).navigateTo(item.path);
                        }
                      },
                      onTransfer: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: false,
                          initialPath: localState.currentPath,
                          title: 'Download "${item.name}" to Local',
                        );

                        if (dest == null) return;
                        ref.read(transferProvider.notifier).startDownload(
                              remotePath: item.path,
                              localPath: dest,
                              fileName: item.name,
                            );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Downloading "${item.name}" to $dest...'),
                            backgroundColor: AppTheme.surfaceDark,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onCopy: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: true,
                          initialPath: sftpState.currentPath,
                          title: 'Copy "${item.name}" to Remote Folder',
                        );
                        if (dest == null) return;
                        final ok = await ref.read(sftpProvider.notifier).copyItem(item, dest);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Copied "${item.name}" to $dest')),
                          );
                        }
                      },
                      onMove: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: true,
                          initialPath: sftpState.currentPath,
                          title: 'Move "${item.name}" to Remote Folder',
                        );
                        if (dest == null) return;
                        final ok = await ref.read(sftpProvider.notifier).moveItem(item, dest);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Moved "${item.name}" to $dest')),
                          );
                        }
                      },
                      onDelete: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref.read(sftpProvider.notifier).deleteItem(item);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Deleted "${item.name}"')),
                          );
                        }
                      },
                      onRename: (item) async {
                        final newName = await showRenameDialog(context, item.name);
                        if (newName != null) {
                          await ref.read(sftpProvider.notifier).renameItem(item, newName);
                        }
                      },
                    ),

                    // Local Tab
                    _buildFilePane(
                      path: localState.currentPath,
                      files: localState.files,
                      isRemote: false,
                      errorMessage: localState.errorMessage,
                      onPathSelected: (p) => ref.read(localStorageProvider.notifier).navigateTo(p),
                      onItemTap: (item) {
                        if (item.isDir) {
                          ref.read(localStorageProvider.notifier).navigateTo(item.path);
                        }
                      },
                      onTransfer: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: true,
                          initialPath: sftpState.currentPath,
                          title: 'Upload "${item.name}" to Remote Server',
                        );

                        if (dest == null) return;
                        ref.read(transferProvider.notifier).startUpload(
                              localPath: item.path,
                              remotePath: dest,
                              fileName: item.name,
                            );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Uploading "${item.name}" to $dest...'),
                            backgroundColor: AppTheme.surfaceDark,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onCopy: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: false,
                          initialPath: localState.currentPath,
                          title: 'Copy "${item.name}" to Local Folder',
                        );
                        if (dest == null) return;
                        final ok = await ref.read(localStorageProvider.notifier).copyItem(item, dest);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Copied "${item.name}" to $dest')),
                          );
                        }
                      },
                      onMove: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final dest = await showDestinationFolderPicker(
                          context,
                          isRemote: false,
                          initialPath: localState.currentPath,
                          title: 'Move "${item.name}" to Local Folder',
                        );
                        if (dest == null) return;
                        final ok = await ref.read(localStorageProvider.notifier).moveItem(item, dest);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Moved "${item.name}" to $dest')),
                          );
                        }
                      },
                      onDelete: (item) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref.read(localStorageProvider.notifier).deleteItem(item);
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Deleted "${item.name}"')),
                          );
                        }
                      },
                      onRename: (item) async {
                        final newName = await showRenameDialog(context, item.name);
                        if (newName != null) {
                          await ref.read(localStorageProvider.notifier).renameItem(item, newName);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Floating Transfer Bar
              TransferBar(onTap: _showTransferSheet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePane({
    required String path,
    required List<FileNode> files,
    required bool isRemote,
    required String? errorMessage,
    required ValueChanged<String> onPathSelected,
    required ValueChanged<FileNode> onItemTap,
    required ValueChanged<FileNode> onTransfer,
    required ValueChanged<FileNode> onCopy,
    required ValueChanged<FileNode> onMove,
    required ValueChanged<FileNode> onDelete,
    required ValueChanged<FileNode> onRename,
  }) {
    final filtered = files.where((f) {
      if (!_showHiddenFiles && f.name.startsWith('.')) return false;
      if (_searchQuery.isNotEmpty && !f.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Path Breadcrumb Navigation
        PathBreadcrumbs(path: path, onPathSelected: onPathSelected),

        if (errorMessage != null && errorMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppTheme.errorRed.withValues(alpha: 0.15),
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 54,
                        color: AppTheme.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty ? 'No matching files found' : 'Folder is empty',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : _isGridView
                  ? GridView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      cacheExtent: 600.0,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return FileGridTile(
                          item: item,
                          isRemote: isRemote,
                          onTap: () => onItemTap(item),
                          onTransfer: () => onTransfer(item),
                          onCopy: () => onCopy(item),
                          onMove: () => onMove(item),
                          onDelete: () => onDelete(item),
                          onRename: () => onRename(item),
                        );
                      },
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      itemExtent: 74.0,
                      cacheExtent: 600.0,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return FileTile(
                          item: item,
                          isRemote: isRemote,
                          onTap: () => onItemTap(item),
                          onTransfer: () => onTransfer(item),
                          onCopy: () => onCopy(item),
                          onMove: () => onMove(item),
                          onDelete: () => onDelete(item),
                          onRename: () => onRename(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
