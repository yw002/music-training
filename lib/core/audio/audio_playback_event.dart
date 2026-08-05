import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 一次播放过程中发出的事件（架构 §3.4）。
///
/// **纵深防御（防泄露，PRD §3.1 / §1.3.4）**：事件**故意不携带**任何 `midiNote` /
/// `frequency` / `pitch` 字段。反馈阶段 UI 要画音高轨道时，必须从 [IntervalQuestion]
/// 自己取。即使某天有人在训练页误用播放事件，也**物理上不可能**泄露答案。
///
/// 每个事件都带 [playbackId]：UI 层**必须**丢弃 `playbackId != currentPlaybackId`
/// 的事件——这是「连续点重播」不错乱的根本保障。
class AudioPlaybackEvent {
  const AudioPlaybackEvent({
    required this.type,
    required this.playbackId,
    this.noteIndex = -1,
    this.segmentIndex = 0,
    this.position = Duration.zero,
    this.noteDuration = Duration.zero,
    this.timbre = Timbre.keyboard,
    this.errorMessage,
  });

  /// 事件类型。
  final AudioEventType type;

  /// 所属播放的 id（每次 [AudioService.playSequence] / [AudioService.playComparison]
  /// 都生成新的 id）。
  final int playbackId;

  /// 音符下标（0=根音，1=目标音，-1=和声同响）。
  final int noteIndex;

  /// 段下标（交替对比 0..3，普通播放 0）。
  final int segmentIndex;

  /// 事件发生的播放位置。
  final Duration position;

  /// 该音符的实际时长（供可视化简洁运行）。
  final Duration noteDuration;

  /// 正在响的音色（仅用于可视化「风格」，不含音高）。
  final Timbre timbre;

  /// 出错时的可读信息（[AudioEventType.error] 时非空）。
  final String? errorMessage;

  /// 全部公开字段名。
  ///
  /// 这是「事件不含音高」的硬性护栏：任何新增 `midiNote` / `frequency` / `pitch`
  /// 字段的人必须同步更新此列表，否则 `audio_playback_event_test` 会失败。Flutter
  /// 不支持 `dart:mirrors`，故用这份显式列表做结构断言，而不是运行时反射。
  static const List<String> fieldNames = <String>[
    'type',
    'playbackId',
    'noteIndex',
    'segmentIndex',
    'position',
    'noteDuration',
    'timbre',
    'errorMessage',
  ];

  /// 整段序列开始。
  factory AudioPlaybackEvent.sequenceStart(int playbackId, {Timbre timbre = Timbre.keyboard}) =>
      AudioPlaybackEvent(
        type: AudioEventType.sequenceStart,
        playbackId: playbackId,
        timbre: timbre,
      );

  /// 某个音符开始发声。
  factory AudioPlaybackEvent.noteStart(
    int playbackId, {
    required int noteIndex,
    required Duration position,
    required Duration noteDuration,
    required Timbre timbre,
  }) =>
      AudioPlaybackEvent(
        type: AudioEventType.noteStart,
        playbackId: playbackId,
        noteIndex: noteIndex,
        position: position,
        noteDuration: noteDuration,
        timbre: timbre,
      );

  /// 某个音符结束发声。
  factory AudioPlaybackEvent.noteEnd(
    int playbackId, {
    required int noteIndex,
    required Duration position,
    required Timbre timbre,
  }) =>
      AudioPlaybackEvent(
        type: AudioEventType.noteEnd,
        playbackId: playbackId,
        noteIndex: noteIndex,
        position: position,
        timbre: timbre,
      );

  /// 交替对比中的某一段开始。
  factory AudioPlaybackEvent.segmentStart(
    int playbackId, {
    required int segmentIndex,
    required Duration position,
    required Timbre timbre,
  }) =>
      AudioPlaybackEvent(
        type: AudioEventType.segmentStart,
        playbackId: playbackId,
        segmentIndex: segmentIndex,
        position: position,
        timbre: timbre,
      );

  /// 整段序列结束。
  factory AudioPlaybackEvent.sequenceEnd(int playbackId, {Timbre timbre = Timbre.keyboard}) =>
      AudioPlaybackEvent(
        type: AudioEventType.sequenceEnd,
        playbackId: playbackId,
        timbre: timbre,
      );

  /// 被新的播放请求取消。
  factory AudioPlaybackEvent.cancelled(int playbackId) =>
      AudioPlaybackEvent(type: AudioEventType.cancelled, playbackId: playbackId);

  /// 出错（不抛异常，改发此事件）。
  factory AudioPlaybackEvent.error(int playbackId, String message) =>
      AudioPlaybackEvent(
        type: AudioEventType.error,
        playbackId: playbackId,
        errorMessage: message,
      );

  @override
  String toString() =>
      'AudioPlaybackEvent(${type.name}, playback=$playbackId, '
      'note=$noteIndex, seg=$segmentIndex)';
}
