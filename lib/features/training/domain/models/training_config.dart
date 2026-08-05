import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/schema_version.dart';

/// 配置校验结果。
///
/// 为什么不直接抛异常：非法配置来自**用户操作**（在自由训练页取消勾选到只剩
/// 1 个音程），属于预期内输入错误，需要在 UI 上逐条提示，而不是崩溃。
/// 架构 §8.2 的「领域层抛异常」针对的是**编程错误**，两者不冲突。
class ValidationResult extends Equatable {
  /// 创建校验结果。
  const ValidationResult(this.errors);

  /// 校验通过。
  const ValidationResult.valid() : errors = const <ValidationIssue>[];

  /// 全部问题，按发现顺序。
  final List<ValidationIssue> errors;

  /// 是否通过。
  bool get isValid => errors.isEmpty;

  /// 第一个问题，没有则为 `null`。
  ValidationIssue? get first => errors.isEmpty ? null : errors.first;

  @override
  List<Object?> get props => <Object?>[errors];

  @override
  String toString() => 'ValidationResult(${errors.join(', ')})';
}

/// 单条校验问题。
///
/// 只带机器可读的 [code] 与字段名，**不带中文文案**——文案在表现层按 [code]
/// 从 `AppStrings` 取（架构 §8.5）。
class ValidationIssue extends Equatable {
  /// 创建一条校验问题。
  const ValidationIssue({required this.code, required this.field});

  /// 稳定错误码，如 `tooFewIntervals`。
  final String code;

  /// 出错字段名。
  final String field;

  @override
  List<Object?> get props => <Object?>[code, field];

  @override
  String toString() => '$field:$code';
}

/// 一次训练的配置快照（架构 §3.1）。
///
/// 会随 `TrainingSession` 一起落盘，因此带 [schemaVersion]；训练开始后**不可变**，
/// 中途改设置只影响下一组，保证一组内的统计口径一致。
class TrainingConfig extends Equatable {
  /// 创建配置。
  const TrainingConfig({
    required this.enabledIntervals,
    this.direction = DirectionMode.ascending,
    this.rootMode = RootMode.limitedRandom,
    this.timbreMode = TimbreMode.keyboard,
    this.questionCount = AppConfig.defaultQuestionsPerSession,
    this.noteDuration = const Duration(
      milliseconds: AppConfig.defaultNoteDurationMs,
    ),
    this.noteGap = const Duration(milliseconds: AppConfig.defaultNoteGapMs),
    this.allowReplay = true,
    this.answerMode = AnswerMode.enabledOnly,
    this.schemaVersion = kDomainSchemaVersion,
  });

  /// 错误码：启用的音程少于 2 个。
  static const String codeTooFewIntervals = 'tooFewIntervals';

  /// 错误码：题数越界。
  static const String codeQuestionCountOutOfRange = 'questionCountOutOfRange';

  /// 错误码：单音时长越界。
  static const String codeNoteDurationOutOfRange = 'noteDurationOutOfRange';

  /// 错误码：音符间隔越界。
  static const String codeNoteGapOutOfRange = 'noteGapOutOfRange';

  /// 错误码：二选一模式要求恰好 2 个音程。
  static const String codeBinaryNeedsExactlyTwo = 'binaryNeedsExactlyTwo';

  /// 本次训练启用的音程集合。
  final Set<IntervalId> enabledIntervals;

  /// 播放方向策略。
  final DirectionMode direction;

  /// 根音策略。
  final RootMode rootMode;

  /// 音色策略。
  final TimbreMode timbreMode;

  /// 本组题数。
  final int questionCount;

  /// 单音时长。
  final Duration noteDuration;

  /// 旋律音程中两音之间的间隔。
  final Duration noteGap;

  /// 是否允许重播。
  final bool allowReplay;

  /// 答题选项构成策略。
  final AnswerMode answerMode;

  /// 落盘 schema 版本。
  final int schemaVersion;

  /// 全 13 音程的默认配置，用于「全部音程」预设与冷启动兜底。
  static TrainingConfig get defaults =>
      TrainingConfig(enabledIntervals: IntervalCatalog.trainableIds);

  /// 启用音程按半音数升序的列表（渲染顺序的唯一来源）。
  List<IntervalId> get sortedIntervals =>
      IntervalCatalog.sorted(enabledIntervals);

  /// 答题选项的候选池：`allIntervals` 用全部可训练音程，其余用启用集合。
  Set<IntervalId> get answerPool => answerMode == AnswerMode.allIntervals
      ? IntervalCatalog.trainableIds
      : enabledIntervals;

