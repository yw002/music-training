import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/schema_version.dart';

/// 一道已经完全确定下来的题目（架构 §3.1）。
///
/// 「完全确定」的含义：方向、音色、根音都已掷过骰子，播放层拿到它就能直接
/// 合成音频，不再需要任何随机。这是可复现性的关键——只要出题序列相同，
/// 后续播放与统计就完全一致。
///
/// **防泄露约束（PRD §3.1）**：作答前 UI 只能读 [answerOptions] 与
/// [direction]，**禁止**读 [correctInterval] / [rootMidiNote] / [targetMidiNote]
/// 去驱动任何可见状态（颜色、位置、动画时长都不行）。
class IntervalQuestion extends Equatable {
  /// 创建一道题目。
  const IntervalQuestion({
    required this.questionId,
    required this.correctInterval,
    required this.rootMidiNote,
    required this.targetMidiNote,
    required this.direction,
    required this.timbre,
    required this.rootMode,
    required this.answerOptions,
    required this.createdAt,
    this.bucket = QuestionBucket.randomProbe,
    this.focusPair,
    this.schemaVersion = kDomainSchemaVersion,
  });

  /// 题目唯一 ID。
  final String questionId;

  /// 正确音程。
  final IntervalId correctInterval;

  /// 根音 MIDI 号（先发声的那个音；和声模式下为较低音）。
  final int rootMidiNote;

  /// 目标音 MIDI 号。
  final int targetMidiNote;

  /// 本题实际播放方向。
  final PlaybackDirection direction;

  /// 本题实际音色。
  final Timbre timbre;

  /// 本题根音策略（记录下来供维度统计）。
  final RootMode rootMode;

  /// 答案选项，按半音数升序（顺序与正确答案无关，防位置泄露）。
  final List<IntervalId> answerOptions;

  /// 生成时刻。
  final DateTime createdAt;

  /// 题目来源桶。
  final QuestionBucket bucket;

  /// 二选一模式下的焦点音程对；其他模式为 `null`。
  final String? focusPair;

  /// 落盘 schema 版本。
  final int schemaVersion;

  /// 半音数。
  int semitones() => correctInterval.semitones;

  /// 两个音中较低者的 MIDI 号。
  int get lowerMidi =>
      rootMidiNote <= targetMidiNote ? rootMidiNote : targetMidiNote;

  /// 两个音中较高者的 MIDI 号。
  int get higherMidi =>
      rootMidiNote >= targetMidiNote ? rootMidiNote : targetMidiNote;

  /// 按播放先后顺序排列的两个音。和声模式下两音同时发声，顺序仅用于渲染。
  List<int> get playbackNotes => <int>[rootMidiNote, targetMidiNote];

  /// 是否为二选一题目。
  bool get isBinary => answerOptions.length == 2;

  /// 选项 [selected] 是否正确。
  bool isCorrectAnswer(IntervalId? selected) => selected == correctInterval;

  /// 复制并覆盖部分字段。
  ///
  /// [focusPair] 用 [clearFocusPair] 显式清空——`null` 在 `copyWith` 里无法
  /// 区分「不改」与「改成 null」。
  IntervalQuestion copyWith({
    String? questionId,
    IntervalId? correctInterval,
    int? rootMidiNote,
    int? targetMidiNote,
    PlaybackDirection? direction,
    Timbre? timbre,
    RootMode? rootMode,
    List<IntervalId>? answerOptions,
    DateTime? createdAt,
    QuestionBucket? bucket,
    String? focusPair,
    bool clearFocusPair = false,
    int? schemaVersion,
  }) =>
      IntervalQuestion(
        questionId: questionId ?? this.questionId,
        correctInterval: correctInterval ?? this.correctInterval,
        rootMidiNote: rootMidiNote ?? this.rootMidiNote,
        targetMidiNote: targetMidiNote ?? this.targetMidiNote,
        direction: direction ?? this.direction,
        timbre: timbre ?? this.timbre,
        rootMode: rootMode ?? this.rootMode,
        answerOptions: answerOptions ?? this.answerOptions,
        createdAt: createdAt ?? this.createdAt,
        bucket: bucket ?? this.bucket,
        focusPair: clearFocusPair ? null : (focusPair ?? this.focusPair),
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  /// 序列化。`null` 字段直接省略（架构 §8.6）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'questionId': questionId,
        'correctInterval': correctInterval.storageId,
        'rootMidiNote': rootMidiNote,
        'targetMidiNote': targetMidiNote,
        'direction': direction.storageId,
        'timbre': timbre.storageId,
        'rootMode': rootMode.storageId,
        'answerOptions':
            answerOptions.map((id) => id.storageId).toList(growable: false),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'bucket': bucket.storageId,
        if (focusPair != null) 'focusPair': focusPair,
      };

  /// 反序列化。缺失字段一律降级，不抛异常。
  factory IntervalQuestion.fromJson(Map<String, dynamic> json) {
    final correct = IntervalId.fromStorageId(json['correctInterval']);
    final rawOptions = json['answerOptions'];
    final options = <IntervalId>[];
    if (rawOptions is List) {
      for (final raw in rawOptions) {
        final id = IntervalId.tryFromStorageId(raw);
        if (id != null) {
          options.add(id);
        }
      }
    }
    return IntervalQuestion(
      questionId: json['questionId'] as String? ?? '',
      correctInterval: correct,
      rootMidiNote: _readInt(json['rootMidiNote']),
      targetMidiNote: _readInt(json['targetMidiNote']),
      direction: PlaybackDirection.fromStorageId(json['direction']),
      timbre: Timbre.fromStorageId(json['timbre']),
      rootMode: RootMode.fromStorageId(json['rootMode']),
      answerOptions: options.isEmpty
          ? IntervalCatalog.sorted(<IntervalId>{correct})
          : List<IntervalId>.unmodifiable(options),
      createdAt: _readTime(json['createdAt']),
      bucket: QuestionBucket.fromStorageId(json['bucket']),
      focusPair: json['focusPair'] as String?,
      schemaVersion: readSchemaVersion(json),
    );
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  static DateTime _readTime(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  List<Object?> get props => <Object?>[
        questionId,
        correctInterval,
        rootMidiNote,
        targetMidiNote,
        direction,
        timbre,
        rootMode,
        answerOptions,
        // 统一按 UTC 比较：本地时间与 UTC 表示同一瞬间时应视为相等，
        // 否则 `fromJson(toJson(x)) == x` 会因时区表示差异失败。
        createdAt.toUtc(),
        bucket,
        focusPair,
        schemaVersion,
      ];

  @override
  String toString() => 'IntervalQuestion($questionId, '
      '${correctInterval.storageId}, root=$rootMidiNote, '
      '${direction.storageId})';
}
