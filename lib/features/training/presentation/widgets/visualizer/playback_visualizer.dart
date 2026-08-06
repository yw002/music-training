import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/breath_halo_painter.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/minimal_pulse_painter.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/spectrum_particles_painter.dart';

/// 播放可视化组件（架构 §5.6 / T12）。
///
/// 订阅 [AudioService.events]（按 [playbackId] 过滤），用本地 `Ticker` 测量「距起音
/// 的毫秒数」，再交给 `EnvelopeSampler.amplitudeAt` 算出幅度。**全程不读 PCM/FFT，
/// 不碰任何音高/频率**——这是防泄露的最后一道防线（PRD §3.1）。
///
/// 可视化方案受 [VisualizerStyle] 与 [MotionScope] 双重约束：
/// - `reduced` 档强制切到极简脉冲（[MinimalPulsePainter]）；
/// - `off` 档不播放任何动画，只渲染静止终态；
/// - 频谱粒子数受看门狗降级（48→16）与 `allowParticles` 双重限制。
class PlaybackVisualizer extends StatefulWidget {
  /// 创建播放可视化。
  const PlaybackVisualizer({
    required this.audio,
    required this.playbackId,
    required this.timbre,
    required this.style,
    this.color,
    this.size = 200,
    super.key,
  });

  /// 音频服务（事件源）。
  final AudioService audio;

  /// 当前播放 id（变化时会重置可视化）。
  final int playbackId;

  /// 音色（仅用于可视化风格，不参与幅度计算，不泄露音高）。
  final Timbre timbre;

  /// 可视化方案（用户设置）。
  final VisualizerStyle style;

  /// 主色（语义色，默认取主题 primary）。
  final Color? color;

  /// 画布直径。
  final double size;

  @override
  State<PlaybackVisualizer> createState() => _PlaybackVisualizerState();
}

class _PlaybackVisualizerState extends State<PlaybackVisualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  StreamSubscription<AudioPlaybackEvent>? _sub;

  double _amplitude = 0;
  double _phase = 0;
  bool _active = false;
  Duration _noteStart = Duration.zero;
  bool _ambientAllowed = false;
  int _seed = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _subscribe();
    _updateAmbient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAmbient();
  }

  @override
  void didUpdateWidget(PlaybackVisualizer old) {
    super.didUpdateWidget(old);
    if (old.playbackId != widget.playbackId || old.audio != widget.audio) {
      _resetPlayback();
      _subscribe();
    }
    _updateAmbient();
  }

  void _updateAmbient() {
    _ambientAllowed = MotionScope.of(context).allowAmbient;
  }

  void _subscribe() {
    _sub?.cancel();
    _seed = widget.playbackId.hashCode;
    _sub = widget.audio.events.listen(_onEvent);
  }

  void _resetPlayback() {
    _active = false;
    _amplitude = 0;
    _phase = 0;
  }

  void _onEvent(AudioPlaybackEvent event) {
    if (event.playbackId != widget.playbackId) {
      return;
    }
    switch (event.type) {
      case AudioEventType.sequenceStart:
      case AudioEventType.noteStart:
        _active = true;
        _noteStart = _lastElapsed;
      case AudioEventType.sequenceEnd:
      case AudioEventType.error:
        _active = false;
      case AudioEventType.cancelled:
      case AudioEventType.noteEnd:
      case AudioEventType.segmentStart:
        break;
    }
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    final shouldAnimate = _active || _ambientAllowed;
    if (!shouldAnimate && _amplitude == 0 && _phase == 0) {
      return;
    }
    final ms = (_lastElapsed - _noteStart).inMicroseconds / 1000;
    final amp = _active
        ? EnvelopeSampler.amplitudeAt(widget.timbre, ms)
        : 0.0;
    final phase = _ambientAllowed
        ? ((_lastElapsed.inMilliseconds % 1800) / 1800)
        : 0.0;
    if ((amp - _amplitude).abs() < 0.005 && (phase - _phase).abs() < 0.01) {
      return;
    }
    _amplitude = amp;
    _phase = phase;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final data = MotionScope.of(context);
    final color = widget.color ?? tokens.scheme.primary;
    final level = data.level;

    // 降级档强制极简；off 档只渲染静止终态（幅度归零）。
    final effectiveStyle = level == MotionLevel.full ? widget.style : VisualizerStyle.minimal;
    final amp = level == MotionLevel.off ? 0.0 : _amplitude;

    Widget painter;
    switch (effectiveStyle) {
      case VisualizerStyle.halo:
        painter = CustomPaint(
          painter: BreathHaloPainter(
            amplitude: amp,
            phase: _phase,
            color: color,
          ),
          size: Size.square(widget.size),
        );
      case VisualizerStyle.spectrum:
        final spec = tokens.motion.viz.spectrumParticles;
        final baseMax = spec.maxParticles;
        final degradedMax = spec.degradedMaxParticles;
        final reduced = data.stage.reducesParticles;
        final count = data.allowParticles
            ? (reduced ? degradedMax : baseMax)
            : 0;
        painter = CustomPaint(
          painter: SpectrumParticlesPainter(
            amplitude: amp,
            color: color,
            particleCount: count,
            seed: _seed,
          ),
          size: Size(widget.size, widget.size * 0.7),
        );
      case VisualizerStyle.minimal:
        painter = CustomPaint(
          painter: MinimalPulsePainter(amplitude: amp, color: color),
          size: Size.square(widget.size),
        );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: painter,
    );
  }
}
