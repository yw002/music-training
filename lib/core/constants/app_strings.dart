/// 全部面向用户的中文文案（架构 §8.5）。
///
/// 为什么集中在一个文件：Widget 里禁止出现裸中文字符串字面量，未来接 i18n 时
/// 只需把 `_XxxStrings` 的实现换成查表，**调用方零改动**。
/// 带参数的文案一律用**方法**而不是字符串拼接，方便未来换成 ICU 复数/性别格式。
///
/// 注意：音程名称（纯一度 / 小二度…）是**领域数据**，绑定 `storageId`，
/// 放在 `IntervalCatalog` 而不是这里。
library;

/// 文案访问入口。
abstract final class AppStrings {
  const AppStrings._();

  /// 应用级通用文案。
  static const CommonStrings common = CommonStrings._();

  /// 单位与格式化片段。
  static const UnitStrings unit = UnitStrings._();

  /// 首页。
  static const HomeStrings home = HomeStrings._();

  /// 训练页（含二选一模式）。
  static const TrainingStrings training = TrainingStrings._();

  /// 作答反馈与错题面板。
  static const FeedbackStrings feedback = FeedbackStrings._();

  /// 一组训练结算页。
  static const SummaryStrings summary = SummaryStrings._();

  /// 自由训练配置页。
  static const FreeTrainingStrings freeTraining = FreeTrainingStrings._();

  /// 报告页。
  static const ReportStrings report = ReportStrings._();

  /// 薄弱音程页。
  static const WeakPairsStrings weakPairs = WeakPairsStrings._();

  /// 设置页。
  static const SettingsStrings settings = SettingsStrings._();

  /// 关于页。
  static const AboutStrings about = AboutStrings._();

  /// 错误与降级提示。
  static const ErrorStrings errors = ErrorStrings._();

  /// 无障碍语义标签（仅供 `Semantics.label`，不直接渲染）。
  static const SemanticsStrings a11y = SemanticsStrings._();
}

/// 通用文案。
final class CommonStrings {
  const CommonStrings._();

  /// 应用名。
  String get appName => '音程听辨训练';

  /// 页面尚未接入时的占位提示（仅开发期可见）。
  String get pageUnderConstruction => '该页面正在开发中';

  /// 未登记的路由。
  String get unknownRoute => '页面不存在';

  /// 确认。
  String get confirm => '确认';

  /// 取消。
  String get cancel => '取消';

  /// 完成。
  String get done => '完成';

  /// 保存。
  String get save => '保存';

  /// 重试。
  String get retry => '重试';

  /// 关闭。
  String get close => '关闭';

  /// 返回。
  String get back => '返回';

  /// 继续。
  String get continueAction => '继续';

  /// 开始。
  String get start => '开始';

  /// 暂停。
  String get pause => '暂停';

  /// 恢复。
  String get resume => '恢复';

  /// 退出。
  String get exit => '退出';

  /// 删除。
  String get delete => '删除';

  /// 查看全部。
  String get viewAll => '查看全部';

  /// 更多。
  String get more => '更多';

  /// 加载中。
  String get loading => '加载中';

  /// 暂无数据。
  String get empty => '暂无数据';

  /// 知道了。
  String get gotIt => '知道了';

  /// 是。
  String get yes => '是';

  /// 否。
  String get no => '否';

  /// 默认。
  String get defaultLabel => '默认';

  /// 自定义。
  String get custom => '自定义';

  /// 多条校验提示之间的分隔符。
  String get issueSeparator => '；';

  /// 全选。
  String get selectAll => '全选';

  /// 全不选。
  String get selectNone => '全不选';

  /// 反选。
  String get invertSelection => '反选';

  /// 推荐。
  String get recommended => '推荐';
}

/// 单位与数值格式化片段。
final class UnitStrings {
  const UnitStrings._();

  /// `1.8 次`。
  String times(String value) => '$value 次';

  /// `3.2 秒`。
  String seconds(String value) => '$value 秒';

  /// `4 分钟`。
  String minutes(String value) => '$value 分钟';

  /// `2 小时`。
  String hours(String value) => '$value 小时';

  /// `3 天`。
  String days(String value) => '$value 天';

  /// `5 个半音`。
  String semitones(int value) => '$value 个半音';

  /// `85%`。
  String percent(int value) => '$value%';

  /// `12 题`。
  String questions(int value) => '$value 题';

  /// `3 组`。
  String sessions(int value) => '$value 组';

  /// 少于一分钟时的兜底表述。
  String get lessThanOneMinute => '不到 1 分钟';

