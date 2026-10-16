import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const MontageStudio());

class MontageStudio extends StatelessWidget {
  const MontageStudio({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Montage Studio',
        theme: ThemeData.dark(useMaterial3: true),
        home: const EditorPage(),
      );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  VideoPlayerController? _video;
  double _start = 0, _end = 0;
  bool _loading = false;

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _loading = true);
    final next = VideoPlayerController.file(
      // XFile.path points to a local file on mobile platforms.
      // dart:io is used here, so this starter targets Android and iOS only.
      File(file.path),
    );
    try {
      await next.initialize();
      await _video?.pause();
      final old = _video;
      setState(() {
        _video = next;
        _start = 0;
        _end = next.value.duration.inMilliseconds.toDouble();
      });
      await old?.dispose();
    } catch (e) {
      await next.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الفيديو: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(double ms) {
    final d = Duration(milliseconds: ms.round());
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  Future<void> _toggle() async {
    final v = _video;
    if (v == null) return;
    if (v.value.isPlaying) {
      await v.pause();
    } else {
      final pos = v.value.position.inMilliseconds.toDouble();
      if (pos < _start || pos >= _end) {
        await v.seekTo(Duration(milliseconds: _start.round()));
      }
      await v.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Montage Studio')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Expanded(
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : v == null || !v.value.isInitialized
                        ? const Text('اختر فيديو للبدء')
                        : AspectRatio(
                            aspectRatio: v.value.aspectRatio,
                            child: VideoPlayer(v),
                          ),
              ),
            ),
            if (v != null && v.value.isInitialized) ...[
              Text('بداية القص: ${_time(_start)}   نهاية القص: ${_time(_end)}'),
              RangeSlider(
                min: 0,
                max: v.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                values: RangeValues(_start, _end),
                onChanged: (range) => setState(() {
                  _start = range.start;
                  _end = range.end;
                }),
                onChangeEnd: (range) => v.seekTo(
                  Duration(milliseconds: range.start.round()),
                ),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: v,
                builder: (context, value, child) {
                  if (value.isPlaying &&
                      value.position.inMilliseconds >= _end && _end > 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (v.value.isPlaying) await v.pause();
                    });
                  }
                  return IconButton.filled(
                    onPressed: _toggle,
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                    tooltip: value.isPlaying ? 'إيقاف' : 'تشغيل',
                  );
                },
              ),
              const Text('القص محدد للمعاينة فقط؛ التصدير سيضاف لاحقاً.'),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('اختيار فيديو'),
            ),
          ]),
        ),
      ),
    );
  }
}
