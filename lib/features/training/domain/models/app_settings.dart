import 'package:equatable/equatable.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 播放可视化方案（PRD §7 表 #3 / 设置页）。
enum VisualizerStyle {
  /// 光环呼吸（默认）。
  halo('halo'),

  /// 频谱粒子。
  spectrum('spectrum'),

  /// 极简脉冲（最省性能）。
  minimal('minimal');

  const VisualizerStyle(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 默认值。
  static const VisualizerStyle defaultValue = VisualizerStyle.halo;

  /// 由落盘字符串解析，未知值降级为 [defaultValue]。
  static VisualizerStyle fromStorageId(String? id) {
    for (final value in values) {
      if (value.storageId == id) {
        return value;
      }
    }
    return defaultValue;
  }
}

/// 答对庆祝强度（PRD §7 表 #2）。
enum CelebrationLevel {
  /// 轻微（默认）：连击阈值更保守。
  subtle('subtle'),

  /// 完整：阈值下调 2 档，粒子更多。
  rich('rich'),

  /// 无庆祝。
  off('off');

  const CelebrationLevel(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 默认值。
  static const CelebrationLevel defaultValue = CelebrationLevel.subtle;

  /// 由落盘字符串解析，未知值降级为 [defaultValue]。
  static CelebrationLevel fromStorageId(String? id) {
    for (final value in values) {
      if (value.storageId == id) {
        return value;
      }
    }
    return defaultValue;
  }
}

/// 桌面窗口几何（设置页持久化）。
class WindowGeometry extends Equatable {
  /// 创建窗口几何。
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// 左上角 x（逻辑像素）。
  final double x;

  /// 左上角 y（逻辑像素）。
  final double y;

  /// 宽（逻辑像素）。
  final double width;

  /// 高（逻辑像素）。
  final double height;

  /// 从 JSON 读取，非法值降级为 0。
  factory WindowGeometry.fromJson(Map<String, dynamic> json) => WindowGeometry(
        x: _readDouble(json['x']),
        y: _readDouble(json['y']),
        width: _readDouble(json['width']),
        height: _readDouble(json['height']),
      );

  /// 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  /// 复制并覆盖部分字段。
  WindowGeometry copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      WindowGeometry(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  static double _readDouble(Object? raw) =>
      raw is num ? raw.toDouble() : 0.0;

  @override
  List<Object?> get props => <Object?>[x, y, width, height];
}

/// 全部用户设置（架构 §3.5 / T16 / T17）。
///
/// 这是设置页的唯一真相源；所有 UI 都从它取，所有改动都走 [copyWith] + 落盘。
/// 字段命名与 `settings_dto.dart` 的键一一对应，迁移时不会有两个真相。
class AppSettings extends Equatable {
  /// 创建设置。
  const AppSettings({
    required this.defaultTimbre,
    required this.defaultNoteGap,
    required this.volume,
    required this.feedbackSoundEnabled,
    required this.autoNext,
    required this.autoNextDelay,
    required this.showSemitoneCount,
    required this.showIntervalShorthand,
    required this.themeMode,
    required this.motionPreference,
    required this.visualizerStyle,
    required this.celebrationLevel,
    required this.hapticsEnabled,
    required this.announcePlayback,
  });

  /// 默认设置（冷启动与「恢复默认」共用）。
  static const AppSettings defaults = AppSettings(
    defaultTimbre: Timbre.keyboard,
    defaultNoteGap: Duration(milliseconds: AppConfig.defaultNoteGapMs),
    volume: 1.0,
    feedbackSoundEnabled: true,
    autoNext: false,
    autoNextDelay: Duration(milliseconds: 600),
    showSemitoneCount: true,
    showIntervalShorthand: false,
    themeMode: ThemePreference.system,
    motionPreference: MotionPreference.system,
    visualizerStyle: VisualizerStyle.halo,
    celebrationLevel: CelebrationLevel.subtle,
    hapticsEnabled: true,
    announcePlayback: false,
  );

  /// 默认音色。
  final Timbre defaultTimbre;

  /// 默认音符间隔。
  final Duration defaultNoteGap;

  /// 主音量 [0, 1]。
  final double volume;

  /// 答题反馈音开关。
  final bool feedbackSoundEnabled;

  /// 答对后自动进入下一题。
  final bool autoNext;

  /// 自动进入的延时。
  final Duration autoNextDelay;

  /// 答案区显示半音数。
  final bool showSemitoneCount;

  /// 音程标签显示英文简称（P1/m2…）。
  final bool showIntervalShorthand;

  /// 主题模式（领域层偏好，表现层再映射为 flutter `ThemeMode`）。
  final ThemePreference themeMode;

