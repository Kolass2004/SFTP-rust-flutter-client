import 'package:flutter/material.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/utils/formatters.dart';

class FileGridTile extends StatelessWidget {
  final FileNode item;
  final bool isRemote;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  const FileGridTile({
    super.key,
    required this.item,
    required this.isRemote,
    required this.onTap,
    required this.onTransfer,
    required this.onDelete,
    required this.onRename,
    required this.onCopy,
    required this.onMove,
  });

  IconData _getFileIcon(String name, bool isDir) {
    if (isDir) return Icons.folder_rounded;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'svg':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'avi':
        return Icons.movie_rounded;
      case 'mp3':
      case 'flac':
      case 'wav':
      case 'm4a':
      case 'ogg':
        return Icons.music_note_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'rs':
      case 'dart':
      case 'py':
      case 'js':
      case 'html':
      case 'json':
      case 'sh':
        return Icons.code_rounded;
      case 'apk':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getIconColor(String name, bool isDir) {
    if (isDir) return AppTheme.warningAmber;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return AppTheme.accentCyan;
      case 'mp4':
      case 'mkv':
      case 'mov':
        return AppTheme.primaryLight;
      case 'mp3':
      case 'flac':
      case 'wav':
        return Colors.pinkAccent;
      case 'zip':
      case 'tar':
      case 'gz':
        return Colors.orangeAccent;
      case 'rs':
      case 'dart':
      case 'py':
        return AppTheme.successGreen;
      case 'pdf':
        return AppTheme.errorRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getFileIcon(item.name, item.isDir);
    final iconColor = _getIconColor(item.name, item.isDir);

    return RepaintBoundary(
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardDark),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon & Context Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.surfaceDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.cardDark),
                    ),
                    onSelected: (val) {
                      switch (val) {
                        case 'transfer':
                          onTransfer();
                          break;
                        case 'copy':
                          onCopy();
                          break;
                        case 'move':
                          onMove();
                          break;
                        case 'rename':
                          onRename();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!item.isDir)
                        PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(
                                isRemote ? Icons.download_rounded : Icons.upload_rounded,
                                color: AppTheme.primaryLight,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isRemote ? 'Download...' : 'Upload...',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            const Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 18),
                            const SizedBox(width: 10),
                            const Text('Copy to...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            const Icon(Icons.drive_file_move_outlined, color: AppTheme.warningAmber, size: 18),
                            const SizedBox(width: 10),
                            const Text('Move to...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                            SizedBox(width: 10),
                            Text('Rename', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 18),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Middle: File Name
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),

              const SizedBox(height: 6),

              // Bottom: Subtitle info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.isDir ? 'Folder' : Formatters.formatBytes(item.size.toInt()),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  Text(
                    Formatters.formatDate(item.modifiedTimestamp).split(',').first,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
