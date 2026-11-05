import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../video_limits.dart';

/// Result returned by RecordScreen via Navigator.pop.
class RecordedVideo {
  const RecordedVideo({
    required this.path,
    required this.seconds,
    required this.createdAt,
  });

  final String path;
  final int seconds;
  final DateTime createdAt;
}

/// In-app camera with a length selector, per-app limit check, a size
/// estimate and a low-space check.
/// Open with:
///   final RecordedVideo? v = await Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => RecordScreen(platformIds: ids)));
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, this.platformIds = const <String>{}});

  /// Platform ids ticked on Compose (PlatformDef.id values).
  final Set<String> platformIds;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  static const Color _warn = Color(0xFFE08A1E);

  // About 26 MB per minute. Good quality at 720p.
  static const int _bitrateHigh = 3500000;
  // About 14 MB per minute. Used when an app with a small file limit
  // (WhatsApp, 16 MB) is ticked.
  static const int _bitrateSmall = 1800000;
  static const int _audioBitrate = 128000;

  final DiskSpacePlus _disk = DiskSpacePlus();

  late final int _videoBitrate;

  List<CameraDescription>? _cameras;
  CameraController? _controller;
  CameraDescription? _desc;
  bool _ready = false;
  String? _error;

  int _chosen = kDefaultRecordSeconds;
  bool _recording = false;
  bool _stopping = false;
  final Stopwatch _watch = Stopwatch();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _videoBitrate = _pickBitrate();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Smaller bitrate when any ticked app has a small file-size limit.
  int _pickBitrate() {
    for (final String id in widget.platformIds) {
      final int? mb = kVideoLimits[id]?.maxMB;
      if (mb != null && mb <= 100) return _bitrateSmall;
    }
    return _bitrateHigh;
  }

  /// Estimated file size in MB for a clip of [seconds].
  double _estMB(int seconds) =>
      seconds * (_videoBitrate + _audioBitrate) / 8 / 1000000;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && !_recording) {
      final c = _controller;
      _controller = null;
      if (mounted) setState(() => _ready = false);
      c?.dispose();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        !_recording) {
      _initCamera(_desc);
    }
  }

  Future<void> _initCamera([CameraDescription? cam]) async {
    try {
      _cameras ??= await availableCameras();
      final list = _cameras!;
      if (list.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this phone.');
        return;
      }
      final CameraDescription desc = cam ??
          list.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => list.first,
          );
      final old = _controller;
      _controller = null;
      if (mounted) setState(() => _ready = false);
      await old?.dispose();

      final c = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: true,
        videoBitrate: _videoBitrate,
        audioBitrate: _audioBitrate,
      );
      await c.initialize();
      try {
        await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _desc = desc;
        _ready = true;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('AccessDenied') ||
          e.code.contains('Restricted');
      setState(() {
        _ready = false;
        _error = denied
            ? 'Camera or microphone access is off. Turn it on in your phone Settings, then come back.'
            : 'Could not start the camera (${e.code}).';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start the camera.');
      }
    }
  }

  Future<void> _flip() async {
    final list = _cameras;
    if (list == null || list.length < 2 || _recording || _desc == null) return;
    final next = list.firstWhere(
      (c) => c.lensDirection != _desc!.lensDirection,
      orElse: () => _desc!,
    );
    await _initCamera(next);
  }

  /// True when there is enough free space to record the chosen length.
  /// If the free space can't be read, recording is allowed.
  Future<bool> _hasSpaceToRecord() async {
    try {
      final double? freeMB = await _disk.getFreeDiskSpace;
      if (freeMB == null) return true;
      final double needMB = _estMB(_chosen) * 1.5 + 200;
      if (freeMB >= needMB) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough free space to record ${_chipLabel(_chosen)}. '
              'Free up about ${needMB.ceil()} MB and try again.',
            ),
          ),
        );
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _recording || _stopping) return;
    if (!await _hasSpaceToRecord()) return;
    try {
      await c.startVideoRecording();
      _watch
        ..reset()
        ..start();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        if (_watch.elapsed.inSeconds >= _chosen) {
          _stop();
        } else {
          setState(() {});
        }
      });
      setState(() => _recording = true);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not start recording (${e.code}).');
      }
    }
  }

  Future<void> _stop() async {
    final c = _controller;
    if (c == null || !_recording || _stopping) return;
    _stopping = true;
    _tick?.cancel();
    _watch.stop();
    final int secs = (_watch.elapsedMilliseconds / 1000).round().clamp(1, _chosen);
    try {
      final XFile f = await c.stopVideoRecording();
      final dir = await getApplicationDocumentsDirectory();
      final vdir = Directory('${dir.path}/videos');
      await vdir.create(recursive: true);
      final String ext = f.path.contains('.') ? f.path.split('.').last : 'mp4';
      final DateTime now = DateTime.now();
      final String dest =
          '${vdir.path}/video_${now.millisecondsSinceEpoch}.$ext';
      // Move the file into the app's folder. Falls back to copy + delete
      // if the two folders are on different volumes.
      try {
        await File(f.path).rename(dest);
      } catch (_) {
        await f.saveTo(dest);
        try {
          await File(f.path).delete();
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        RecordedVideo(path: dest, seconds: secs, createdAt: now),
      );
    } on CameraException catch (e) {
      _stopping = false;
      if (mounted) {
        setState(() {
          _recording = false;
          _error = 'Could not save the video (${e.code}).';
        });
      }
    }
  }

  Future<void> _close() async {
    if (_recording) {
      final c = _controller;
      _tick?.cancel();
      _watch.stop();
      try {
        final XFile f = await c!.stopVideoRecording();
        await File(f.path).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop(null);
  }

  String _clock(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _chipLabel(int s) => s >= 120 ? '${s ~/ 60} min' : '${s}s';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _preview()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _topBar(),
                const Spacer(),
                _bottomPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final c = _controller;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
        ),
      );
    }
    if (!_ready || c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    final Size ps = c.value.previewSize ?? const Size(1280, 720);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ps.height,
          height: ps.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  Widget _topBar() {
    final int elapsed = _watch.elapsed.inSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            tooltip: 'Close',
          ),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_recording)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      '${_clock(_recording ? elapsed : 0)} / ${_clock(_chosen)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    final Set<String> ids = widget.platformIds;
    final String hint = recommendedHint(ids);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00000000), Color(0xE6000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          if (ids.isNotEmpty) _platformPill(ids),
          const SizedBox(height: 6),
          Text(
            'About ${_estMB(_chosen).round()} MB at ${_chipLabel(_chosen)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _chipRow(),
          const SizedBox(height: 16),
          _controlsRow(),
        ],
      ),
    );
  }

  Widget _platformPill(Set<String> ids) {
    final List<String> trims = appsThatWillTrim(ids, _chosen);
    final double est = _estMB(_chosen);
    final List<String> big = <String>[];
    for (final String id in ids) {
      final VideoLimit? l = kVideoLimits[id];
      if (l != null && l.maxMB != null && est > l.maxMB!) {
        big.add('${l.label} (limit ${l.maxMB} MB)');
      }
    }
    final bool ok = trims.isEmpty && big.isEmpty;
    final String msg;
    if (ok) {
      msg = platformCheckMessage(ids, _chosen);
    } else {
      final List<String> parts = <String>[];
      if (trims.isNotEmpty) parts.add(platformCheckMessage(ids, _chosen));
      if (big.isNotEmpty) {
        parts.add('File of about ${est.round()} MB is over ${big.join(', ')}');
      }
      msg = parts.join('. ');
    }
    final Color color = ok ? AppColors.gold : _warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: kRecordLengthOptions.map((int s) {
        final bool sel = s == _chosen;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: _recording ? null : () => setState(() => _chosen = s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.gold : const Color(0x99000000),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Text(
                _chipLabel(s),
                style: TextStyle(
                  color: sel
                      ? AppColors.black
                      : (_recording
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _controlsRow() {
    final bool canFlip = (_cameras?.length ?? 0) > 1 && !_recording;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const SizedBox(width: 48),
        GestureDetector(
          onTap: _recording ? _stop : _start,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 3),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: _recording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius:
                    _recording ? BorderRadius.circular(10) : null,
              ),
              margin: EdgeInsets.all(_recording ? 16 : 0),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: canFlip
              ? IconButton(
                  onPressed: _flip,
                  icon: const Icon(Icons.cameraswitch_outlined,
                      color: AppColors.textPrimary),
                  tooltip: 'Flip camera',
                )
              : null,
        ),
      ],
    );
  }
}
