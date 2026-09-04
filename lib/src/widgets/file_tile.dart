import 'package:flutter/material.dart';
import 'package:sftp_client/src/rust/api/file_system.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/utils/formatters.dart';

class FileTile extends StatelessWidget {
  final FileNode item;
  final bool isRemote;
  final VoidCallback onTap;
  final VoidCallback onTransfer; // Upload if local, Download if remote
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  const FileTile({
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardDark),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          title: Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                if (!item.isDir) ...[
                  Text(
                    Formatters.formatBytes(item.size.toInt()),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(width: 6),
                ],
                Text(
                  Formatters.formatDate(item.modifiedTimestamp),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
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
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(isRemote ? 'Download to Phone...' : 'Upload to Server...'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 20),
                    const SizedBox(width: 12),
                    Text('Copy to...'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outlined, color: AppTheme.warningAmber, size: 20),
                    const SizedBox(width: 12),
                    Text('Move to...'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
