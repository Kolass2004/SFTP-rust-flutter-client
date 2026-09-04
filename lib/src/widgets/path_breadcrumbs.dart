import 'package:flutter/material.dart';
import 'package:sftp_client/src/theme/app_theme.dart';

class PathBreadcrumbs extends StatefulWidget {
  final String path;
  final ValueChanged<String> onPathSelected;

  const PathBreadcrumbs({
    super.key,
    required this.path,
    required this.onPathSelected,
  });

  @override
  State<PathBreadcrumbs> createState() => _PathBreadcrumbsState();
}

class _PathBreadcrumbsState extends State<PathBreadcrumbs> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant PathBreadcrumbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanPath = widget.path.replaceAll('\\', '/');
    final rawParts = cleanPath.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 48,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(bottom: BorderSide(color: AppTheme.cardDark, width: 1)),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Root / Home Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onPathSelected('/'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: rawParts.isEmpty
                        ? AppTheme.primaryViolet.withValues(alpha: 0.25)
                        : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rawParts.isEmpty
                          ? AppTheme.primaryViolet
                          : AppTheme.cardDark,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.home_rounded,
                        size: 16,
                        color: rawParts.isEmpty
                            ? AppTheme.primaryLight
                            : AppTheme.accentCyan,
                      ),
                      if (rawParts.isEmpty) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Root',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Path Segments
            for (int i = 0; i < rawParts.length; i++) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
              Builder(
                builder: (context) {
                  final isLast = i == rawParts.length - 1;
                  final targetPath = '/' + rawParts.sublist(0, i + 1).join('/');

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onPathSelected(targetPath),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLast
                              ? AppTheme.primaryViolet.withValues(alpha: 0.2)
                              : AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLast
                                ? AppTheme.primaryViolet.withValues(alpha: 0.6)
                                : AppTheme.cardDark,
                          ),
                        ),
                        child: Text(
                          rawParts[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                            color: isLast ? AppTheme.primaryLight : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
