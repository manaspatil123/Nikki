import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/core/constants/languages.dart';

class LanguageDropdown extends StatefulWidget {
  final String sourceLanguage;
  final ValueChanged<String> onLanguageChanged;

  const LanguageDropdown({
    super.key,
    required this.sourceLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: PopupMenuButton<String>(
        color: CameraColors.linen,
        offset: const Offset(0, 53),
        onOpened: () => setState(() => _isOpen = true),
        onCanceled: () => setState(() => _isOpen = false),
        onSelected: (value) {
          setState(() => _isOpen = false);
          widget.onLanguageChanged(value);
        },
        itemBuilder: (context) {
          return Languages.cameraSourceLanguages.map((lang) {
            final isSelected = widget.sourceLanguage == lang;
            return PopupMenuItem<String>(
              padding: EdgeInsets.zero,
              value: lang,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(
                          color: CameraColors.brown,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  Languages.nativeName(lang),
                  style: TextStyle(
                    color: isSelected ? CameraColors.brown : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList();
        },
        child: Material(
          color: _isOpen ? CameraColors.darkTeal : CameraColors.teal,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            onTap: null,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isOpen ? CameraColors.teal : CameraColors.darkTeal,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                Languages.nativeName(widget.sourceLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
