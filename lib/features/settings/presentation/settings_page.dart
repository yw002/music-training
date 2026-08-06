import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/features/settings/presentation/platform_support.dart';
import 'package:interval_ear/features/settings/presentation/settings_cubit.dart';
import 'package:interval_ear/features/settings/presentation/settings_state.dart';
import 'package:interval_ear/features/settings/presentation/widgets/about_section.dart';
import 'package:interval_ear/features/settings/presentation/widgets/audio_diagnostic_tile.dart';
import 'package:interval_ear/features/settings/presentation/widgets/data_management_section.dart';
import 'package:interval_ear/features/settings/presentation/widgets/setting_section.dart';
import 'package:interval_ear/features/settings/presentation/widgets/setting_segmented_tile.dart';
import 'package:interval_ear/features/settings/presentation/widgets/setting_slider_tile.dart';
import 'package:interval_ear/features/settings/presentation/widgets/setting_switch_tile.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 设置页（T17）：即时编辑并落盘所有设置，驱动全局主题/动效。
class SettingsPage extends StatelessWidget {
  /// 创建设置页。
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (BuildContext context, SettingsState state) {
        final AppSettings settings = state is SettingsLoaded
            ? state.settings
            : AppSettings.defaults;
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.settings.title)),
          body: ListView(
            padding: EdgeInsets.all(tokens.space.md),
            children: <Widget>[
              SettingSection(
                title: AppStrings.settings.appearanceSection,
                children: <Widget>[
                  SettingSegmentedTile<ThemePreference>(
                    title: AppStrings.settings.themeMode,
                    value: settings.themeMode,
                    options: <SegmentOption<ThemePreference>>[
                      SegmentOption(
                        value: ThemePreference.system,
                        label: AppStrings.settings.themeSystem,
                      ),
                      SegmentOption(
                        value: ThemePreference.light,
                        label: AppStrings.settings.themeLight,
                      ),
                      SegmentOption(
                        value: ThemePreference.dark,
                        label: AppStrings.settings.themeDark,
                      ),
                    ],
                    onChanged: (ThemePreference v) =>
                        _update(context, settings.copyWith(themeMode: v)),
                  ),
                  SettingSwitchTile(
                    title: AppStrings.settings.showIntervalShorthand,
                    subtitle: AppStrings.settings.showIntervalShorthandHint,
                    value: settings.showIntervalShorthand,
                    onChanged: (bool v) => _update(
                      context,
                      settings.copyWith(showIntervalShorthand: v),
                    ),
                  ),
                  SettingSegmentedTile<VisualizerStyle>(
                    title: AppStrings.settings.visualizerStyle,
                    value: settings.visualizerStyle,
                    options: <SegmentOption<VisualizerStyle>>[
                      SegmentOption(
                        value: VisualizerStyle.halo,
                        label: AppStrings.settings.visualizerHalo,
                      ),
                      SegmentOption(
                        value: VisualizerStyle.spectrum,
                        label: AppStrings.settings.visualizerSpectrum,
                      ),
                      SegmentOption(
                        value: VisualizerStyle.minimal,
                        label: AppStrings.settings.visualizerMinimal,
                      ),
                    ],
                    onChanged: (VisualizerStyle v) =>
                        _update(context, settings.copyWith(visualizerStyle: v)),
                  ),
                  SettingSegmentedTile<CelebrationLevel>(
                    title: AppStrings.settings.celebrationLevel,
                    value: settings.celebrationLevel,
                    options: <SegmentOption<CelebrationLevel>>[
                      SegmentOption(
                        value: CelebrationLevel.subtle,
                        label: AppStrings.settings.celebrationSubtle,
                      ),
                      SegmentOption(
                        value: CelebrationLevel.rich,
                        label: AppStrings.settings.celebrationFull,
                      ),
                      SegmentOption(
                        value: CelebrationLevel.off,
                        label: AppStrings.settings.celebrationNone,
                      ),
                    ],
                    onChanged: (CelebrationLevel v) => _update(
                      context,
                      settings.copyWith(celebrationLevel: v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.sectionGap),
              SettingSection(
                title: AppStrings.settings.motionSection,
                subtitle: AppStrings.settings.motionHint,
                children: <Widget>[
                  SettingSegmentedTile<MotionPreference>(
                    title: AppStrings.settings.motionPreference,
                    value: settings.motionPreference,
                    options: <SegmentOption<MotionPreference>>[
                      SegmentOption(
                        value: MotionPreference.system,
                        label: AppStrings.settings.motionSystem,
                      ),
                      SegmentOption(
                        value: MotionPreference.full,
                        label: AppStrings.settings.motionFull,
                      ),
                      SegmentOption(
                        value: MotionPreference.reduced,
                        label: AppStrings.settings.motionReduced,
                      ),
                      SegmentOption(
                        value: MotionPreference.off,
                        label: AppStrings.settings.motionOff,
                      ),
                    ],
                    onChanged: (MotionPreference v) => _update(
                      context,
                      settings.copyWith(motionPreference: v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.sectionGap),
              SettingSection(
                title: AppStrings.settings.audioSection,
                children: <Widget>[
                  SettingSegmentedTile<Timbre>(
                    title: AppStrings.settings.timbre,
                    value: settings.defaultTimbre,
                    options: <SegmentOption<Timbre>>[
                      SegmentOption(
                        value: Timbre.keyboard,
                        label: AppStrings.freeTraining.timbreKeyboard,
                      ),
                      SegmentOption(
                        value: Timbre.plucked,
                        label: AppStrings.freeTraining.timbrePlucked,
                      ),
                    ],
                    onChanged: (Timbre v) =>
                        _update(context, settings.copyWith(defaultTimbre: v)),
                  ),
                  SettingSliderTile(
                    title: AppStrings.settings.noteGap,
                    value: settings.defaultNoteGap.inMilliseconds.toDouble(),
                    min: AppConfig.minNoteGapMs.toDouble(),
                    max: AppConfig.maxNoteGapMs.toDouble(),
                    divisions:
                        (AppConfig.maxNoteGapMs - AppConfig.minNoteGapMs) ~/ 40,
                    formatValue: (double v) => '${v.round()} ms',
                    onChanged: (double v) => _update(
                      context,
                      settings.copyWith(
                        defaultNoteGap: Duration(milliseconds: v.round()),
                      ),
                    ),
                  ),
                  SettingSliderTile(
                    title: AppStrings.settings.volume,
                    value: settings.volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    formatValue: (double v) =>
                        AppStrings.unit.percent((v * 100).round()),
                    onChanged: (double v) =>
                        _update(context, settings.copyWith(volume: v)),
                  ),
                  SettingSwitchTile(
                    title: AppStrings.settings.sfxEnabled,
                    value: settings.feedbackSoundEnabled,
                    onChanged: (bool v) => _update(
                      context,
                      settings.copyWith(feedbackSoundEnabled: v),
                    ),
                  ),
                  if (supportsHapticFeedback)
                    SettingSwitchTile(
                      title: AppStrings.settings.hapticsEnabled,
                      value: settings.hapticsEnabled,
                      onChanged: (bool v) =>
                          _update(context, settings.copyWith(hapticsEnabled: v)),
                    ),
                  SettingSwitchTile(
                    title: AppStrings.settings.announcePlayback,
                    value: settings.announcePlayback,
                    onChanged: (bool v) => _update(
                      context,
                      settings.copyWith(announcePlayback: v),
                    ),
                  ),
                  const AudioDiagnosticTile(),
                ],
              ),
              SizedBox(height: tokens.space.sectionGap),
              SettingSection(
                title: AppStrings.settings.trainingSection,
                children: <Widget>[
                  SettingSwitchTile(
                    title: AppStrings.settings.autoAdvance,
                    subtitle: AppStrings.settings.autoAdvanceHint,
                    value: settings.autoNext,
                    onChanged: (bool v) =>
                        _update(context, settings.copyWith(autoNext: v)),
                  ),
                  SettingSliderTile(
                    title: AppStrings.settings.autoNextDelay,
                    value: settings.autoNextDelay.inMilliseconds.toDouble(),
                    min: 0,
                    max: 2000,
                    divisions: 20,
                    formatValue: (double v) => '${v.round()} ms',
                    onChanged: (double v) => _update(
                      context,
                      settings.copyWith(
                        autoNextDelay: Duration(milliseconds: v.round()),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.sectionGap),
              const DataManagementSection(),
              SizedBox(height: tokens.space.sectionGap),
              SettingSection(
                title: AppStrings.settings.aboutSection,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(tokens.space.md),
                    child: const AboutSection(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _update(BuildContext context, AppSettings next) {
    context.read<SettingsCubit>().update(next);
  }
}
