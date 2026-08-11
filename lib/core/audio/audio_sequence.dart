import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';

/// 一次播放请求的「纯数据」规格（架构 §3.4）。
///
/// 由 [IntervalQuestion] 经 [AudioSequenceSpec.fromQuestion] 转换而来；序列层
/// [SequenceBuilder] 只认这个规格，不认题目——这样合成与「出题/答案」彻底解耦，
/// 也天然满足防泄露（序列层拿不到题目 ID / 答案）。
class AudioSequenceSpec {
  const AudioSequenceSpec({
    required this.rootMidiNote,
    required this.targetMidiNote,
    required this.direction,
    required this.timbre,
    this.noteDuration = defaultNoteDuration,
    this.noteGap = defaultNoteGap,
    this.gain = defaultGain,
  });

  /// 默认单音时长（毫秒）。与合成器 [KeyboardVoice.kNoteDuration] 对齐（1.1s），
  /// 使默认旋律总样本数 = `round(44100 × (1.1 + 0.18 + 1.1))`（T08 验收 3）。
  static const Duration defaultNoteDuration = Duration(milliseconds: 1100);

  /// 默认旋律间隔（毫秒）。架构 §5.5 规定的 0.18s。
  static const Duration defaultNoteGap = Duration(milliseconds: 180);

  /// 默认增益。
  static const double defaultGain = 1.0;

  /// 根音 MIDI 号（先发声的那个音；和声模式下为较低音）。
  final int rootMidiNote;

  /// 目标音 MIDI 号。
  final int targetMidiNote;

  /// 播放方向。
  final PlaybackDirection direction;

  /// 音色。
  final Timbre timbre;

  /// 单音时长。
  final Duration noteDuration;

  /// 旋律两音之间的间隔。
  final Duration noteGap;

  /// 整体增益（0..1+）。
  final double gain;

  /// 不含题目 ID 的缓存键。
  ///
  /// 同音程 + 同根音 + 同音色 + 同时长/间隔/增益 → 命中同一键（T08 验收 5）。
  /// 重播同一题的音频直接从 L2 序列缓存取，不重复合成。
  String cacheKey() {
    return 'r$rootMidiNote'
        '-t$targetMidiNote'
        '-${direction.storageId}'
        '-${timbre.storageId}'
        '-${noteDuration.inMilliseconds}'
        '-${noteGap.inMilliseconds}'
        '-${gain.toStringAsFixed(3)}';
  }

  /// 从一道已确定的题目构造播放规格。
  ///
  /// 只取 [IntervalQuestion] 的 root/target/direction/timbre，**不读答案**
  /// （符合 PRD §3.1 防泄露约束）。[noteGap] 可覆盖默认间隔。
  factory AudioSequenceSpec.fromQuestion(
    IntervalQuestion q, {
    Duration? noteGap,
  }) {
    return AudioSequenceSpec(
      rootMidiNote: q.rootMidiNote,
      targetMidiNote: q.targetMidiNote,
      direction: q.direction,
      timbre: q.timbre,
      noteDuration: defaultNoteDuration,
      noteGap: noteGap ?? defaultNoteGap,
    );
  }

  /// 替换目标音程（保留根音/方向/音色，只换目标 MIDI）。
  ///
  /// 用于交替对比播放：正确音程与用户所选音程各播一遍（答错后的对比播放）。
  AudioSequenceSpec withInterval(IntervalId other) {
    final int signedSemitones = direction == PlaybackDirection.descending
        ? -other.semitones
        : other.semitones;
    return copyWith(targetMidiNote: rootMidiNote + signedSemitones);
  }

  /// 复制并覆盖部分字段。
  AudioSequenceSpec copyWith({
    int? rootMidiNote,
    int? targetMidiNote,
    PlaybackDirection? direction,
    Timbre? timbre,
    Duration? noteDuration,
    Duration? noteGap,
    double? gain,
  }) {
    return AudioSequenceSpec(
      rootMidiNote: rootMidiNote ?? this.rootMidiNote,
      targetMidiNote: targetMidiNote ?? this.targetMidiNote,
      direction: direction ?? this.direction,
      timbre: timbre ?? this.timbre,
      noteDuration: noteDuration ?? this.noteDuration,
      noteGap: noteGap ?? this.noteGap,
      gain: gain ?? this.gain,
    );
  }

  @override
  String toString() => 'AudioSequenceSpec(r$rootMidiNote-t$targetMidiNote, '
      '${direction.storageId}, ${timbre.storageId})';
}
