import 'dart:io' show File, Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/widgets/app_snackbar.dart';
import 'package:interval_ear/features/settings/presentation/widgets/destructive_confirm_button.dart';
import 'package:interval_ear/features/settings/presentation/widgets/setting_section.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';

/// 数据管理分区：导出 / 导入 / 清空（验收 ③④）。
///
/// - 导出：移动端走 `share_plus` 分享 JSON 文本；桌面端走 `file_selector`
///   选保存路径写文件。
/// - 导入：`file_selector` 选文件，解析校验后由 [TrainingRepository.importJson]
///   原子替换全部数据（校验失败转用户提示）。
/// - 清空：长按确认（[DestructiveConfirmButton]）后调用 [TrainingRepository.clearAll]。
class DataManagementSection extends StatelessWidget {
  /// 创建数据管理分区。
  const DataManagementSection({super.key});

  /// 是否桌面端（决定导出走文件选择器还是分享）。
  bool get _isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  Future<void> _export(BuildContext context) async {
    final TrainingRepository repo = context.read<TrainingRepository>();
    try {
      final String json = await repo.exportJson();
      if (_isDesktop) {
        final FileSaveLocation? location = await getSaveLocation(
          suggestedName: 'interval_ear_export',
          acceptedTypeGroups: <XTypeGroup>[
            XTypeGroup(label: 'JSON', extensions: <String>['json']),
          ],
        );
        if (location != null) {
          final File file = File(location.path);
          await file.writeAsString(json);
        }
      } else {
        await SharePlus.instance.share(
        ShareParams(text: json, subject: AppStrings.common.appName),
      );
      }
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.settings.exportSucceeded,
          tone: AppSnackBarTone.success,
        );
      }
    } on Object {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.errors.exportFailed,
          tone: AppSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final TrainingRepository repo = context.read<TrainingRepository>();
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (file == null) {
        return;
      }
      final String content = await file.readAsString();
      await repo.importJson(content);
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.settings.importSucceeded(0),
          tone: AppSnackBarTone.success,
        );
      }
    } on Object {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.errors.importInvalidFormat,
          tone: AppSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _clear(BuildContext context) async {
    final TrainingRepository repo = context.read<TrainingRepository>();
    try {
      await repo.clearAll();
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.settings.clearAllData,
          tone: AppSnackBarTone.success,
        );
      }
    } on Object {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: AppStrings.errors.generic,
          tone: AppSnackBarTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return SettingSection(
      title: AppStrings.settings.dataSection,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(AppStrings.settings.exportRecords),
          contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.md),
          onTap: () => _export(context),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(AppStrings.settings.importRecords),
          contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.md),
          onTap: () => _import(context),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space.md),
          child: DestructiveConfirmButton(
            label: AppStrings.settings.clearAllData,
            confirmLabel: AppStrings.settings.clearDialogConfirm,
            onConfirmed: () => _clear(context),
          ),
        ),
      ],
    );
  }
}
