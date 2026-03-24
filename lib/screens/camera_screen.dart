import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/services/ocr_service.dart';
import 'package:nikki/widgets/text_overlay.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;
  bool _isShowingExplanation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
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
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    _startImageStream();
  }

  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final cameraProvider = context.read<CameraProvider>();
    _controller!.startImageStream((image) {
      if (_isProcessing || cameraProvider.isFrozen) return;
      _isProcessing = true;
      _processImage(image).then((_) {
        _isProcessing = false;
      });
    });
  }

  void _stopImageStream() {
    try {
      _controller?.stopImageStream();
    } catch (_) {
      // Stream may not be running
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_selectedCamera == null) return;

    final inputImage = _ocrService.buildInputImage(image, _selectedCamera!);
    if (inputImage == null) return;

    try {
      final blocks = await _ocrService.processImage(inputImage);
      if (!mounted) return;

      final cameraProvider = context.read<CameraProvider>();
      cameraProvider.onTextRecognized(
        blocks,
        image.width,
        image.height,
        _selectedCamera!.sensorOrientation,
      );
    } catch (e) {
      debugPrint('OCR processing error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopImageStream();
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _onWordSelected(RecognizedElement element, String blockText) {
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.onWordSelected(element, blockText);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
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
    );
    controller.dispose;
  }

  String _languageAbbreviation(String language) {
    switch (language.toLowerCase()) {
      case 'japanese':
        return 'JP';
      case 'english':
        return 'EN';
      case 'chinese':
        return 'ZH';
      case 'korean':
        return 'KR';
      case 'french':
        return 'FR';
      case 'german':
        return 'DE';
      case 'spanish':
        return 'ES';
      default:
        return language.substring(0, 2).toUpperCase();
    }
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
                      : _checkPermissionAndInit,
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
          return Stack(
            fit: StackFit.expand,
            children: [
              // Full screen camera preview
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),

              // Text overlay
              Positioned.fill(
                child: TextOverlay(
                  blocks: cameraProvider.recognizedBlocks,
                  selectedWord: cameraProvider.selectedWord,
                  imageWidth: cameraProvider.imageWidth,
                  imageHeight: cameraProvider.imageHeight,
                  rotationDegrees: cameraProvider.rotationDegrees,
                  onElementTapped: _onWordSelected,
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
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.black.withOpacity(0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Source language chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _languageAbbreviation(
                              cameraProvider.sourceLanguage,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

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
                                          'Tap to add novel',
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

                        // Target language chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _languageAbbreviation(
                              cameraProvider.targetLanguage,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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

                        // Freeze button
                        GestureDetector(
                          onTap: () {
                            cameraProvider.toggleFreeze();
                            if (cameraProvider.isFrozen) {
                              _stopImageStream();
                            } else {
                              _startImageStream();
                            }
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cameraProvider.isFrozen
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              cameraProvider.isFrozen
                                  ? Icons.play_arrow
                                  : Icons.camera_alt_outlined,
                              color: cameraProvider.isFrozen
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
