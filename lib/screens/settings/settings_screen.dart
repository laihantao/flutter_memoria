import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_ops.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(l10n.settingsSectionPersonal),
          ListTile(
            leading: const Icon(Icons.person_outline,
                color: AppColors.warmBrown),
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
            leading: const Icon(Icons.category_outlined,
                color: AppColors.warmBrown),
            title: Text(l10n.settingsCategories),
            subtitle: Text(l10n.settingsCategoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionWallets),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.warmBrown),
            title: Text(l10n.settingsMyWallets),
            subtitle: Text(l10n.settingsMyWalletsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/wallets'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionBackup),
          ListTile(
            leading: const Icon(Icons.backup_outlined,
                color: AppColors.warmBrown),
            title: Text(l10n.settingsExport),
            subtitle: Text(kIsWeb
                ? l10n.settingsExportMobileOnly
                : l10n.settingsExportNote),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _exportBackup(context, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined,
                color: AppColors.warmBrown),
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
            leading: const Icon(Icons.info_outline, color: AppColors.warmBrown),
            title: const Text('Memora'),
            subtitle: Text(l10n.settingsAppVersion),
          ),
        ],
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
                color: AppColors.warmBrown,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
      );
}
