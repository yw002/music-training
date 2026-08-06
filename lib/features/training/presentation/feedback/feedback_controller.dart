import 'dart:async';

import 'package:flutter/material.dart';

import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

/// 反馈区播放控制器（架构 §3.5 / T13 验收 1）。
///
/// 负责「交替对比」播放（答对后对比正确音程 vs 用户所选音程）。**关键约束**：
/// 整段对比只调用**一次** `AudioService.playComparison`（其内部走
/// [SequenceBuilder.buildComparison] 单缓冲渲染），且播放中再次点击会被忽略，
/// 杜绝重叠播放泄露作答节奏。
///
/// 以 `StatefulWidget` + builder 形式暴露 [FeedbackHandle]，让错题面板内的
/// A/B 按钮、进度环等子组件共享同一个 `isComparing` 状态。
class FeedbackController extends StatefulWidget {
  /// 创建反馈控制器。
  const FeedbackController({
    required this.audio,
    required this.question,
    required this.attempt,
    required this.builder,
    super.key,
  });

  /// 音频服务。
  final AudioService audio;

  /// 已答的那道题（携带 root/target，但不读答案之外信息）。
  final IntervalQuestion question;

  /// 本次作答（含所选音程，供对比播放构造第二段）。
  final TrainingAttempt attempt;

  /// 用 [FeedbackHandle] 构建子组件。
  final Widget Function(BuildContext context, FeedbackHandle handle) builder;

  @override
  State<FeedbackController> createState() => _FeedbackControllerState();
}

/// 反馈控制器暴露给子组件的句柄。
class FeedbackHandle {
  /// 创建句柄。
  const FeedbackHandle({
    required this.isComparing,
    required this.playComparison,
  });

  /// 是否正在对比播放。
  final bool isComparing;

  /// 触发一次对比播放（播放中再次调用无效）。
  final VoidCallback playComparison;
}

class _FeedbackControllerState extends State<FeedbackController> {
  bool _comparing = false;
  StreamSubscription<AudioPlaybackEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.audio.events.listen(_onEvent);
  }

  @override
  void didUpdateWidget(FeedbackController old) {
    super.didUpdateWidget(old);
    if (old.audio != widget.audio) {
      _sub?.cancel();
      _sub = widget.audio.events.listen(_onEvent);
    }
  }

  void _onEvent(AudioPlaybackEvent event) {
    if (event.type == AudioEventType.sequenceEnd ||
        event.type == AudioEventType.error ||
        event.type == AudioEventType.cancelled) {
      if (_comparing && mounted) {
        setState(() => _comparing = false);
      }
    }
  }

  void _play() {
    if (_comparing) {
      return; // 单缓冲：播放中忽略再次点击。
    }
    final correct = AudioSequenceSpec.fromQuestion(widget.question);
    final selectedInterval = widget.attempt.selectedInterval;
    // 用户未选（不确定）时，对比正确音程与「同根音大二度」作为可听差异的参照。
    final reference = selectedInterval ??
        IntervalId.fromSemitones(
          (widget.question.correctInterval.semitones + 2).clamp(0, 12),
        );
    final selected = correct.withInterval(reference);
    setState(() => _comparing = true);
    widget.audio
        .playComparison(
          <AudioSequenceSpec>[correct, selected],
          const Duration(milliseconds: AppConfig.compareGapMs),
        )
        .then((_) {
      // 真正结束以 sequenceEnd 事件为准；此处兜底。
    }).catchError((Object _) {
      if (mounted) {
        setState(() => _comparing = false);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        FeedbackHandle(isComparing: _comparing, playComparison: _play),
      );
}
