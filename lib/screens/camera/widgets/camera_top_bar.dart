import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nikki/core/constants/assets.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/screens/camera/widgets/language_dropdown.dart';

class CameraTopBar extends StatelessWidget {
  final String sourceLanguage;
  final Novel? selectedNovel;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onArrowTap;

  const CameraTopBar({
    super.key,
    required this.sourceLanguage,
    required this.selectedNovel,
    required this.onLanguageChanged,
    required this.onArrowTap,
  });

  @override
  Widget build(BuildContext context) {
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
              color: CameraColors.linen,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: CameraColors.linen,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LanguageDropdown(
                    sourceLanguage: sourceLanguage,
                    onLanguageChanged: onLanguageChanged,
                  ),
                  // Novel name (or empty)
                  Expanded(
                    child: Text(
                      selectedNovel?.name ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selectedNovel != null ? Colors.black87 : Colors.transparent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
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
