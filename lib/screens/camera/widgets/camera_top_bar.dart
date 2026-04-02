import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nikki/core/constants/assets.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/screens/camera/widgets/language_dropdown.dart';

class CameraTopBar extends StatelessWidget {
  final String sourceLanguage;
  final Novel? selectedNovel;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onArrowTap;
  final VoidCallback? onNovelTap;

  const CameraTopBar({
    super.key,
    required this.sourceLanguage,
    required this.selectedNovel,
    required this.onLanguageChanged,
    required this.onArrowTap,
    this.onNovelTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: colors.background,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.background,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LanguageDropdown(
                    sourceLanguage: sourceLanguage,
                    onLanguageChanged: onLanguageChanged,
                  ),
                  // Novel name (tappable → navigate to novel detail)
                  Expanded(
                    child: GestureDetector(
                      onTap: selectedNovel != null ? onNovelTap : null,
                      child: Text(
                        selectedNovel?.name ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selectedNovel != null ? colors.textPrimary : Colors.transparent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Back to read list
                  GestureDetector(
                    onTap: onArrowTap,
                    child: SvgPicture.asset(
                      Assets.rightArrow,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        CameraColors.darkTeal,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