  /// 时间轴上的「今天」。
  String get today => '今天';

  /// 时间轴上的「昨天」。
  String get yesterday => '昨天';

  /// `3 天前`。
  String daysAgo(int value) => '$value 天前';

  /// `3月14日`。
  String monthDay(int month, int day) => '$month月$day日';
}

/// 首页文案。
final class HomeStrings {
  const HomeStrings._();

  /// 页面标题。
  String get title => '首页';

  /// 清晨问候。
  String get greetingMorning => '早上好';

  /// 午间问候。
  String get greetingAfternoon => '下午好';

  /// 夜间问候。
  String get greetingEvening => '晚上好';

  /// 今日练习大卡标题。
  String get todayCardTitle => '今日练习';

  /// 今日练习大卡副标题。
  String get todayCardSubtitle => '每天一组，稳定进步';

  /// 今日练习按钮。
  String get startTodayTraining => '开始今日练习';

  /// 继续未完成的一组。
  String get resumeSession => '继续上次训练';

  /// 自由训练入口。
  String get freeTrainingEntry => '自由训练';

  /// 自由训练入口说明。
  String get freeTrainingHint => '自选音程与音色，随练随停';

  /// 二选一对比入口。
  String get binaryTrainingEntry => '二选一对比';

  /// 二选一对比说明。
  String get binaryTrainingHint => '专攻最易混淆的两个音程';

  /// 报告入口。
  String get reportEntry => '训练报告';

  /// 薄弱音程分区标题。
  String get weakSectionTitle => '薄弱音程';

  /// 薄弱音程为空时的提示。
  String get weakSectionEmpty => '数据还不够，先练几组吧';

  /// 连续练习天数。
  String streakDays(int days) => '已连续练习 $days 天';

  /// 今日进度。
  String todayProgress(int done, int goal) => '今日 $done / $goal 题';

  /// 今日目标已完成。
  String get todayGoalReached => '今日目标已完成';

  /// 总体正确率标签。
  String get overallAccuracy => '总体正确率';

  /// 今日用时标签。
  String get todayDuration => '今日用时';
}

/// 训练页文案。
final class TrainingStrings {
  const TrainingStrings._();

  /// 页面标题。
  String get title => '训练';

  /// 二选一模式标题。
  String get binaryTitle => '二选一对比';

  /// 进度：第 3 / 20 题。
  String questionProgress(int current, int total) => '第 $current / $total 题';

  /// 重播按钮。
  String get replay => '重播';

  /// 播放按钮。
  String get play => '播放';

  /// 「不确定」作答按钮。
  String get uncertain => '不确定';

  /// 下一题。
  String get next => '下一题';

  /// 提交答案。
  String get submit => '提交';

  /// 结束本组。
  String get finishSession => '结束本组';

  /// 引导：听完后选择你听到的音程。
  String get prompt => '选择你听到的音程';

  /// 二选一引导。
  String get binaryPrompt => '这两个音之间是哪个音程？';

  /// 交替对比播放按钮（A/B 对比）。
  String get compareAb => '交替对比';

  /// 播放 A。
  String get playA => '播放 A';

  /// 播放 B。
  String get playB => '播放 B';

  /// 连击提示。
  String comboCount(int count) => '连击 $count';

  /// 章节推进提示。
  String chapterAdvance(String chapterName) => '进入 $chapterName';

  /// 半音数角标（色盲可辨规则中的必选项）。
  String semitoneCount(int count) => '$count 个半音';

  /// 退出确认标题。
  String get quitDialogTitle => '结束这一组训练？';

  /// 退出确认正文。
  String get quitDialogBody => '当前进度会保存，可以随时继续。';

  /// 退出确认按钮。
  String get quitDialogConfirm => '结束训练';

  /// 键盘快捷键提示。
  String get shortcutHint => '数字键选择答案，空格重播，回车下一题';

  /// 桌面右侧栏快捷键面板标题（expanded 断点常驻展示）。
  String get shortcutPanelTitle => '键盘快捷键';

  /// 重播按钮桌面 tooltip（M-33，仅桌面显示）。
  String get replayTooltip => '重播（空格）';

  /// 「不确定」按钮桌面 tooltip。
  String get uncertainTooltip => '不确定（U 键）';

  /// 「下一题」按钮桌面 tooltip。
  String get nextTooltip => '下一题（回车）';
}

/// 作答反馈与错题面板。
final class FeedbackStrings {
  const FeedbackStrings._();

  /// 答对。
  String get correct => '答对了';

  /// 答错。
  String get wrong => '答错了';

  /// 选择「不确定」后的中性反馈。
  String get uncertain => '标记为不确定';

