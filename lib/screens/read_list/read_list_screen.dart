import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:nikki/core/constants/assets.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/screens/read_list/add_novel_dialog.dart';
import 'package:nikki/screens/novel_detail/novel_detail_screen.dart';
import 'package:nikki/theme/nikki_colors.dart';

class ReadListScreen extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onSettings;

  const ReadListScreen({super.key, this.onCamera, this.onSettings});

  void _showEditNovelDialog(BuildContext context, Novel novel) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddNovelDialog(
        editNovel: novel,
        onCreate: (_, __, ___) async {},
        onUpdate: (updated) async {
          final cameraProvider = context.read<CameraProvider>();
          await cameraProvider.updateNovel(updated);
        },
        onDelete: () async {
          final cameraProvider = context.read<CameraProvider>();
          await cameraProvider.deleteNovel(novel.id!);
        },
      ),
    );
  }

  void _showAddNovelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddNovelDialog(
        onCreate: (name, language, description) async {
          final cameraProvider = context.read<CameraProvider>();
          await cameraProvider.createNovelFull(name, language, description);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final cameraProvider = context.watch<CameraProvider>();
    final novels = cameraProvider.novels;

    return Scaffold(
      backgroundColor: colors.background,
        body: Stack(
          children: [
            Column(
              children: [
                // Top header
                AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark,
                  child: Column(
                    children: [
                      Container(
                        height: MediaQuery.of(context).padding.top,
                        color: colors.background,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: colors.background,
                        child: Row(
                          children: [
                            // Camera icon — left (just icon, no circle)
                            GestureDetector(
                              onTap: () {
                                context.read<CameraProvider>().deselectNovel();
                                if (onCamera != null) {
                                  onCamera!();
                                } else {
                                  Navigator.pushNamed(context, '/camera');
                                }
                              },
                              child: SvgPicture.asset(
                                Assets.coloredCaptureIcon,
                                width: 40,
                                height: 40
                              ),
                            ),

                            // Title — centered
                            Expanded(
                              child: Text(
                                'Read List',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),

                            // Settings button — right
                            GestureDetector(
                              onTap: onSettings ?? () => Navigator.pushNamed(context, '/settings'),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.textPrimary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.settings_outlined,
                                  color: colors.textSecondary,
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Novel list
                Expanded(
                  child: novels.isEmpty
                      ? Center(
                          child: Text(
                            'No novels yet.\nTap "Add new" to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: novels.length,
                          itemBuilder: (context, index) {
                            final novel = novels[index];
                            return _NovelCard(
                              novel: novel,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NovelDetailScreen(
                                    novel: novel,
                                    onStartReading: () {
                                      final cp = context.read<CameraProvider>();
                                      cp.selectNovel(novel);
                                      Navigator.pop(context); // pop novel detail
                                      if (onCamera != null) onCamera!();
                                    },
                                  ),
                                ),
                              ),
                              onEdit: () => _showEditNovelDialog(context, novel),
                              onRead: () {
                                final cp = context.read<CameraProvider>();
                                cp.selectNovel(novel);
                                if (onCamera != null) {
                                  onCamera!();
                                } else {
                                  Navigator.pushNamed(context, '/camera');
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),

            // Floating add button — bottom right
            Positioned(
              bottom: 0,
              right: 24,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () => _showAddNovelDialog(context),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CameraColors.teal,
                        border: Border.all(
                          color: Colors.grey,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 38,
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



class _NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRead;

  const _NovelCard({required this.novel, this.onTap, this.onEdit, this.onRead});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + edit button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    novel.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.textSecondary, width: 1.5),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: colors.textSecondary,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),

            // Description
            if (novel.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                novel.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Language
            Text(
              '${novel.sourceLanguage} → ${novel.targetLanguage}',
              style: const TextStyle(
                fontSize: 12,
                color: CameraColors.teal,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),

            // Created date
            Text(
              'Created on ${_formatDate(novel.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Bottom row: Read button right-aligned
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: CameraColors.teal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Read',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  static String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
