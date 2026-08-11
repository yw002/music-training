import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/sfx_catalog.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/services/session_runner.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_state.dart';

/// 训练页状态机驱动器（架构 §3.5 / T10）。
///
/// 职责边界（严格遵守「Cubit 只做 domain↔UI 映射 + 副作用编排」）：
/// - 委托 [SessionRunner] 管理「出题→作答→统计→结算」工作流（领域状态唯一真相）；
/// - 委托 [AudioService] 播放；通过 [TrainingRepository] 落盘与加载统计；
/// - 把领域事件翻译成 [TrainingState] 供 UI 渲染；
/// - **不**持有任何音高/频率计算，所有播放可视化幅度由 UI 层走 `EnvelopeSampler`。
///
/// 状态机：`initial → loading → ready → playing → awaitingAnswer → answered
/// → (next) → ready/playing … → finished`。
class TrainingCubit extends Cubit<TrainingState> {
  /// 创建训练 Cubit。
  ///
  /// [config] 本组不可变配置；[repository] 落盘/读统计；[audio] 播放服务；
  /// [settings] 用户设置（反馈音、自动下一题、可视化/庆祝强度）；
  /// [random] 随机源（可注入 seed 做可复现测试）；[clock] 时钟（同样可注入）。
  /// [onActiveSessionChanged] 是「进行中会话」的对外广播口（T23 验收 ⑥）：
  /// 开局与每次作答后回调最新的 [TrainingSession]，结算 / 关闭时回调 `null`。
  /// 应用根据此维护进程级登记处，在退到后台或关窗时把没打完的一组标记为
  /// `aborted` 落盘。故意用回调而非直接依赖 `app/` 层对象，避免
  /// `features → app` 的反向依赖；留空则完全无副作用（单测默认路径）。
  TrainingCubit({
    required TrainingConfig config,
    required TrainingRepository repository,
    required AudioService audio,
    required AppSettings settings,
    math.Random? random,
    DateTime Function()? clock,
    void Function(TrainingSession? session)? onActiveSessionChanged,
  })  : _config = config,
        _repository = repository,
        _audio = audio,
        _settings = settings,
        _random = random ?? math.Random(),
        _clock = clock ?? DateTime.now,
        _onActiveSessionChanged = onActiveSessionChanged,
        super(const TrainingInitial());

  final TrainingConfig _config;
  final TrainingRepository _repository;
  final AudioService _audio;
  final AppSettings _settings;
  final math.Random _random;
  final DateTime Function() _clock;
  final void Function(TrainingSession? session)? _onActiveSessionChanged;

  SessionRunner? _runner;
  int _playbackId = 0;
  int _replayCount = 0;
  DateTime? _questionReadyAt;
  PlaybackProgress? _lastProgress;
  StreamSubscription<AudioPlaybackEvent>? _audioSub;
  bool _isSubmitting = false;

  /// 用户设置（UI 读取可视化/庆祝强度）。
  AppSettings get settings => _settings;

  @override
  Future<void> close() async {
    await _audioSub?.cancel();
    await _audio.stop();
    await _repository.flush();
    // 页面销毁后这一组不再「进行中」：不清会导致后续退到后台时误判为中途退出。
    _onActiveSessionChanged?.call(null);
    await super.close();
  }

  /// 启动一组训练：加载先验统计 → 组卷 → 记录会话开始 → 自动播第一题。
  Future<void> start() async {
    if (_runner != null) {
      return;
    }
    emit(const TrainingLoading());
    final priorSnapshot = await _safeLoadStats();
    _runner = SessionRunner.start(
      config: _config,
      priorSnapshot: priorSnapshot,
      random: _random,
      now: _clock(),
      trainingMode: _config.answerMode == AnswerMode.binary
          ? TrainingMode.binaryDrill
          : TrainingMode.daily,
    );
    await _repository.startSession(_runner!.session);
    _onActiveSessionChanged?.call(_runner!.session);
    _audioSub ??= _audio.events.listen(_onAudioEvent);
    _loadQuestion(isFirst: true);
  }

  Future<StatsSnapshot> _safeLoadStats() async {
    try {
      return await _repository.loadStats();
    } on Object catch (e, st) {
      AppLogger.warning(
        'loadStats 失败，使用空快照',
        tag: 'TrainingCubit',
        error: e,
        stackTrace: st,
      );
      return StatsSnapshot.empty();
    }
  }