  /// 错题面板标题。
  String get wrongPanelTitle => '再听一次差别';

  /// 正确答案标签。
  String get correctAnswer => '正确答案';

  /// 你的答案标签。
  String get yourAnswer => '你的答案';

  /// 半音尺标题。
  String get semitoneRulerTitle => '半音距离对比';

  /// 半音差说明。
  String semitoneDelta(int delta) => '相差 $delta 个半音';

  /// 同半音数（等音程）说明。
  String get sameSemitones => '半音数相同';

  /// 记住这个差别的引导。
  String get memoHint => '注意听两者的宽窄差异';

  /// 加入强化练习。
  String get addToDrill => '加入强化练习';

  /// 已加入强化练习。
  String get addedToDrill => '已加入强化练习';
}

/// 结算页文案。
final class SummaryStrings {
  const SummaryStrings._();

  /// 页面标题。
  String get title => '本组小结';

  /// 正确率标签。
  String get accuracy => '正确率';

  /// 用时标签。
  String get duration => '用时';

  /// 平均反应时间标签。
  String get averageResponse => '平均反应';

  /// 平均重播次数标签。
  String get averageReplay => '平均重播';

  /// 最长连击标签。
  String get bestCombo => '最长连击';

  /// 错题数标签。
  String get wrongCount => '错题';

  /// 再来一组。
  String get playAgain => '再来一组';

  /// 查看报告。
  String get viewReport => '查看报告';

  /// 查看本组小结。
  String get viewSummary => '查看小结';

  /// 回到首页。
  String get backHome => '回到首页';

  /// 高分鼓励语。
  String get praiseHigh => '状态很好，继续保持';

  /// 中等鼓励语。
  String get praiseMedium => '稳步提升中';

  /// 低分鼓励语。
  String get praiseLow => '多听几遍差别就出来了';

  /// 本组新掌握的音程。
  String newlyMastered(int count) => '新掌握 $count 个音程';
}

/// 自由训练配置页。
final class FreeTrainingStrings {
  const FreeTrainingStrings._();

  /// 页面标题。
  String get title => '自由训练';

  /// 音程选择分区。
  String get intervalSection => '训练音程';

  /// 方向分区。
  String get directionSection => '播放方向';

  /// 上行。
  String get directionAscending => '上行';

  /// 下行。
  String get directionDescending => '下行';

  /// 和声（同时发声）。
  String get directionHarmonic => '和声';

  /// 随机混合。
  String get directionRandomMixed => '随机混合';

  /// 根音分区。
  String get rootSection => '根音范围';

  /// 固定根音。
  String get rootFixed => '固定根音';

  /// 有限随机。
  String get rootLimitedRandom => '有限随机';

  /// 完全随机。
  String get rootFullRandom => '完全随机';

  /// 音色分区。
  String get timbreSection => '音色';

  /// 合成键盘。
  String get timbreKeyboard => '合成键盘';

  /// 合成拨弦。
  String get timbrePlucked => '合成拨弦';

  /// 题数分区。
  String get questionCountSection => '题目数量';

  /// 音符时长。
  String get noteDurationSection => '单音时长';

  /// 音符间隔。
  String get noteGapSection => '音符间隔';

  /// 开始训练。
  String get startTraining => '开始训练';

  /// 至少选择两个音程的校验提示。
  String get needAtLeastTwoIntervals => '至少选择 2 个音程';

  /// 答题模式：全部 13 音程。
  String get answerModeAll => '全部音程';

  /// 答题模式：仅所选音程。
  String get answerModeEnabled => '仅所选音程';

  /// 答题模式：二选一。
  String get answerModeBinary => '二选一';

  /// 二选一模式恰好需要 2 个音程的校验提示。
  String get binaryNeedsExactlyTwo => '二选一模式需要恰好 2 个音程';

  /// 题数越界的校验提示。
  String get questionCountOutOfRange => '题目数量超出允许范围';

  /// 单音时长越界的校验提示。
  String get noteDurationOutOfRange => '单音时长超出允许范围';

  /// 音符间隔越界的校验提示。
  String get noteGapOutOfRange => '音符间隔超出允许范围';

  /// 通用配置无效提示。
  String get invalidConfig => '配置无效，请检查后重试';

  /// 「全部 13 音程」与「今日推荐」的差异说明。
  String get allVsTodayHint => '全部 13 音程：覆盖所有音程，适合系统巩固；今日推荐会根据你的掌握情况自适应挑选。';

  /// 恢复默认配置。
  String get resetToDefault => '恢复默认';
}

