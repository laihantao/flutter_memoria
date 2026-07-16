import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/expense_provider.dart';
import '../../providers/person_provider.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme_extension.dart';
import 'pdf_preview_screen.dart';

/// 下载/分享 chooser for a generated PDF (Pocket Gold pattern). Shared by the
/// export settings page's 导出 button and the preview screen's app-bar action.
Future<void> showExportActions(
    BuildContext context, Uint8List bytes, String filename) async {
  final l10n = context.l10n;
  final t = Theme.of(context).extension<AppThemeExtension>()!;
  final messenger = ScaffoldMessenger.of(context);

  final action = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.download_outlined, color: t.accentColor),
            title: Text(l10n.exportActionDownload),
            subtitle: Text(l10n.exportActionDownloadHint,
                style: TextStyle(fontSize: 12, color: t.textSecondary)),
            onTap: () => Navigator.pop(ctx, 'download'),
          ),
          ListTile(
            leading: Icon(Icons.share_outlined, color: t.accentColor),
            title: Text(l10n.exportActionShare),
            subtitle: Text(l10n.exportActionShareHint,
                style: TextStyle(fontSize: 12, color: t.textSecondary)),
            onTap: () => Navigator.pop(ctx, 'share'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  switch (action) {
    case 'download':
      final nameWithoutExt = filename.endsWith('.pdf')
          ? filename.substring(0, filename.length - 4)
          : filename;
      // Native "Save As" picker; null = user cancelled, not an error.
      final saved = await FileSaver.instance.saveAs(
        name: nameWithoutExt,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (saved != null) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.exportPdfSaved),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    case 'share':
      await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

/// Expense-report PDF export (Req G — Pocket Gold pattern).
///
/// One page of section toggles, then a bottom bar with 预览 and 导出. 预览
/// pushes [PdfPreviewScreen] (rasterized pages, pinch-zoomable); 导出 opens the
/// 下载/分享 sheet. The PDF is generated on demand — no live preview churning
/// on every toggle.
class ExpenseExportScreen extends ConsumerStatefulWidget {
  final Memory memory;

  const ExpenseExportScreen({super.key, required this.memory});

  @override
  ConsumerState<ExpenseExportScreen> createState() =>
      _ExpenseExportScreenState();
}

class _ExpenseExportScreenState extends ConsumerState<ExpenseExportScreen> {
  bool _expensesTable = true;
  bool _categoryChart = true;
  bool _personSpend = true;
  bool _statement = false;
  bool _consolidate = true;
  // Off by default: this PDF goes to the people you're settling with, and your
  // own 个人 purchases are neither theirs to reimburse nor theirs to read.
  bool _personal = false;

  bool _generatingPreview = false;
  bool _generatingExport = false;

  bool get _busy => _generatingPreview || _generatingExport;

  bool get _anySection =>
      _expensesTable ||
      _categoryChart ||
      _personSpend ||
      _statement ||
      _consolidate;

  AppThemeExtension get _t =>
      Theme.of(context).extension<AppThemeExtension>()!;

  String get _memoryId => widget.memory.id;

  String get _filename {
    final now = DateTime.now();
    return 'memora_expenses_'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.pdf';
  }

  /// Generates the PDF from the current toggles, or null on failure (the
  /// sources not having landed yet counts as one — buttons are disabled until
  /// they have, so that path is defensive).
  Future<Uint8List?> _generate({required bool forPreview}) async {
    final txns = ref.read(transactionsByMemoryProvider(_memoryId)).value;
    final splits = ref.read(memorySplitResultsProvider(_memoryId)).value;
    final resolved = ref.read(memoryResolvedExpensesProvider(_memoryId)).value;
    if (txns == null || splits == null || resolved == null) return null;

    final persons = ref.read(personsProvider).value ?? const [];
    final me = ref.read(mePersonProvider).value;
    final categories = ref.read(categoriesProvider(null)).value ?? const [];
    final personNames = <String, String>{
      for (final p in persons) p.id: p.name,
      if (me != null) me.id: me.name,
    };
    final categoryNames = {for (final c in categories) c.id: c.name};

    setState(() => forPreview
        ? _generatingPreview = true
        : _generatingExport = true);
    try {
      return await PdfService.generateExpenseReport(
        memory: widget.memory,
        transactions: txns,
        personNames: personNames,
        categoryNames: categoryNames,
        splits: splits,
        resolved: resolved,
        includeExpensesTable: _expensesTable,
        includeCategoryChart: _categoryChart,
        includePersonSpend: _personSpend,
        includeStatement: _statement,
        includeConsolidate: _consolidate,
        includePersonal: _personal,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportPdfFailed('$e'))),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => forPreview
            ? _generatingPreview = false
            : _generatingExport = false);
      }
    }
  }

  Future<void> _onPreview() async {
    final bytes = await _generate(forPreview: true);
    if (bytes == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfPreviewScreen(bytes: bytes, filename: _filename),
    ));
  }

  Future<void> _onExport() async {
    final bytes = await _generate(forPreview: false);
    if (bytes == null || !mounted) return;
    await showExportActions(context, bytes, _filename);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final l10n = context.l10n;
    // Watched (not just read at generate-time) so the buttons enable themselves
    // the moment the sources land.
    final sources = <AsyncValue<Object>>[
      ref.watch(transactionsByMemoryProvider(_memoryId)),
      ref.watch(memorySplitResultsProvider(_memoryId)),
      ref.watch(memoryResolvedExpensesProvider(_memoryId)),
    ];
    final loadError =
        sources.where((a) => a.hasError).map((a) => a.error).firstOrNull;
    final ready = sources.every((a) => a.hasValue);

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.exportPdfTitle,
            style: TextStyle(color: t.textPrimary, fontSize: 16)),
        iconTheme: IconThemeData(color: t.textSecondary),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    title: l10n.exportSectionBlocks,
                    child: _buildToggles(),
                  ),
                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l10n.exportLoadFailed('$loadError'),
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade400)),
                    ),
                ],
              ),
            ),
          ),
          _buildBottomBar(ready: ready && _anySection),
        ],
      ),
    );
  }

  Widget _buildToggles() {
    final t = _t;
    final l10n = context.l10n;
    Widget row(String label, String hint, bool value,
        ValueChanged<bool> onChanged) {
      return SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
        activeThumbColor: t.accentColor,
        title: Text(label,
            style: TextStyle(color: t.textPrimary, fontSize: 14)),
        subtitle: Text(hint,
            style: TextStyle(color: t.textSecondary, fontSize: 11)),
        value: value,
        onChanged: onChanged,
      );
    }

    return Column(
      children: [
        row(l10n.exportBlockExpenses, l10n.exportBlockExpensesHint,
            _expensesTable, (v) => setState(() => _expensesTable = v)),
        row(l10n.exportBlockCategory, l10n.exportBlockCategoryHint,
            _categoryChart, (v) => setState(() => _categoryChart = v)),
        row(l10n.exportBlockPersonSpend, l10n.exportBlockPersonSpendHint,
            _personSpend, (v) => setState(() => _personSpend = v)),
        row(l10n.exportBlockStatement, l10n.exportBlockStatementHint,
            _statement, (v) => setState(() => _statement = v)),
        row(l10n.exportBlockConsolidate, l10n.exportBlockConsolidateHint,
            _consolidate, (v) => setState(() => _consolidate = v)),
        Divider(height: 1, color: t.borderColor),
        row(l10n.exportIncludePersonal, l10n.exportIncludePersonalHint,
            _personal, (v) => setState(() => _personal = v)),
        if (!_anySection)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(l10n.exportPickAtLeastOne,
                style: TextStyle(fontSize: 12, color: t.textSecondary)),
          ),
      ],
    );
  }

  Widget _buildBottomBar({required bool ready}) {
    final t = _t;
    final l10n = context.l10n;
    final ctaText =
        ThemeData.estimateBrightnessForColor(t.accentColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    Widget spinner(Color color) => SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceColor,
        border: Border(top: BorderSide(color: t.borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: _generatingPreview
                  ? spinner(t.accentColor)
                  : const Icon(Icons.visibility_outlined, size: 18),
              label: Text(l10n.exportPreviewButton,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _busy || !ready ? null : _onPreview,
              style: OutlinedButton.styleFrom(
                foregroundColor: t.accentColor,
                side: BorderSide(color: t.accentColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: _generatingExport
                  ? spinner(ctaText)
                  : const Icon(Icons.ios_share, size: 18),
              label: Text(l10n.exportButton,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _busy || !ready ? null : _onExport,
              style: FilledButton.styleFrom(
                backgroundColor: t.accentColor,
                foregroundColor: ctaText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: t.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
            ),
            Divider(height: 1, color: t.borderColor),
            child,
          ],
        ),
      ),
    );
  }
}
