import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/core/constants/languages.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/models/explanation_category.dart';
import 'package:nikki/models/novel.dart';

class AddNovelDialog extends StatefulWidget {
  final Future<void> Function(String name, String sourceLanguage, String description) onCreate;
  /// If provided, dialog is in edit mode.
  final Novel? editNovel;
  final Future<void> Function(Novel updated)? onUpdate;
  final Future<void> Function()? onDelete;

  const AddNovelDialog({
    super.key,
    required this.onCreate,
    this.editNovel,
    this.onUpdate,
    this.onDelete,
  });

  @override
  State<AddNovelDialog> createState() => _AddNovelDialogState();
}

class _AddNovelDialogState extends State<AddNovelDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedLanguage = 'Japanese';
  bool _advancedOpen = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.editNovel != null;

  final Set<ExplanationCategory> _enabledCategories =
      Set.of(ExplanationCategory.values);
  String _proficiency = 'N3';
  String _detailLevel = 'Detailed';

  static const _proficiencyLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const _detailLevels = [
    'Very Brief',
    'Brief',
    'Medium',
    'Detailed',
    'Very Detailed',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editNovel != null) {
      _titleController.text = widget.editNovel!.name;
      _descController.text = widget.editNovel!.description;
      _selectedLanguage = widget.editNovel!.sourceLanguage;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _titleController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    if (_isEditMode) {
      final updated = widget.editNovel!.copyWith(
        name: name,
        description: _descController.text.trim(),
      );
      await widget.onUpdate?.call(updated);
    } else {
      await widget.onCreate(name, _selectedLanguage, _descController.text.trim());
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    setState(() => _isSaving = true);
    await widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: colors.overlay,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditMode ? 'Edit Book' : "What's your next read?",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.textSecondary, width: 1.5),
                          ),
                          child: Icon(Icons.close, size: 16, color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Scrollable form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Book Title *'),
                        const SizedBox(height: 6),
                        _InputField(
                          controller: _titleController,
                          hint: 'Enter the book title',
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel('Description'),
                        const SizedBox(height: 6),
                        _InputField(
                          controller: _descController,
                          hint: 'A short description (optional)',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel('Language of the book *'),
                        const SizedBox(height: 6),
                        _LanguageDropdown(
                          value: _selectedLanguage,
                          enabled: !_isEditMode,
                          onChanged: (lang) => setState(() => _selectedLanguage = lang),
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel('Cover Images'),
                        const SizedBox(height: 6),
                        _ImageSelectPlaceholder(),
                        const SizedBox(height: 20),

                        // Advanced settings
                        GestureDetector(
                          onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                          child: Row(
                            children: [
                              Icon(
                                _advancedOpen ? Icons.expand_less : Icons.expand_more,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Advanced Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_advancedOpen) ...[
                          const SizedBox(height: 12),
                          _AdvancedSection(
                            enabledCategories: _enabledCategories,
                            onCategoryToggle: (cat) {
                              setState(() {
                                if (_enabledCategories.contains(cat)) {
                                  _enabledCategories.remove(cat);
                                } else {
                                  _enabledCategories.add(cat);
                                }
                              });
                            },
                            proficiency: _proficiency,
                            onProficiencyChanged: (v) => setState(() => _proficiency = v),
                            detailLevel: _detailLevel,
                            onDetailLevelChanged: (v) => setState(() => _detailLevel = v),
                            selectedLanguage: _selectedLanguage,
                            proficiencyLevels: _proficiencyLevels,
                            detailLevels: _detailLevels,
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      // Save / Create button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _isSaving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: CameraColors.teal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isEditMode ? 'Save Changes' : 'Create',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Delete button (edit mode only)
                      if (_isEditMode) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _isSaving ? null : _delete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: CameraColors.dangerBorder,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Delete Book',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field widgets ──

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15, color: colors.textPrimary),
      cursorColor: CameraColors.teal,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.5)),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CameraColors.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _LanguageDropdown({required this.value, this.enabled = true, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
        ),
        child: IgnorePointer(
          ignoring: !enabled,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: colors.textSecondary),
              dropdownColor: colors.background,
              style: TextStyle(fontSize: 15, color: colors.textPrimary),
              items: Languages.cameraSourceLanguages
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSelectPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Row(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () {
              // TODO: image picker
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.inputBorder),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: colors.textSecondary.withOpacity(0.4),
                size: 28,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Advanced settings ──

class _AdvancedSection extends StatelessWidget {
  final Set<ExplanationCategory> enabledCategories;
  final ValueChanged<ExplanationCategory> onCategoryToggle;
  final String proficiency;
  final ValueChanged<String> onProficiencyChanged;
  final String detailLevel;
  final ValueChanged<String> onDetailLevelChanged;
  final String selectedLanguage;
  final List<String> proficiencyLevels;
  final List<String> detailLevels;

  const _AdvancedSection({
    required this.enabledCategories,
    required this.onCategoryToggle,
    required this.proficiency,
    required this.onProficiencyChanged,
    required this.detailLevel,
    required this.onDetailLevelChanged,
    required this.selectedLanguage,
    required this.proficiencyLevels,
    required this.detailLevels,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Include in explanations'),
        const SizedBox(height: 4),
        ...ExplanationCategory.values.map((cat) {
          return GestureDetector(
            onTap: () => onCategoryToggle(cat),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    enabledCategories.contains(cat)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: enabledCategories.contains(cat)
                        ? CameraColors.teal
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat.displayName,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _FieldLabel("What's your current understanding of $selectedLanguage?"),
        const SizedBox(height: 6),
        _SmallDropdown(value: proficiency, items: proficiencyLevels, onChanged: onProficiencyChanged),
        const SizedBox(height: 16),
        const _FieldLabel('How detailed do you want your explanations?'),
        const SizedBox(height: 6),
        _SmallDropdown(value: detailLevel, items: detailLevels, onChanged: onDetailLevelChanged),
      ],
    );
  }
}

class _SmallDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SmallDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textSecondary),
          dropdownColor: colors.background,
          style: TextStyle(fontSize: 14, color: colors.textPrimary),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
