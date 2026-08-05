/// 播放事件类型（架构 §3.4 / §1.3）。
///
/// 与 [AudioPlaybackEvent] 配套：UI 层据此驱动 M-18 半音尺高亮、光环扫光等，
/// **绝不**从事件里读音高（见 [AudioPlaybackEvent] 的纵深防御）。
enum AudioEventType {
  /// 整段序列开始。
  sequenceStart,

  /// 某个音符开始发声。
  noteStart,

  /// 某个音符结束发声。
  noteEnd,

  /// 交替对比中的某一段开始（segmentIndex 区分错/对）。
  segmentStart,

  /// 整段序列结束。
  sequenceEnd,

  /// 被新的播放请求取消（旧 playbackId 的事件丢弃）。
  cancelled,

  /// 合成 / 播放出错（不抛异常，emit error 事件）。
  error,
}

/// 时间轴上的一个标记点（架构 §1.3.2）。
///
/// [at] 是距序列起点的绝对时刻；[noteIndex] 0=根音、1=目标音、-1=和声两音同响；
/// [segmentIndex] 普通播放恒为 0，交替对比为 0..3。
///
/// 注意：mark **不携带音色/音高**——音色只出现在运行期的 [AudioPlaybackEvent]
/// 上（且同样不含音高），这里只描述「何时发生了什么」。
class AudioTimelineMark {
  const AudioTimelineMark({
    required this.at,
    required this.type,
    this.noteIndex = -1,
    this.segmentIndex = 0,
    this.noteDuration = Duration.zero,
  });

  /// 距序列起点的时刻。
  final Duration at;

  /// 事件类型。
  final AudioEventType type;

  /// 音符下标（0=根音，1=目标音，-1=和声同响）。
  final int noteIndex;

  /// 段下标（交替对比 0..3，普通播放 0）。
  final int segmentIndex;

  /// 该音符的实际时长（供 M-18 扫光按「该音符实际时长」运行）。
  final Duration noteDuration;

  @override
  String toString() =>
      'AudioTimelineMark(${type.name} @${at.inMilliseconds}ms, '
      'note=$noteIndex, seg=$segmentIndex)';
}

/// 一道题音频的时间线（架构 §1.3）。
///
/// 由 [SequenceBuilder] 与波形**同时**产出，二者共享同一份参数，mark 位置与采样点
/// 「误差 0 样本」（T08 验收 2）。[total] 含尾部 padding（见
/// [SequenceBuilder.kTailPaddingMs]）。
class AudioTimeline {
  const AudioTimeline({
    required this.total,
    required this.marks,
  });

  /// 整段总时长（含尾部 padding）。
  final Duration total;

  /// 按 [AudioTimelineMark.at] 升序的标记列表。
  final List<AudioTimelineMark> marks;

  /// 取出下一个「晚于 [position]」的标记下标，供播放器逐帧推进。
  ///
  /// 返回 `null` 表示没有更多标记。
  int? nextMarkIndex(Duration position) {
    for (int i = 0; i < marks.length; i++) {
      if (marks[i].at > position) {
        return i;
      }
    }
    return null;
  }
}
