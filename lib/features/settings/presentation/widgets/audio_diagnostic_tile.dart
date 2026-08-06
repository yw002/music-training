import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/soloud_audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 音频后端诊断项（验收 ⑥）：展示当前音频后端与可用性。
class AudioDiagnosticTile extends StatelessWidget {
  /// 创建音频诊断项。
  const AudioDiagnosticTile({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AudioService audio = context.read<AudioService>();
    final bool available = audio.isAvailable;
    final String backend = audio is SoLoudAudioService
        ? 'SoLoud 音频引擎'
        : '离线降级（无音频输出）';
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.md),
      leading: Icon(
        available ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: available ? tokens.color.success.base : tokens.color.warning.base,
      ),
      title: Text(AppStrings.settings.audioBackend, style: tokens.type.bodyLarge),
      subtitle: Text(
        '$backend · ${available ? '音频可用' : '音频不可用'}',
        style: tokens.type.bodySmall?.copyWith(
          color: tokens.scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
