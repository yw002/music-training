/// 全局编译期常量。
///
/// 只放「与业务规则绑定、多个模块都要读、且运行时不变」的数值。
/// 用户可调项走 `SettingsRepository`，不进这里。
abstract final class AppConfig {
  const AppConfig._();

  /// 应用版本号（用于关于页展示，与 pubspec 的 `version` 保持一致）。
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // 音域与音高
  // ---------------------------------------------------------------------------

  /// 训练音域下界 C3 的 MIDI 号（C4 = 60，故 C3 = 48）。
  static const int minMidi = 48;

  /// 训练音域上界 C6 的 MIDI 号。
  static const int maxMidi = 84;

  /// 固定根音模式使用的根音：C4。
  static const int fixedRootMidi = 60;

  /// 有限随机根音的候选下界（C4）。
  static const int limitedRandomRootMin = 60;

  /// 有限随机根音的候选上界（B4），保证上行八度不越过 [maxMidi]。
  static const int limitedRandomRootMax = 71;

  /// A4 标准音高（Hz），MIDI→频率换算的基准。
  static const double referencePitchHz = 440.0;

  /// A4 对应的 MIDI 号。
  static const int referencePitchMidi = 69;

  // ---------------------------------------------------------------------------
  // 音频合成
  // ---------------------------------------------------------------------------

  /// 合成采样率。44100 是四端音频后端的公共安全值。
  static const int sampleRate = 44100;

  /// 声道数。单声道足够，且能把序列缓冲体积减半。
  static const int channelCount = 1;

  /// PCM 位深（WAV 编码用）。
  static const int bitsPerSample = 16;

  /// 单音默认时长（毫秒）。
  static const int defaultNoteDurationMs = 900;

  /// 单音时长可调下界（毫秒）。
  static const int minNoteDurationMs = 400;

  /// 单音时长可调上界（毫秒）。
  static const int maxNoteDurationMs = 2000;

  /// 旋律音程两音之间的默认间隔（毫秒）。
  static const int defaultNoteGapMs = 120;

  /// 音符间隔可调下界（毫秒）。
  static const int minNoteGapMs = 0;

  /// 音符间隔可调上界（毫秒）。
  static const int maxNoteGapMs = 800;

  /// 交替对比播放时两次播放之间的静音间隔（毫秒）。
  static const int compareGapMs = 320;

  /// 峰值归一化目标幅度。留 18% 余量给和声叠加后的软限幅。
  static const double normalizePeak = 0.82;

  /// 起音/收音的 raised-cosine 淡入淡出时长（毫秒），消除爆音。
  static const int fadeEdgeMs = 8;

  // ---------------------------------------------------------------------------
  // 题目与训练组
  // ---------------------------------------------------------------------------

  /// 每组题数默认值。
  static const int defaultQuestionsPerSession = 20;

  /// 每组题数下界。
  static const int minQuestionsPerSession = 5;

  /// 每组题数上界。
  static const int maxQuestionsPerSession = 50;

  /// 自由训练至少要选中的音程数（少于 2 个无法构成辨别任务）。
  static const int minSelectedIntervals = 2;

  /// 每日目标题数默认值。
  static const int defaultDailyGoalQuestions = 20;

  /// 二选一模式的选项数。
  static const int binaryOptionCount = 2;

  /// 同一音程连续出现的最大次数，避免自适应出题退化成刷同一题。
  static const int maxConsecutiveSameInterval = 2;

  // ---------------------------------------------------------------------------
  // 掌握度与统计
  // ---------------------------------------------------------------------------

  /// 掌握度置信收缩系数：`p̂ = (correct + k·prior) / (n + k)`。
  ///
  /// k 越大越保守。取 5 意味着「n=2 全对」也不会被判成已掌握（验收要求）。
  static const double kMasteryConfidenceK = 5.0;

  /// 掌握度先验正确率。
  static const double masteryPrior = 0.5;

  /// 判定「已掌握」的收缩后正确率阈值。
  static const double masteryStrongThreshold = 0.85;

  /// 判定「巩固中」的收缩后正确率阈值。
  static const double masteryMediumThreshold = 0.65;

  /// 低于该样本数一律归为「样本不足」。
  static const int masteryMinSamples = 8;

  /// 报告页混淆矩阵展示的 TOP 条目数（compact 布局）。
  static const int confusionTopCount = 8;

  /// 趋势图默认展示天数。
  static const int trendDefaultDays = 7;

  // ---------------------------------------------------------------------------
  // 缓存
  // ---------------------------------------------------------------------------

  /// L1 单音 PCM 缓存容量（条）。37 个音高 × 2 音色 ≈ 74，留一倍余量。
  static const int noteCacheCapacity = 160;

  /// L2 序列 WAV + Timeline 缓存容量（条）。
  static const int sequenceCacheCapacity = 24;

  /// L3 已加载到音频引擎的 `AudioSource` 缓存容量（条）。
  /// 受引擎句柄数限制，不宜过大。
  static const int loadedSourceCacheCapacity = 8;

  // ---------------------------------------------------------------------------
  // 存储
  // ---------------------------------------------------------------------------

  /// 应用数据子目录名。
  static const String dataDirName = 'interval_ear';

  /// 训练记录 JSONL 按月分片的文件名格式前缀。
  static const String recordsFilePrefix = 'records';

  /// 设置文件名。
  static const String settingsFileName = 'settings.json';

  /// 统计快照文件名。
  static const String statsFileName = 'stats.json';

  /// 原子写入使用的临时文件后缀。
  static const String tempFileSuffix = '.tmp';

  /// 损坏文件的备份后缀。
  static const String backupFileSuffix = '.corrupt.bak';

  /// 连续写失败多少次后才提示用户（架构 §8.2）。
  static const int writeFailureNotifyThreshold = 3;

  // ---------------------------------------------------------------------------
  // 桌面窗口
  // ---------------------------------------------------------------------------

  /// 桌面窗口最小宽度。
  static const double desktopMinWidth = 360;

  /// 桌面窗口最小高度。
  static const double desktopMinHeight = 640;

  /// 桌面窗口默认宽度。
  static const double desktopDefaultWidth = 1200;

  /// 桌面窗口默认高度。
  static const double desktopDefaultHeight = 800;

  /// 恢复窗口几何时允许的单边最大值（逻辑像素）。
  ///
  /// 超过该值一律视为损坏记录并退回默认尺寸，避免把窗口撑到屏幕外后
  /// 用户再也点不到标题栏。
  static const double desktopMaxRestoreExtent = 20000;

  /// macOS 红绿灯按钮占用的左侧宽度（逻辑像素）。
  ///
  /// 自绘顶栏（`WindowDragArea`）必须在左侧让出这段距离，否则内容会压在
  /// 关闭/最小化/全屏三个按钮下面。
  static const double macOSTrafficLightInset = 78;

  // ---------------------------------------------------------------------------
  // 无障碍
  // ---------------------------------------------------------------------------

  /// 文字缩放下界（PRD §2.3）。
  static const double minTextScale = 1.0;

  /// 文字缩放上界。
  static const double maxTextScale = 1.3;

  /// 超过该缩放倍数时，多选答案按钮从 2 列降为 1 列。
  static const double singleColumnTextScaleThreshold = 1.15;

  /// 触控目标最小边长。
  static const double minTouchTarget = 48;
}
