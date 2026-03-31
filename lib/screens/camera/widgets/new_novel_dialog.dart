import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/theme/nikki_colors.dart';

Future<void> showNewNovelDialog(BuildContext context) async {
  final colors = NikkiColors.of(context);
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.divider),
        ),
        title: Text(
          'New Novel',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Novel name',
            hintStyle: TextStyle(color: colors.hint),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.icon),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<CameraProvider>().createNovel(name);
                Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
        ],
      );
    },
  );
  controller.dispose();
}