/// 报告页文案。
final class ReportStrings {
  const ReportStrings._();

  /// 页面标题。
  String get title => '训练报告';

  /// 总览分区。
  String get overviewSection => '总览';

  /// 趋势分区。
  String get trendSection => '正确率趋势';

  /// 各音程表现分区。
  String get perIntervalSection => '各音程表现';

  /// 混淆矩阵分区。
  String get confusionSection => '易混淆音程';

  /// 累计题数。
  String get totalQuestions => '累计题数';

  /// 累计时长。
  String get totalDuration => '累计时长';

  /// 掌握音程数。
  String get masteredCount => '已掌握';

  /// 练习天数。
  String get practiceDays => '练习天数';

  /// 总体正确率。
  String get overallAccuracy => '总体正确率';

  /// 时间范围：近 7 天。
  String get range7Days => '近 7 天';

  /// 时间范围：近 30 天。
  String get range30Days => '近 30 天';

  /// 时间范围：全部。
  String get rangeAll => '全部';

  /// 混淆条目：把 A 听成了 B。
  String confusionPair(String actual, String answered) =>
      '把 $actual 听成 $answered';

  /// 混淆次数。
  String confusionTimes(int count) => '$count 次';

  /// 掌握度分桶：已掌握。
  String get masteryStrong => '已掌握';

  /// 掌握度分桶：巩固中。
  String get masteryMedium => '巩固中';

  /// 掌握度分桶：薄弱。
  String get masteryWeak => '薄弱';

  /// 掌握度分桶：样本不足。
  String get masteryUnknown => '样本不足';

  /// 维度表现分区。
  String get dimensionSection => '维度表现';

  /// 每日练习热力分区。
  String get heatmapSection => '每日练习';

  /// 空数据态的引导提示。
  String get emptyHint => '完成几组训练后，这里会展示你的进步曲线';

  /// 导出数据。
  String get exportData => '导出数据';

  /// 数据量不足时的空态。
  String get notEnoughData => '再练几组就能看到趋势了';
}

/// 薄弱音程页。
final class WeakPairsStrings {
  const WeakPairsStrings._();

  /// 页面标题。
  String get title => '薄弱音程';

  /// 列表分区标题。
  String get listSection => '按易错程度排序';

  /// 针对某个音程开始强化。
  String drillInterval(String intervalName) => '强化 $intervalName';

  /// 针对某一对音程开始二选一。
  String drillPair(String a, String b) => '对比 $a 与 $b';

  /// 空态。
  String get empty => '暂时没有明显薄弱的音程';
}

/// 设置页文案。
final class SettingsStrings {
  const SettingsStrings._();

  /// 页面标题。
  String get title => '设置';

  /// 外观分区。
  String get appearanceSection => '外观';

  /// 主题模式。
  String get themeMode => '主题';

  /// 跟随系统。
  String get themeSystem => '跟随系统';

  /// 浅色。
  String get themeLight => '浅色';

  /// 深色。
  String get themeDark => '深色';

  /// 显示音程英文简称。
  String get showIntervalShorthand => '显示英文简称';

  /// 显示音程英文简称说明。
  String get showIntervalShorthandHint => '在音程标签上显示 P1 / m2 / M3 等';

  /// 动效分区。
  String get motionSection => '动效';

  /// 动效强度。
  String get motionPreference => '动效强度';

  /// 动效：跟随系统。
  String get motionSystem => '跟随系统';

  /// 动效：完整。
  String get motionFull => '完整';

  /// 动效：精简。
  String get motionReduced => '精简';

  /// 动效：关闭。
  String get motionOff => '关闭';

  /// 动效强度说明。
  String get motionHint => '精简与关闭会保留必要的状态提示';

  /// 可视化方案。
  String get visualizerStyle => '播放可视化';

  /// 可视化：光环呼吸。
  String get visualizerHalo => '光环呼吸';

  /// 可视化：频谱粒子。
  String get visualizerSpectrum => '频谱粒子';

  /// 可视化：极简。
  String get visualizerMinimal => '极简';

  /// 庆祝强度。
  String get celebrationLevel => '答对庆祝强度';

  /// 庆祝：无。
  String get celebrationNone => '无';

  /// 庆祝：轻微。
  String get celebrationSubtle => '轻微';

  /// 庆祝：完整。
  String get celebrationFull => '完整';

  /// 音频分区。
  String get audioSection => '音频';

  /// 音频后端诊断项。
  String get audioBackend => '音频后端';

  /// 音色。
  String get timbre => '音色';

  /// 单音时长。
  String get noteDuration => '单音时长';

