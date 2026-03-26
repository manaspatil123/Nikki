import 'dart:io' show File;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/services/apple_ocr_service.dart';
import 'package:nikki/widgets/text_overlay.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final AppleOcrService _ocrService = AppleOcrService();
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;
  bool _isShowingExplanation = false;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permissionGranted = true);
      await _initCamera();
    } else {
      setState(() {
        _permissionPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (_permissionGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    _selectedCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);

    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;

      final cameraProvider = context.read<CameraProvider>();
      final result = await _ocrService.processImageFile(
        xFile.path,
        cameraProvider.sourceLanguage,
      );
      if (!mounted) return;

      cameraProvider.onPictureTaken(
        xFile.path,
        result.blocks,
        result.width,
        result.height,
      );
    } catch (e) {
      debugPrint('Take picture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  void _retake() {
    context.read<CameraProvider>().retake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      if (!_permissionGranted) {
        _checkCurrentStatus();
      } else {
        _initCamera();
      }
    }
  }

  void _onTextSelected(String selectedText, String blockText) {
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.onTextSelected(selectedText, blockText);
    _showExplanationSheet();
  }

  void _showExplanationSheet() {
    if (_isShowingExplanation) return;
    _isShowingExplanation = true;

    final cameraProvider = context.read<CameraProvider>();
    final explanationProvider = context.read<ExplanationProvider>();
    final selectedWord = cameraProvider.selectedWord;

    if (selectedWord == null) {
      _isShowingExplanation = false;
      return;
    }

    explanationProvider.explain(
      selectedText: selectedWord.text,
      surroundingContext: selectedWord.surroundingContext,
      sourceLanguage: cameraProvider.sourceLanguage,
      targetLanguage: cameraProvider.targetLanguage,
      novelId: cameraProvider.selectedNovel?.id,
      dontSave: cameraProvider.dontSave,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.15,
          maxChildSize: 0.45,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<ExplanationProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Selected word title
                      Text(
                        provider.selectedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Content
                      if (provider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error: ${provider.error}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else if (provider.explanation != null) ...[
                        if (provider.explanation!.reading != null)
                          _explanationRow(
                            'Reading',
                            provider.explanation!.reading!,
                          ),
                        if (provider.explanation!.meaning != null)
                          _explanationRow(
                            'Meaning',
                            provider.explanation!.meaning!,
                          ),
                        if (provider.explanation!.context != null)
                          _explanationRow(
                            'In Context',
                            provider.explanation!.context!,
                          ),
                        if (provider.explanation!.breakdown != null)
                          _explanationRow(
                            'Breakdown',
                            provider.explanation!.breakdown!,
                          ),
                        if (provider.explanation!.similarWords != null &&
                            provider.explanation!.similarWords!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Similar Words',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...provider.explanation!.similarWords!.map(
                            (sw) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: GestureDetector(
                                onTap: () {
                                  provider.compare(
                                    originalWord: provider.selectedText,
                                    similarWord: sw,
                                    sourceLanguage:
                                        cameraProvider.sourceLanguage,
                                    targetLanguage:
                                        cameraProvider.targetLanguage,
                                  );
                                },
                                child: Text(
                                  '${sw.word} - ${sw.brief}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Comparison section
                        if (provider.showComparison) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),
                          if (provider.isComparisonLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (provider.comparisonError != null)
                            Text(
                              'Comparison error: ${provider.comparisonError}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            )
                          else if (provider.comparison != null)
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Comparing: ${provider.selectedText} vs ${provider.comparisonTarget?.word ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${provider.comparison!.difference}\n\n${provider.comparison!.nuance}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      _isShowingExplanation = false;
      if (mounted) {
        context.read<CameraProvider>().dismissExplanation();
        context.read<ExplanationProvider>().reset();
      }
    });
  }

  Widget _explanationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewNovelDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text(
            'New Novel',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Novel name',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
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
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _permissionPermanentlyDenied
                      ? 'Camera permission is permanently denied.\nPlease enable it in Settings.'
                      : 'Camera permission is required to scan text.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _permissionPermanentlyDenied
                      ? () => openAppSettings()
                      : _requestPermissionAndInit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: Text(
                    _permissionPermanentlyDenied
                        ? 'Open Settings'
                        : 'Grant Permission',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, _) {
          // Guard against disposed controller during rebuild
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview — always rendered to avoid flash on capture.
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              ),

              // Captured image + overlay layered on top.
              if (cameraProvider.isCaptured)
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(cameraProvider.capturedImagePath!),
                          fit: BoxFit.cover,
                        ),
                        TextOverlay(
                          blocks: cameraProvider.recognizedBlocks,
                          selectedWord: cameraProvider.selectedWord,
                          imageWidth: cameraProvider.imageWidth,
                          imageHeight: cameraProvider.imageHeight,
                          rotationDegrees: 0,
                          imagePath: cameraProvider.capturedImagePath,
                          onSelectionComplete: _onTextSelected,
                        ),
                      ],
                    ),
                  ),
                ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: Colors.black.withOpacity(0.5),
                    child: Row(
                      children: [
                        // "Translate from" language dropdown
                        PopupMenuButton<String>(
                          color: Colors.black,
                          offset: const Offset(0, 40),
                          onSelected: (value) {
                            cameraProvider.setSourceLanguage(value);
                          },
                          itemBuilder: (context) {
                            const languages = [
                              'Japanese',
                              'Chinese',
                              'Korean',
                              'English',
                              'French',
                              'German',
                              'Spanish',
                            ];
                            return languages.map((lang) {
                              final isSelected =
                                  cameraProvider.sourceLanguage == lang;
                              return PopupMenuItem<String>(
                                value: lang,
                                child: Text(
                                  lang,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cameraProvider.sourceLanguage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Novel selector
                        Flexible(
                          child: PopupMenuButton<String>(
                            color: Colors.black,
                            offset: const Offset(0, 40),
                            onSelected: (value) {
                              if (value == '_new_novel_') {
                                _showNewNovelDialog();
                              } else {
                                final novel =
                                    cameraProvider.novels.firstWhere(
                                  (n) => n.id.toString() == value,
                                );
                                cameraProvider.selectNovel(novel);
                              }
                            },
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<String>>[];
                              for (final novel in cameraProvider.novels) {
                                items.add(
                                  PopupMenuItem<String>(
                                    value: novel.id.toString(),
                                    child: Text(
                                      novel.name,
                                      style: TextStyle(
                                        color:
                                            cameraProvider.selectedNovel
                                                        ?.id ==
                                                    novel.id
                                                ? Colors.white
                                                : Colors.white70,
                                        fontWeight:
                                            cameraProvider.selectedNovel
                                                        ?.id ==
                                                    novel.id
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (cameraProvider.novels.isNotEmpty) {
                                items.add(const PopupMenuDivider());
                              }
                              items.add(
                                const PopupMenuItem<String>(
                                  value: '_new_novel_',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'New Novel...',
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              return items;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      cameraProvider.selectedNovel?.name ??
                                          'Select novel',
                                      style: TextStyle(
                                        color:
                                            cameraProvider.selectedNovel !=
                                                    null
                                                ? Colors.white
                                                : Colors.white54,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.black.withOpacity(0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Don't Save toggle
                        GestureDetector(
                          onTap: () => cameraProvider.toggleDontSave(),
                          child: Opacity(
                            opacity: cameraProvider.dontSave ? 0.5 : 1.0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cameraProvider.dontSave
                                      ? Icons.bookmark_remove_outlined
                                      : Icons.bookmark_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cameraProvider.dontSave
                                      ? 'Not Saving'
                                      : 'Saving',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Capture / Retake button
                        GestureDetector(
                          onTap: cameraProvider.isCaptured
                              ? _retake
                              : _takePicture,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cameraProvider.isCaptured
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: _isTakingPicture
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    cameraProvider.isCaptured
                                        ? Icons.refresh
                                        : Icons.camera_alt_outlined,
                                    color: cameraProvider.isCaptured
                                        ? Colors.black
                                        : Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),

                        // History button
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/history');
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