  /// 校验配置合法性。返回全部问题，不在第一个问题处短路——UI 需要一次性展示。
  ValidationResult validate() {
    final issues = <ValidationIssue>[];
    if (answerMode == AnswerMode.binary) {
      if (enabledIntervals.length != AppConfig.binaryOptionCount) {
        issues.add(
          const ValidationIssue(
            code: codeBinaryNeedsExactlyTwo,
            field: 'enabledIntervals',
          ),
        );
      }
    } else if (enabledIntervals.length < AppConfig.minSelectedIntervals) {
      issues.add(
        const ValidationIssue(
          code: codeTooFewIntervals,
          field: 'enabledIntervals',
        ),
      );
    }
    if (questionCount < AppConfig.minQuestionsPerSession ||
        questionCount > AppConfig.maxQuestionsPerSession) {
      issues.add(
        const ValidationIssue(
          code: codeQuestionCountOutOfRange,
          field: 'questionCount',
        ),
      );
    }
    if (noteDuration.inMilliseconds < AppConfig.minNoteDurationMs ||
        noteDuration.inMilliseconds > AppConfig.maxNoteDurationMs) {
      issues.add(
        const ValidationIssue(
          code: codeNoteDurationOutOfRange,
          field: 'noteDuration',
        ),
      );
    }
    if (noteGap.inMilliseconds < AppConfig.minNoteGapMs ||
        noteGap.inMilliseconds > AppConfig.maxNoteGapMs) {
      issues.add(
        const ValidationIssue(
          code: codeNoteGapOutOfRange,
          field: 'noteGap',
        ),
      );
    }
    return ValidationResult(List<ValidationIssue>.unmodifiable(issues));
  }

  /// 复制并覆盖部分字段。
  TrainingConfig copyWith({
    Set<IntervalId>? enabledIntervals,
    DirectionMode? direction,
    RootMode? rootMode,
    TimbreMode? timbreMode,
    int? questionCount,
    Duration? noteDuration,
    Duration? noteGap,
    bool? allowReplay,
    AnswerMode? answerMode,
    int? schemaVersion,
  }) =>
      TrainingConfig(
        enabledIntervals: enabledIntervals ?? this.enabledIntervals,
        direction: direction ?? this.direction,
        rootMode: rootMode ?? this.rootMode,
        timbreMode: timbreMode ?? this.timbreMode,
        questionCount: questionCount ?? this.questionCount,
        noteDuration: noteDuration ?? this.noteDuration,
        noteGap: noteGap ?? this.noteGap,
        allowReplay: allowReplay ?? this.allowReplay,
        answerMode: answerMode ?? this.answerMode,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  /// 序列化。音程集合按半音数升序落盘，保证同一配置的 JSON 字节完全一致
  /// （便于做「配置是否变化」的字符串比对与快照测试）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'enabledIntervals': sortedIntervals
            .map((id) => id.storageId)
            .toList(growable: false),
        'direction': direction.storageId,
        'rootMode': rootMode.storageId,
        'timbreMode': timbreMode.storageId,
        'questionCount': questionCount,
        'noteDurationMs': noteDuration.inMilliseconds,
        'noteGapMs': noteGap.inMilliseconds,
        'allowReplay': allowReplay,
        'answerMode': answerMode.storageId,
      };

  /// 反序列化。任何字段缺失/非法都降级为默认值，绝不抛异常。
  factory TrainingConfig.fromJson(Map<String, dynamic> json) {
    final rawIntervals = json['enabledIntervals'];
    final intervals = <IntervalId>{};
    if (rawIntervals is List) {
      for (final raw in rawIntervals) {
        final id = IntervalId.tryFromStorageId(raw);
        if (id != null) {
          intervals.add(id);
        }
      }
    }
    return TrainingConfig(
      enabledIntervals:
          intervals.isEmpty ? IntervalCatalog.trainableIds : intervals,
      direction: DirectionMode.fromStorageId(json['direction']),
      rootMode: RootMode.fromStorageId(json['rootMode']),
      timbreMode: TimbreMode.fromStorageId(json['timbreMode']),
      questionCount: _readInt(
        json['questionCount'],
        AppConfig.defaultQuestionsPerSession,
      ),
      noteDuration: Duration(
        milliseconds: _readInt(
          json['noteDurationMs'],
          AppConfig.defaultNoteDurationMs,
        ),
      ),
      noteGap: Duration(
        milliseconds: _readInt(json['noteGapMs'], AppConfig.defaultNoteGapMs),
      ),
      allowReplay: json['allowReplay'] as bool? ?? true,
      answerMode: AnswerMode.fromStorageId(json['answerMode']),
      schemaVersion: readSchemaVersion(json),
    );
  }

  static int _readInt(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return fallback;
  }

  @override
  List<Object?> get props => <Object?>[
        // 用排序后的列表而不是 Set：Equatable 对 Set 走 DeepCollectionEquality，
        // 顺序无关，但排序后列表在 hashCode 上也稳定，便于当 Map 键使用。
        sortedIntervals,
        direction,
        rootMode,
        timbreMode,
        questionCount,
        noteDuration,
        noteGap,
        allowReplay,
        answerMode,
        schemaVersion,
      ];

  @override
  String toString() =>
      'TrainingConfig(${enabledIntervals.length} intervals, '
      '$questionCount questions, ${direction.storageId})';
}