  /// 动效偏好。
  final MotionPreference motionPreference;

  /// 播放可视化方案。
  final VisualizerStyle visualizerStyle;

  /// 答对庆祝强度。
  final CelebrationLevel celebrationLevel;

  /// 触觉反馈开关。
  final bool hapticsEnabled;

  /// 屏幕阅读器播报每次播放。
  final bool announcePlayback;

  /// 序列化（顶层带 `schemaVersion`）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': 1,
        'defaultTimbre': defaultTimbre.storageId,
        'defaultNoteGapMs': defaultNoteGap.inMilliseconds,
        'volume': volume,
        'feedbackSoundEnabled': feedbackSoundEnabled,
        'autoNext': autoNext,
        'autoNextDelayMs': autoNextDelay.inMilliseconds,
        'showSemitoneCount': showSemitoneCount,
        'showIntervalShorthand': showIntervalShorthand,
        'themeMode': themeMode.storageId,
        'motionPreference': motionPreference.storageId,
        'visualizerStyle': visualizerStyle.storageId,
        'celebrationLevel': celebrationLevel.storageId,
        'hapticsEnabled': hapticsEnabled,
        'announcePlayback': announcePlayback,
      };

  /// 反序列化，任何字段缺失/非法都降级为 [defaults] 对应项。
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        defaultTimbre: Timbre.fromStorageId(json['defaultTimbre']),
        defaultNoteGap: Duration(
          milliseconds:
              _readInt(json['defaultNoteGapMs'], AppConfig.defaultNoteGapMs),
        ),
        volume: _readDouble(json['volume'], 1.0),
        feedbackSoundEnabled: json['feedbackSoundEnabled'] as bool? ?? true,
        autoNext: json['autoNext'] as bool? ?? false,
        autoNextDelay: Duration(
          milliseconds: _readInt(json['autoNextDelayMs'], 600),
        ),
        showSemitoneCount: json['showSemitoneCount'] as bool? ?? true,
        showIntervalShorthand: json['showIntervalShorthand'] as bool? ?? false,
        themeMode: ThemePreference.fromStorageId(json['themeMode'] as String?),
        motionPreference:
            MotionPreference.fromStorageId(json['motionPreference'] as String?),
        visualizerStyle:
            VisualizerStyle.fromStorageId(json['visualizerStyle'] as String?),
        celebrationLevel:
            CelebrationLevel.fromStorageId(json['celebrationLevel'] as String?),
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        announcePlayback: json['announcePlayback'] as bool? ?? false,
      );

  /// 复制并覆盖部分字段。
  AppSettings copyWith({
    Timbre? defaultTimbre,
    Duration? defaultNoteGap,
    double? volume,
    bool? feedbackSoundEnabled,
    bool? autoNext,
    Duration? autoNextDelay,
    bool? showSemitoneCount,
    bool? showIntervalShorthand,
    ThemePreference? themeMode,
    MotionPreference? motionPreference,
    VisualizerStyle? visualizerStyle,
    CelebrationLevel? celebrationLevel,
    bool? hapticsEnabled,
    bool? announcePlayback,
  }) =>
      AppSettings(
        defaultTimbre: defaultTimbre ?? this.defaultTimbre,
        defaultNoteGap: defaultNoteGap ?? this.defaultNoteGap,
        volume: volume ?? this.volume,
        feedbackSoundEnabled:
            feedbackSoundEnabled ?? this.feedbackSoundEnabled,
        autoNext: autoNext ?? this.autoNext,
        autoNextDelay: autoNextDelay ?? this.autoNextDelay,
        showSemitoneCount: showSemitoneCount ?? this.showSemitoneCount,
        showIntervalShorthand:
            showIntervalShorthand ?? this.showIntervalShorthand,
        themeMode: themeMode ?? this.themeMode,
        motionPreference: motionPreference ?? this.motionPreference,
        visualizerStyle: visualizerStyle ?? this.visualizerStyle,
        celebrationLevel: celebrationLevel ?? this.celebrationLevel,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        announcePlayback: announcePlayback ?? this.announcePlayback,
      );

  static int _readInt(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return fallback;
  }

  static double _readDouble(Object? raw, double fallback) =>
      raw is num ? raw.toDouble() : fallback;

  @override
  List<Object?> get props => <Object?>[
        defaultTimbre,
        defaultNoteGap,
        volume,
        feedbackSoundEnabled,
        autoNext,
        autoNextDelay,
        showSemitoneCount,
        showIntervalShorthand,
        themeMode,
        motionPreference,
        visualizerStyle,
        celebrationLevel,
        hapticsEnabled,
        announcePlayback,
      ];
}