  void _loadQuestion({required bool isFirst}) {
    final runner = _runner;
    if (runner == null || !runner.hasNext) {
      _finish();
      return;
    }
    final question = runner.currentQuestion!;
    _replayCount = 0;
    _questionReadyAt = null;
    emit(
      TrainingReady(
        question: question,
        answerOptions: question.answerOptions,
        index: runner.completedCount,
        total: runner.plannedCount + runner.extraDrillCount,
        combo: runner.combo,
        canReplay: _config.allowReplay,
      ),
    );
    _playCurrent();
  }

  Future<void> _playCurrent() async {
    final runner = _runner;
    if (runner == null) {
      return;
    }
    final question = runner.currentQuestion;
    if (question == null) {
      _finish();
      return;
    }
    final spec =
        AudioSequenceSpec.fromQuestion(question, noteGap: _config.noteGap);
    try {
      final int id = await _audio.playSequence(spec);
      if (isClosed) {
        return;
      }
      _playbackId = id;
      _lastProgress = PlaybackProgress(
        playbackId: id,
        noteIndex: -1,
        timbre: question.timbre,
        position: Duration.zero,
        noteDuration: spec.noteDuration,
      );
      emit(
        TrainingPlaying(
          question: question,
          answerOptions: question.answerOptions,
          index: runner.completedCount,
          total: runner.plannedCount + runner.extraDrillCount,
          combo: runner.combo,
          canReplay: _config.allowReplay,
          playback: _lastProgress!,
        ),
      );
      // 加载、起播或后端不可用时，服务会返回 id 但不会进入播放。
      if (!_audio.isPlaying) {
        _enterAwaiting();
      }
    } on Object catch (e, st) {
      AppLogger.warning('playSequence 失败',
          tag: 'TrainingCubit', error: e, stackTrace: st);
      _enterAwaiting();
    }
  }

  void _onAudioEvent(AudioPlaybackEvent event) {
    if (event.playbackId != _playbackId) {
      return;
    }
    switch (event.type) {
      case AudioEventType.noteStart:
        _lastProgress = PlaybackProgress(
          playbackId: event.playbackId,
          noteIndex: event.noteIndex,
          timbre: event.timbre,
          position: event.position,
          noteDuration: event.noteDuration,
        );
      case AudioEventType.sequenceStart:
        _lastProgress = PlaybackProgress(
          playbackId: event.playbackId,
          noteIndex: -1,
          timbre: event.timbre,
          position: Duration.zero,
          noteDuration: const Duration(milliseconds: 1100),
        );
      case AudioEventType.sequenceEnd:
      case AudioEventType.error:
        _enterAwaiting();
      case AudioEventType.cancelled:
      case AudioEventType.noteEnd:
      case AudioEventType.segmentStart:
        break;
    }
  }

  void _enterAwaiting() {
    final runner = _runner;
    if (runner == null) {
      return;
    }
    if (state is! TrainingPlaying && state is! TrainingReady) {
      return;
    }
    _questionReadyAt ??= _clock();
    emit(
      TrainingAwaitingAnswer(
        question: runner.currentQuestion!,
        answerOptions: runner.currentQuestion!.answerOptions,
        index: runner.completedCount,
        total: runner.plannedCount + runner.extraDrillCount,
        combo: runner.combo,
        canReplay: _config.allowReplay,
        replayCount: _replayCount,
        lastPlayback: _lastProgress,
      ),
    );
  }

  /// 重播当前题目（仅 [TrainingAwaitingAnswer] 且允许重播时有效）。
  void replay() {
    final s = state;
    if (s is! TrainingAwaitingAnswer || !s.canReplay) {
      return;
    }
    _replayCount += 1;
    _playCurrent();
  }

  /// 提交一个明确答案。
  Future<void> submitAnswer(IntervalId selected) async {
    final s = state;
    if (s is! TrainingAwaitingAnswer) {
      return;
    }
    await _submit(selectedInterval: selected, isUncertain: false);
  }

  /// 标记为「不确定」。
  Future<void> submitUncertain() async {
    final s = state;
    if (s is! TrainingAwaitingAnswer) {
      return;
    }
    await _submit(selectedInterval: null, isUncertain: true);
  }