  /// 音符间隔。
  String get noteGap => '音符间隔';

  /// 音量。
  String get volume => '音量';

  /// 反馈音开关。
  String get sfxEnabled => '答题反馈音';

  /// 触觉反馈开关。
  String get hapticsEnabled => '触觉反馈';

  /// 播放时朗读音程名。
  String get announcePlayback => '答题后朗读结果';

  /// 自动进入下一题延迟。
  String get autoNextDelay => '自动进入下一题延迟';

  /// 训练分区。
  String get trainingSection => '训练';

  /// 每组题数。
  String get questionsPerSession => '每组题数';

  /// 每日目标。
  String get dailyGoal => '每日目标';

  /// 自动播放下一题。
  String get autoAdvance => '自动进入下一题';

  /// 自动播放下一题说明。
  String get autoAdvanceHint => '答对后自动进入，答错时始终等待手动确认';

  /// 数据分区。
  String get dataSection => '数据';

  /// 导出训练记录。
  String get exportRecords => '导出训练记录';

  /// 导入训练记录。
  String get importRecords => '导入训练记录';

  /// 清空全部数据。
  String get clearAllData => '清空全部数据';

  /// 清空确认标题。
  String get clearDialogTitle => '清空全部训练数据？';

  /// 清空确认正文。
  String get clearDialogBody => '此操作不可撤销，所有历史记录与统计都会被删除。';

  /// 清空确认按钮（长按确认）。
  String get clearDialogConfirm => '长按确认清空';

  /// 导出成功。
  String get exportSucceeded => '导出成功';

  /// 导入成功。
  String importSucceeded(int count) => '已导入 $count 条记录';

  /// 关于分区。
  String get aboutSection => '关于';

  /// 音频正常。
  String get audioNormal => '音频正常';
}

/// 关于页。
final class AboutStrings {
  const AboutStrings._();

  /// 页面标题。
  String get title => '关于';

  /// 版本号标签。
  String version(String version) => '版本 $version';

  /// 应用简介。
  String get intro => '一个专注音程听辨的离线训练工具，所有音频由本机实时合成。';

  /// 数据存储位置说明。
  String get storageNotice => '训练数据仅保存在本机，不会上传。';

  /// 开源许可。
  String get licenses => '开源许可';
}

/// 错误与降级提示。
final class ErrorStrings {
  const ErrorStrings._();

  /// 通用错误。
  String get generic => '出了点问题，请稍后再试';

  /// 音频不可用常驻 banner。
  String get audioUnavailable => '音频不可用，训练暂时只能查看不能播放';

  /// 音频不可用 banner 的操作按钮。
  String get audioUnavailableAction => '重新检测';

  /// 单次播放失败。
  String get playbackFailed => '播放失败，可以点重播再试一次';

  /// 读取设置失败（已降级到默认值）。
  String get settingsReadFailed => '设置读取失败，已使用默认设置';

  /// 写入失败（连续 3 次后才提示）。
  String get storageWriteFailed => '数据保存失败，请检查存储空间';

  /// 记录文件损坏并已重建。
  String recordsRecovered(int droppedLines) =>
      '部分历史记录损坏，已跳过 $droppedLines 行并修复文件';

  /// 导出失败。
  String get exportFailed => '导出失败';

  /// 导入失败：文件格式不正确。
  String get importInvalidFormat => '导入失败：文件格式不正确';

  /// 导入失败：版本过新。
  String get importUnsupportedVersion => '导入失败：文件版本高于当前应用';

  /// 未知路由兜底页标题。
  String get routeNotFoundTitle => '页面不存在';

  /// 未知路由兜底页正文。
  String routeNotFoundBody(String routeName) => '找不到路由「$routeName」';

  /// release 模式下的全局错误页标题。
  String get fatalTitle => '应用遇到问题';

  /// release 模式下的全局错误页正文。
  String get fatalBody => '已记录该问题，重启应用即可继续训练。';
}

/// 无障碍语义标签。
final class SemanticsStrings {
  const SemanticsStrings._();

  /// 播放按钮语义。
  String get playButton => '播放音程';

  /// 重播按钮语义。
  String get replayButton => '重播音程';

  /// 答案按钮语义：音程名 + 半音数。
  String answerOption(String intervalName, int semitones) =>
      '$intervalName，$semitones 个半音';

  /// 进度语义。
  String progress(int current, int total) => '进度：第 $current 题，共 $total 题';

  /// 正确率语义。
  String accuracy(int percent) => '正确率 $percent%';

  /// 加载中语义。
  String get loading => '正在加载';
}
