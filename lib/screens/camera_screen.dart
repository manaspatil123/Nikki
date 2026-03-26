import 'dart:async';
import 'dart:io' show File;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  bool _langDropdownOpen = false;

  // Camera idle sleep — stops camera after inactivity to save battery.
  static const _idleTimeout = Duration(seconds: 8);
  static const _motionThreshold = 0.3; // m/s² change to count as movement
  bool _cameraSleeping = false;
  Timer? _idleTimer;
  StreamSubscription<dynamic>? _accelSub;
  double _lastAccelMag = 0;

  /// Path to the last frame snapshot — shown blurred when camera sleeps
  /// or during retake while camera re-initializes.
  String? _lastFramePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatus();
    _startMotionDetection();
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
    _cameraSleeping = false;
    _resetIdleTimer();
    setState(() {});
  }

  /// Stop the camera hardware. Does NOT setState — caller is responsible.
  void _stopCamera() {
    _idleTimer?.cancel();
    _controller?.dispose();
    _controller = null;
  }

  /// Put camera to sleep — just stop it, no snapshot (avoids flash).
  void _sleepCamera() {
    if (_cameraSleeping || _controller == null) return;
    debugPrint('Camera: sleeping (idle timeout)');
    _stopCamera();
    if (mounted) setState(() => _cameraSleeping = true);
  }

  /// Wake camera from sleep on motion or touch.
  Future<void> _wakeCamera() async {
    if (!_cameraSleeping || !_permissionGranted) return;
    debugPrint('Camera: waking up');
    setState(() => _cameraSleeping = false);
    await _initCamera();
  }

  // ── Motion detection ──────────────────────────────────────────────

  void _startMotionDetection() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 500),
      ).handleError((_) {
        // Stream activation failed (MissingPluginException on hot reload).
        debugPrint('Accelerometer stream error, using touch-only idle');
        _accelSub?.cancel();
        _accelSub = null;
      }).listen((event) {
        final mag =
            sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final delta = (mag - _lastAccelMag).abs();
        _lastAccelMag = mag;

        if (delta > _motionThreshold) {
          _onActivity();
        }
      });
    } catch (_) {
      debugPrint('Accelerometer init failed, using touch-only idle');
    }
  }

  /// Called on any motion or touch — resets the idle timer or wakes camera.
  void _onActivity() {
    if (_cameraSleeping) {
      _wakeCamera();
    } else {
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final cameraProvider = context.read<CameraProvider>();
    if (cameraProvider.isCaptured) return;
    _idleTimer = Timer(_idleTimeout, _sleepCamera);
  }

  /// Delete a temporary image file if it exists.
  void _deleteTempFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  // ── Capture / Retake ──────────────────────────────────────────────

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    // Clear old frame so the previous image doesn't flash on screen.
    _deleteTempFile(_lastFramePath);
    _lastFramePath = null;
    setState(() => _isTakingPicture = true);
    _idleTimer?.cancel();

    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;

      _lastFramePath = xFile.path;
      setState(() {}); // show the new captured image as background

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

      // Now that the captured image is on screen, stop the camera.
      _stopCamera();
      if (mounted) setState(() {});
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
    final cameraProvider = context.read<CameraProvider>();
    final oldPath = cameraProvider.capturedImagePath;
    // Use the captured image as blurred background during camera init.
    _lastFramePath = oldPath;
    cameraProvider.retake();
    _initCamera();
    // Delete the old capture after camera is ready (async, non-blocking).
    Future.delayed(const Duration(seconds: 2), () => _deleteTempFile(oldPath));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _idleTimer?.cancel();
      _stopCamera();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      final cameraProvider = context.read<CameraProvider>();
      if (!_permissionGranted) {
        _checkCurrentStatus();
      } else if (!cameraProvider.isCaptured) {
        // Only restart camera if we're on live preview, not reading.
        _cameraSleeping = false;
        _initCamera();
      }
    }
  }

  static String _nativeLanguageName(String language) {
    const map = {
      'Japanese': '日本語',
      'Chinese': '中文',
      'Korean': '한국어',
      'English': 'English',
      'French': 'Français',
      'German': 'Deutsch',
      'Spanish': 'Español',
    };
    return map[language] ?? language;
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
    _idleTimer?.cancel();
    _accelSub?.cancel();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, _) {
          final controller = _controller;
          final cameraReady =
              controller != null && controller.value.isInitialized;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 0: Last frame — shown during capture (hides iOS
              // shutter flash), during retake/wake (hides init delay).
              // Blurred when not capturing, sharp when capturing.
              if ((!cameraReady || _isTakingPicture) && !cameraProvider.isCaptured && _lastFramePath != null)
                SizedBox.expand(
                  child: _isTakingPicture
                      // During capture: show the captured frame sharp
                      ? Image.file(
                          File(_lastFramePath!),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      // During wake/retake: show blurred
                      : ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                              sigmaX: 10, sigmaY: 10),
                          child: Image.file(
                            File(_lastFramePath!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                ),

              // Layer 1: Live camera preview — hidden during capture
              // to avoid iOS shutter black-out flash.
              if (cameraReady && !_isTakingPicture)
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

              // Sleep overlay — tap to wake.
              if (_cameraSleeping && !cameraProvider.isCaptured)
                GestureDetector(
                  onTap: _wakeCamera,
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white38,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tap to wake camera',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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

              // Top bar: status bar area + toolbar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark,
                  child: Column(
                    children: [
                      // Status bar area — opaque linen
                      Container(
                        height: MediaQuery.of(context).padding.top,
                        color: const Color(0xFFFAF0E6),
                      ),
                      // Toolbar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: const Color(0xFFFAF0E6),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            // Language dropdown — fixed width, aligned left
                            SizedBox(
                              width: 90,
                              child: PopupMenuButton<String>(
                                color: const Color(0xFFFAF0E6),
                                offset: const Offset(0, 53),
                                onOpened: () =>
                                    setState(() => _langDropdownOpen = true),
                                onCanceled: () =>
                                    setState(() => _langDropdownOpen = false),
                                onSelected: (value) {
                                  setState(() => _langDropdownOpen = false);
                                  cameraProvider.setSourceLanguage(value);
                                },
                                itemBuilder: (context) {
                                  const languages = {
                                    'Japanese': '日本語',
                                    'Chinese': '中文',
                                    'Korean': '한국어',
                                    'English': 'English',
                                    'French': 'Français',
                                    'German': 'Deutsch',
                                    'Spanish': 'Español',
                                  };
                                  return languages.entries.map((e) {
                                    final lang = e.key;
                                    final isSelected =
                                        cameraProvider.sourceLanguage ==
                                            lang;
                                    return PopupMenuItem<String>(
                                      padding: EdgeInsets.zero,
                                      value: lang,
                                      child: Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                      0xFF664C36),
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              )
                                            : null,
                                        child: Text(
                                          e.value,
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF664C36)
                                                : Colors.black54,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                                child: Material(
                                  color: _langDropdownOpen
                                      ? const Color(0xFF005F5F)
                                      : const Color(0xFF008B8B),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    splashColor: Colors.white24,
                                    highlightColor: Colors.white10,
                                    onTap: null, // PopupMenuButton handles tap
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _langDropdownOpen
                                              ? const Color(0xFF008B8B)
                                              : const Color(0xFF005F5F),
                                          width: 1.5,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _nativeLanguageName(
                                            cameraProvider.sourceLanguage),
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
                            ),

                            // Novel selector — centered between language box and arrow
                            Expanded(
                              child: PopupMenuButton<String>(
                                color: const Color(0xFFFAF0E6),
                                offset: const Offset(0, 42),
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
                                  final items =
                                      <PopupMenuEntry<String>>[];
                                  for (final novel
                                      in cameraProvider.novels) {
                                    items.add(
                                      PopupMenuItem<String>(
                                        value: novel.id.toString(),
                                        child: Text(
                                          novel.name,
                                          style: TextStyle(
                                            color: cameraProvider
                                                        .selectedNovel
                                                        ?.id ==
                                                    novel.id
                                                ? Colors.black
                                                : Colors.black54,
                                            fontWeight: cameraProvider
                                                        .selectedNovel
                                                        ?.id ==
                                                    novel.id
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (cameraProvider
                                      .novels.isNotEmpty) {
                                    items.add(
                                        const PopupMenuDivider());
                                  }
                                  items.add(
                                    const PopupMenuItem<String>(
                                      value: '_new_novel_',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.add,
                                            color: Colors.black54,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'New Novel...',
                                            style: TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  return items;
                                },
                                child: Text(
                                  cameraProvider.selectedNovel?.name ??
                                      'Select novel',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cameraProvider
                                                .selectedNovel !=
                                            null
                                        ? Colors.black87
                                        : Colors.black38,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Arrow button — right side
                            GestureDetector(
                              onTap: () {
                                // TODO: action for arrow button
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black26),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.black54,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Capture / Retake button — centered
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: GestureDetector(
                        onTap: cameraProvider.isCaptured
                            ? _retake
                            : _takePicture,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFAF0E6),
                            border: Border.all(
                              color: const Color(0xFF664C36),
                              width: 4.5,
                            ),
                          ),
                          child: _isTakingPicture
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF008B8B),
                                    strokeWidth: 2,
                                  ),
                                )
                              : cameraProvider.isCaptured
                                  ? const Icon(
                                      Icons.refresh,
                                      color: Color(0xFF008B8B),
                                      size: 40,
                                    )
                                  : Padding(
                                      padding:
                                          const EdgeInsets.all(16),
                                      child: SvgPicture.asset(
                                        'assets/icons/capture.svg',
                                        colorFilter:
                                            const ColorFilter.mode(
                                          Color(0xFF008B8B),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // History button — right side
              Positioned(
                bottom: 0,
                right: 16,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/history');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF0E6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF008B8B),
                            width: 2.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'History',
                              style: TextStyle(
                                color: Color(0xFF005F5F),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.history,
                              color: Color(0xFF005F5F),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
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
