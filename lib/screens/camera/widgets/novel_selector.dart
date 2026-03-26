import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';

class NovelSelector extends StatelessWidget {
  final List<Novel> novels;
  final Novel? selectedNovel;
  final ValueChanged<Novel> onNovelSelected;
  final VoidCallback onNewNovel;

  const NovelSelector({
    super.key,
    required this.novels,
    required this.selectedNovel,
    required this.onNovelSelected,
    required this.onNewNovel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PopupMenuButton<String>(
        color: CameraColors.linen,
        offset: const Offset(0, 42),
        onSelected: (value) {
          if (value == '_new_novel_') {
            onNewNovel();
          } else {
            final novel = novels.firstWhere(
              (n) => n.id.toString() == value,
            );
            onNovelSelected(novel);
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];
          for (final novel in novels) {
            items.add(
              PopupMenuItem<String>(
                value: novel.id.toString(),
                child: Text(
                  novel.name,
                  style: TextStyle(
                    color: selectedNovel?.id == novel.id
                        ? Colors.black
                        : Colors.black54,
                    fontWeight: selectedNovel?.id == novel.id
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }
          if (novels.isNotEmpty) {
            items.add(const PopupMenuDivider());
          }
          items.add(
            const PopupMenuItem<String>(
              value: '_new_novel_',
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.black54, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'New Novel...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
          return items;
        },
        child: Text(
          selectedNovel?.name ?? 'Select novel',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selectedNovel != null ? Colors.black87 : Colors.black38,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
