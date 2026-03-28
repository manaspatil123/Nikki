import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:nikki/core/constants/assets.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/screens/read_list/add_novel_dialog.dart';

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
    final cameraProvider = context.watch<CameraProvider>();
    final novels = cameraProvider.novels;

    return Scaffold(
      backgroundColor: CameraColors.linen,
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
                        color: CameraColors.linen,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: CameraColors.linen,
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
                            const Expanded(
                              child: Text(
                                'Read List',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: CameraColors.brown,
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
                      ? const Center(
                          child: Text(
                            'No novels yet.\nTap "Add new" to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: CameraColors.brown,
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
  final VoidCallback? onEdit;
  final VoidCallback? onRead;

  const _NovelCard({required this.novel, this.onEdit, this.onRead});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
                      border: Border.all(color: CameraColors.brown, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: CameraColors.brown,
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
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
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
              style: const TextStyle(
                fontSize: 12,
                color: CameraColors.brown,
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
