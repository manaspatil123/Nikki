import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';

/// Theme-aware colors that change between light and dark mode.
/// Access via `NikkiColors.of(context)`.
///
/// Accent colors that stay the same in both modes live in [CameraColors].
class NikkiColors extends ThemeExtension<NikkiColors> {
  /// Scaffold / page background.
  final Color background;

  /// Card / input / item background.
  final Color card;

  /// Primary text color (headings, body).
  final Color textPrimary;

  /// Secondary/muted text color (labels, dates, hints).
  final Color textSecondary;

  /// Divider / separator lines.
  final Color divider;

  /// Input field fill color.
  final Color inputFill;

  /// Input field border color.
  final Color inputBorder;

  /// Drag handle bar color.
  final Color handle;

  /// Dialog / sheet background.
  final Color dialogBg;

  /// Dialog overlay (semi-transparent backdrop).
  final Color overlay;

  /// Icon color for general UI icons.
  final Color icon;

  /// Hint text in inputs.
  final Color hint;

  const NikkiColors({
    required this.background,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.inputFill,
    required this.inputBorder,
    required this.handle,
    required this.dialogBg,
    required this.overlay,
    required this.icon,
    required this.hint,
  });

  /// Convenience accessor.
  static NikkiColors of(BuildContext context) {
    return Theme.of(context).extension<NikkiColors>()!;
  }

  static const light = NikkiColors(
    background: CameraColors.linen,
    card: Colors.white,
    textPrimary: Colors.black,
    textSecondary: CameraColors.brown,
    divider: CameraColors.caramel,
    inputFill: Colors.white,
    inputBorder: CameraColors.caramel,
    handle: CameraColors.caramel,
    dialogBg: CameraColors.linen,
    overlay: Colors.black54,
    icon: CameraColors.brown,
    hint: Color(0x80664C36), // brown at 50%
  );

  static const dark = NikkiColors(
    background: Color(0xFF121212),
    card: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: CameraColors.caramel,
    divider: Color(0xFF3A3A3A),
    inputFill: Color(0xFF2A2A2A),
    inputBorder: Color(0xFF3A3A3A),
    handle: Color(0xFF555555),
    dialogBg: Color(0xFF181818),
    overlay: Colors.black87,
    icon: CameraColors.caramel,
    hint: Color(0x80EAC096), // caramel at 50%
  );

  @override
  NikkiColors copyWith({
    Color? background, Color? card, Color? textPrimary, Color? textSecondary,
    Color? divider, Color? inputFill, Color? inputBorder, Color? handle,
    Color? dialogBg, Color? overlay, Color? icon, Color? hint,
  }) {
    return NikkiColors(
      background: background ?? this.background,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      handle: handle ?? this.handle,
      dialogBg: dialogBg ?? this.dialogBg,
      overlay: overlay ?? this.overlay,
      icon: icon ?? this.icon,
      hint: hint ?? this.hint,
    );
  }

  @override
  NikkiColors lerp(NikkiColors? other, double t) {
    if (other == null) return this;
    return NikkiColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      handle: Color.lerp(handle, other.handle, t)!,
      dialogBg: Color.lerp(dialogBg, other.dialogBg, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
    );
  }
}