  Future<void> _submit({
    required IntervalId? selectedInterval,
    required bool isUncertain,
  }) async {
    final runner = _runner;
    if (runner == null || _isSubmitting) {
      return;
    }
    _isSubmitting = true;
    try {
      final responseDuration = _questionReadyAt == null
          ? Duration.zero
          : _clock().difference(_questionReadyAt!);
      final attempt = runner.answer(
        selectedInterval: selectedInterval,
        isUncertain: isUncertain,
        replayCount: _replayCount,
        responseDuration: responseDuration,
        now: _clock(),
      );
      await _safeRecord(attempt);
      // T23 验收 ⑥：每答一题都刷新登记处，中途退出时落盘的是**当前进度**，
      // 而不是开局那一份空快照。
      _onActiveSessionChanged?.call(runner.session);
      if (_settings.feedbackSoundEnabled) {
        _audio.playSfx(attempt.isCorrect ? SfxId.correct : SfxId.wrong);
      }
      // 已答的那道题在 answer() 后 cursor 已前进，需取 completedCount-1 下标。
      final answeredQuestion = runner.questions[runner.completedCount - 1];
      final isLast = !runner.hasNext;
      emit(
        TrainingAnswered(
          question: answeredQuestion,
          answerOptions: answeredQuestion.answerOptions,
          index: runner.completedCount - 1,
          total: runner.plannedCount + runner.extraDrillCount,
          combo: runner.combo,
          canReplay: _config.allowReplay,
          attempt: attempt,
          isLast: isLast,
          chapterAdvanced: false,
          session: runner.session,
        ),
      );
      if (_settings.autoNext && attempt.isCorrect && !isLast) {
        final delay = _settings.autoNextDelay;
        unawaited(
          Future<void>.delayed(delay).then((_) {
            if (!isClosed && state is TrainingAnswered) {
              next();
            }
          }),
        );
      }
    } finally {
      _isSubmitting = false;
    }
  }

  /// 进入下一题；若已是最后一题则结算。
  Future<void> next() async {
    final s = state;
    if (s is! TrainingAnswered) {
      return;
    }
    if (!s.isLast) {
      _loadQuestion(isFirst: false);
      return;
    }
    _finish();
  }

  Future<void> _safeRecord(TrainingAttempt attempt) async {
    try {
      await _repository.recordAttempt(attempt);
    } on Object catch (e, st) {
      AppLogger.warning('recordAttempt 失败',
          tag: 'TrainingCubit', error: e, stackTrace: st);
    }
  }

  Future<void> _finish() async {
    final runner = _runner;
    if (runner == null) {
      emit(
        TrainingFinished(
          session: TrainingSession(
            sessionId: '',
            trainingMode: TrainingMode.daily,
            startedAt: _epoch,
            totalQuestions: 0,
            configSnapshot: TrainingConfig.defaults,
          ),
          snapshot: StatsSnapshot.empty(),
          chapterAdvanced: false,
        ),
      );
      return;
    }
    runner.finishNow(_clock());
    final mistakes = runner.attempts.where((a) => !a.isCorrect).toList();
    final session = runner.session.copyWith(mistakes: mistakes);
    try {
      await _repository.finishSession(session);
    } on Object catch (e, st) {
      AppLogger.warning('finishSession 失败',
          tag: 'TrainingCubit', error: e, stackTrace: st);
    }
    // 正常结算完毕：撤销登记，之后再退到后台也不会被误判为「中途退出」。
    _onActiveSessionChanged?.call(null);
    final chapterAdvanced = await _checkChapterAdvance();
    emit(
      TrainingFinished(
        session: session,
        snapshot: runner.updatedSnapshot,
        chapterAdvanced: chapterAdvanced,
        chapterName: null,
      ),
    );
  }

  Future<bool> _checkChapterAdvance() async {
    final runner = _runner;
    if (runner == null || runner.presetId == null) {
      return false;
    }
    try {
      final recent =
          await _repository.recentSessions(kChapterAdvanceMinSessions + 4);
      return SessionRunner.shouldAdvanceChapter(recent,
          presetId: runner.presetId);
    } on Object catch (e, st) {
      AppLogger.warning('章节推进判定失败',
          tag: 'TrainingCubit', error: e, stackTrace: st);
      return false;
    }
  }

  /// 中途退出：结算当前进度并保存。
  Future<void> abort() async {
    if (_runner == null) {
      return;
    }
    await _finish();
  }
}

/// 兜底纪元常量（无 runner 时的结算兜底用）。
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
