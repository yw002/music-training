import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_state.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';

/// 自由训练配置状态机（T19，架构 §2.4）。
///
/// 持有当前编辑中的 [TrainingConfig]；每次变更都 `copyWith` 并清空校验结果，
/// 避免旧错误提示残留。配置经 [SettingsRepository.saveLastFreeConfig] 持久化，
/// 「开始训练」前用 [TrainingConfig.validate] 拦截非法配置（架构 §8.2：非法配置
/// 来自用户操作，是预期内输入错误，需逐条在 UI 提示而非崩溃）。
class FreeTrainingCubit extends Cubit<FreeTrainingState> {
  /// 创建设置 Cubit。
  FreeTrainingCubit({required SettingsRepository settingsRepo})
      : _settingsRepo = settingsRepo,
        super(FreeTrainingState(config: TrainingConfig.defaults));

  final SettingsRepository _settingsRepo;

  /// 从仓储恢复上次保存的自由训练配置（无记录则为 [TrainingConfig.defaults]）。
  Future<void> load() async {
    final TrainingConfig config = await _settingsRepo.loadLastFreeConfig();
    emit(
      state.copyWith(
        config: config,
        validation: const ValidationResult.valid(),
      ),
    );
  }

  void _commit(TrainingConfig config) {
    emit(
      state.copyWith(
        config: config,
        validation: const ValidationResult.valid(),
      ),
    );
  }

  /// 切换某个音程的选中状态。
  void toggleInterval(IntervalId id) {
    final Set<IntervalId> next =
        Set<IntervalId>.from(state.config.enabledIntervals);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    _commit(state.config.copyWith(enabledIntervals: next));
  }

  /// 设置播放方向。
  void setDirection(DirectionMode mode) =>
      _commit(state.config.copyWith(direction: mode));

  /// 设置根音策略。
  void setRootMode(RootMode mode) =>
      _commit(state.config.copyWith(rootMode: mode));

  /// 设置音色策略。
  void setTimbreMode(TimbreMode mode) =>
      _commit(state.config.copyWith(timbreMode: mode));

  /// 设置题目数量（10 / 20 / 50）。
  void setQuestionCount(int count) =>
      _commit(state.config.copyWith(questionCount: count));

  /// 设置答题模式。
  ///
  /// 切换到二选一时强制恰好保留 2 个音程（架构 §5 T19 验收 ②：binary 恰好 2），
  /// 避免用户停留在非法中间态。
  void setAnswerMode(AnswerMode mode) {
    TrainingConfig next = state.config.copyWith(answerMode: mode);
    if (mode == AnswerMode.binary &&
        next.enabledIntervals.length != AppConfig.binaryOptionCount) {
      final Set<IntervalId> trimmed =
          next.sortedIntervals.take(AppConfig.binaryOptionCount).toSet();
      next = next.copyWith(enabledIntervals: trimmed);
    }
    _commit(next);
  }

  /// 恢复为默认配置（全部 13 音程）。
  void resetToDefault() => _commit(TrainingConfig.defaults);

  /// 持久化当前配置（跨会话保留，重启恢复）。
  Future<void> save() async {
    await _settingsRepo.saveLastFreeConfig(state.config);
  }

  /// 校验并开始训练。
  ///
  /// 返回是否通过校验：不通过时把 [ValidationResult] 写入 state 让 UI 提示，
  /// 且**不**导航（导航由页面在返回 `true` 后执行）。
  bool start() {
    final ValidationResult result = state.config.validate();
    if (!result.isValid) {
      emit(state.copyWith(validation: result));
      return false;
    }
    return true;
  }
}
