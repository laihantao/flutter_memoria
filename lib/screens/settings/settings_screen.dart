import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/file_ops.dart';
import '../../widgets/theme_background.dart';
import '../../widgets/theme_picker_grid.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ThemeBackground(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(l10n.settingsSectionPersonal),
          ListTile(
            leading: Icon(Icons.person_outline,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: Text(l10n.settingsMyProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final db = ref.read(databaseProvider);
              final self = await db.personDao.getSelfPerson();
              if (self != null && context.mounted) {
                context.push('/people/${self.id}');
              }
            },
          ),
          const Divider(),
          _SectionHeader('外观'),
          const ThemePickerGrid(),
          const SizedBox(height: 12),
          _AnimationsToggle(),
          _DecorationDensitySlider(),
          _AnimationSpeedSlider(),
          const Divider(),
          _SectionHeader(l10n.settingsSectionLanguage),
          RadioGroup<Locale>(
            groupValue: currentLocale,
            onChanged: (v) {
              if (v != null) ref.read(localeProvider.notifier).setLocale(v);
            },
            child: Column(
              children: AppLocalizations.supportedLocales.map((locale) {
                final label = locale.languageCode == 'zh'
                    ? l10n.langZh
                    : l10n.langEn;
                return RadioListTile<Locale>(
                  title: Text(label),
                  value: locale,
                );
              }).toList(),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionMoments),
          ListTile(
            leading: Icon(Icons.category_outlined,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: Text(l10n.settingsCategories),
            subtitle: Text(l10n.settingsCategoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),
          ListTile(
            leading: Icon(Icons.receipt_long_outlined,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: const Text('费用分类'),
            subtitle: const Text('记账分类的图标与排序'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/expense-categories'),
          ),
          ListTile(
            leading: Icon(Icons.paid_outlined,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: const Text('货币'),
            subtitle: const Text('记账与预算可用的货币'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/currencies'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionBackup),
          ListTile(
            leading: Icon(Icons.backup_outlined,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: Text(l10n.settingsExport),
            subtitle: Text(kIsWeb
                ? l10n.settingsExportMobileOnly
                : l10n.settingsExportNote),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _exportBackup(context, l10n),
          ),
          ListTile(
            leading: Icon(Icons.restore_outlined,
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: Text(l10n.settingsImport),
            subtitle: Text(kIsWeb
                ? l10n.settingsImportMobileOnly
                : l10n.settingsImportNote),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _importBackup(context, l10n),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAbout),
          ListTile(
            leading: Icon(Icons.info_outline, color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
            title: const Text('Memora'),
            subtitle: Text(l10n.settingsAppVersion),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _exportBackup(
      BuildContext context, AppLocalizations l10n) async {
    try {
      final bytes = await BackupService().exportBackup();
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name:
                  'memora_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
              mimeType: 'application/zip')
        ],
        text: 'Memora 备份',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsExportFailed('$e'))),
        );
      }
    }
  }

  Future<void> _importBackup(
      BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsRestoreTitle),
        content: Text(l10n.settingsRestoreContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsRestoreTitle,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null) return;

    final zipBytes = result.files.single.bytes ??
        (result.files.single.path != null
            ? await readAbsoluteFileBytes(result.files.single.path!)
            : null);

    if (zipBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsCannotRead)),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final loadingSnack = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(l10n.settingsRestoring),
          duration: const Duration(minutes: 5)),
    );

    final error = await BackupService().importBackup(zipBytes);
    loadingSnack.close();

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsRestoreFailed(error))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsRestoreSuccess)),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
      );
}

class _AnimationsToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final enabled = ref.watch(animationsEnabledProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '动态背景效果',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ext.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '关闭后保留主题配色与图标，但不显示动态动画效果，适合性能较弱的设备',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: ext.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: ext.accentColor,
            onChanged: (val) =>
                ref.read(animationsEnabledProvider.notifier).setEnabled(val),
          ),
        ],
      ),
    );
  }
}

class _DecorationDensitySlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final density = ref.watch(decorationDensityProvider);
    final animEnabled = ref.watch(animationsEnabledProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '装饰数量',
                style: GoogleFonts.notoSansSc(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: animEnabled ? ext.textPrimary : ext.textSecondary,
                ),
              ),
              Text(
                '${(density * 100).round()}%',
                style: GoogleFonts.notoSansSc(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: animEnabled ? ext.accentColor : ext.textSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: density,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            activeColor: animEnabled ? ext.accentColor : ext.borderColor,
            inactiveColor: ext.borderColor,
            onChanged: animEnabled
                ? (val) =>
                    ref.read(decorationDensityProvider.notifier).setDensity(val)
                : null,
          ),
        ],
      ),
    );
  }
}

class _AnimationSpeedSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final speed = ref.watch(animationSpeedMultiplierProvider);
    final animEnabled = ref.watch(animationsEnabledProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '动画速度',
                style: GoogleFonts.notoSansSc(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: animEnabled ? ext.textPrimary : ext.textSecondary,
                ),
              ),
              Text(
                '${speed.toStringAsFixed(1)}x',
                style: GoogleFonts.notoSansSc(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: animEnabled ? ext.accentColor : ext.textSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: speed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            activeColor: animEnabled ? ext.accentColor : ext.borderColor,
            inactiveColor: ext.borderColor,
            onChanged: animEnabled
                ? (val) => ref
                    .read(animationSpeedMultiplierProvider.notifier)
                    .setSpeed(val)
                : null,
          ),
        ],
      ),
    );
  }
}
