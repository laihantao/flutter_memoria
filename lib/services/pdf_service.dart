import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_database.dart';
import '../services/expense_split_service.dart';
import '../utils/file_ops.dart';
import '../utils/money.dart';

/// One expense paired with who bears it. Structurally the same record as the
/// provider layer's `ResolvedExpense`, redeclared here so this service doesn't
/// depend on providers — Dart records match by shape, so it passes straight in.
typedef ExpenseShares = ({Transaction tx, Map<String, double> shares});

/// Donut palette — mirrors the in-app `_kChartColors` so the PDF and the 统计
/// tab colour the same categories the same way.
const _kPdfChartColors = [
  PdfColor.fromInt(0xFFF28B82), PdfColor.fromInt(0xFFFFAD8B),
  PdfColor.fromInt(0xFFF7C59F), PdfColor.fromInt(0xFFE8B4D0),
  PdfColor.fromInt(0xFF9AB5CF), PdfColor.fromInt(0xFFB5C4B1),
  PdfColor.fromInt(0xFFD4A5C9), PdfColor.fromInt(0xFFF0C23E),
];

/// The CJK font could not be loaded, so a statement would render with every
/// Chinese label blank. Thrown rather than silently emitting that document.
class CjkFontUnavailable implements Exception {
  const CjkFontUnavailable();

  @override
  String toString() => '无法加载中文字体，请连接网络后重试（首次导出需要下载字体，之后可离线使用）。';
}

class PdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Future<pw.ThemeData>? _cjkTheme;

  /// A theme with an embedded CJK font.
  ///
  /// The pdf package's built-in Helvetica carries no CJK glyphs, so every
  /// Chinese label — the section headers, 已结清, category and person names —
  /// silently renders blank without this.
  ///
  /// [PdfGoogleFonts] downloads the font once and caches it to disk, so the
  /// first export needs network and every later one does not.
  ///
  /// To make it fully offline instead (no code change): drop
  /// `NotoSansSC-Regular.ttf` and `NotoSansSC-Bold.ttf` into a `google_fonts/`
  /// directory at the project root and add `- google_fonts/` to the pubspec
  /// assets — the loader checks the asset bundle before the network. Verified
  /// working; it costs ~21 MB of app size, which is why it isn't the default.
  /// The exported PDF stays small either way (the font is subsetted to the
  /// glyphs actually used — a full statement measured ~25 KB).
  ///
  /// Held as a Future (not the resolved value) so concurrent exports share one
  /// load instead of racing.
  ///
  /// Known gap: Noto Sans SC has no emoji glyphs, so an emoji in a memory title
  /// or category name still renders blank.
  static Future<pw.ThemeData> _cjk() async {
    final pending = _cjkTheme ??= _buildCjkTheme();
    try {
      return await pending;
    } catch (_) {
      // Don't let one offline attempt poison the cache for the whole session.
      _cjkTheme = null;
      rethrow;
    }
  }

  static Future<pw.ThemeData> _buildCjkTheme() async {
    final base = await PdfGoogleFonts.notoSansSCRegular();
    final bold = await PdfGoogleFonts.notoSansSCBold();
    // printing swallows *any* load failure and hands back Helvetica, which has
    // no CJK glyphs — the document would come out with every Chinese label
    // blank and nothing to explain why (the package's own warning sits inside
    // an assert, so release builds are silent). A real load yields a TtfFont.
    if (base is! pw.TtfFont || bold is! pw.TtfFont) {
      throw const CjkFontUnavailable();
    }
    return pw.ThemeData.withFont(base: base, bold: bold);
  }

  /// Drops the cached font theme. For tests.
  @visibleForTesting
  static void resetFontCache() => _cjkTheme = null;

  /// Keepsake PDF: cover info + itinerary timeline + photo grid.
  /// Returns raw PDF bytes. Throws [UnsupportedError] on web.
  static Future<Uint8List> generateKeepsake({
    required Memory memory,
    required List<ItineraryItem> itinerary,
    required List<MediaAsset> mediaAssets,
    required List<String> participantNames,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('PDF export is not available on web.');
    }

    // Pre-load photo bytes asynchronously before building the PDF.
    final photoAssets =
        mediaAssets.where((a) => a.type == 'photo').take(12).toList();
    final photoBytes = <Uint8List>[];
    final docs = await getDocsPath();
    for (final photo in photoAssets) {
      final bytes = await readAbsoluteFileBytes(joinPath(docs, photo.filePath));
      if (bytes != null) photoBytes.add(bytes);
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: await _cjk(),
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                memory.title,
                style: pw.TextStyle(
                    fontSize: 28, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${_dateFmt.format(memory.startDate)}'
              '${memory.endDate != null ? ' – ${_dateFmt.format(memory.endDate!)}' : ''}',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            if (memory.locationName != null) ...[
              pw.SizedBox(height: 4),
              pw.Text('📍 ${memory.locationName}',
                  style: const pw.TextStyle(fontSize: 12)),
            ],
            if (participantNames.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('With: ${participantNames.join(', ')}',
                  style: const pw.TextStyle(fontSize: 12)),
            ],
            pw.Divider(),

            if (itinerary.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Itinerary'),
              ...itinerary.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _dateFmt.format(item.itemDate),
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.brown700),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.title,
                                  style: const pw.TextStyle(fontSize: 12)),
                              if (item.locationName != null)
                                pw.Text('  ${item.locationName}',
                                    style: const pw.TextStyle(
                                        fontSize: 10,
                                        color: PdfColors.grey600)),
                              if (item.notes != null)
                                pw.Text('  ${item.notes}',
                                    style: const pw.TextStyle(
                                        fontSize: 10,
                                        color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              pw.Divider(),
            ],

            _buildPhotoGrid(photoBytes),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Expense report PDF. Emits only the sections whose flag is on, each grouped
  /// **per currency** (Req F). Section order: 支出明细 → 分类占比 → 各人消费 →
  /// 付款表 → 最终结算 — record, then analysis, then settlement.
  ///
  /// [transactions] are the memory's expenses via the `memoryId` FK path (only
  /// `type == 'expense'` rows are shown). [splits] is the pre-computed
  /// settlement from [ExpenseSplitService]; [resolved] is every expense paired
  /// with who bears it, which is what lets 各人消费 spell out its arithmetic
  /// instead of asking the reader to trust a total. All money is rounded
  /// half-up via the shared [money] helpers.
  ///
  /// [includePersonal] governs 个人 rows only. This document is what you hand a
  /// travel companion to settle up, and your own 个人 purchases are neither
  /// theirs to reimburse nor theirs to read — hence off by default. They never
  /// affect settlement either way (a 个人 expense is borne by its own payer), so
  /// dropping them changes the 明细 and 各人消费 detail but not who owes whom.
  ///
  /// Deliberately absent: a per-person 差额 (paid − borne) column. It reads as
  /// "you're square, nothing to do" when it is zero, which is false — netting is
  /// pairwise, so a person can be square overall and still owe one companion
  /// while another owes them (see [PersonCostTotals.net]). 最终结算 is the only
  /// honest answer to "what do I actually transfer", so that is the only place
  /// this document answers it.
  ///
  /// Reads no files, so it is safe on web (unlike [generateKeepsake]).
  static Future<Uint8List> generateExpenseReport({
    required Memory memory,
    required List<Transaction> transactions,
    required Map<String, String> personNames,
    required Map<String, String> categoryNames,
    required List<CurrencySplit> splits,
    /// Every expense with its bearers — powers 各人消费 and the "AA ÷N" label.
    List<ExpenseShares> resolved = const [],
    bool includeExpensesTable = true,
    bool includeCategoryChart = true,
    bool includePersonSpend = true,
    bool includeStatement = false,
    bool includeConsolidate = true,
    bool includePersonal = false,
  }) async {
    bool keep(String splitType) =>
        includePersonal || splitType != 'personal';

    final expenseTxns = transactions
        .where((t) => t.type == 'expense' && keep(t.splitType))
        .toList();
    final shares =
        resolved.where((r) => keep(r.tx.splitType)).toList();
    // txId → head count, so the 明细 can print "AA ÷N" and make an exclusion
    // visible in the row itself instead of only in the settlement.
    final sharerCounts = {
      for (final r in shares)
        if (r.tx.splitType == 'split_aa') r.tx.id: r.shares.length,
    };
    final splitByCurrency = {for (final s in splits) s.currencyCode: s};

    // Every currency that appears in either the expenses or the settlement.
    final currencies = <String>{
      ...expenseTxns.map((t) => normalizeCurrency(t.currencyCode)),
      ...splits.map((s) => s.currencyCode),
    }.toList()
      ..sort();

    String nameOf(String? id) =>
        id == null ? '' : (personNames[id] ?? id);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: await _cjk(),
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          final out = <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Text('${memory.title} — 支出报告',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${_dateFmt.format(memory.startDate)}'
              '${memory.endDate != null ? ' – ${_dateFmt.format(memory.endDate!)}' : ''}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Divider(),
          ];

          // ── 1. Expenses table (Req G #1, default ON) ──────────────────────
          if (includeExpensesTable) {
            out.add(pw.Header(level: 1, text: '支出明细 · Expenses'));
            var any = false;
            for (final c in currencies) {
              final rows = expenseTxns
                  .where((t) => normalizeCurrency(t.currencyCode) == c)
                  .toList();
              if (rows.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.add(_expensesTable(
                  rows, categoryNames, personNames, sharerCounts, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无支出'));
            if (!includePersonal) {
              out.add(_emptyNote('* 个人消费未列入本报告'));
            }
          }

          // ── 2. 分类占比 — where the money went ────────────────────────────
          if (includeCategoryChart) {
            out.add(pw.Header(level: 1, text: '分类占比 · By Category'));
            var any = false;
            for (final c in currencies) {
              final rows = expenseTxns
                  .where((t) => normalizeCurrency(t.currencyCode) == c)
                  .toList();
              if (rows.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.add(_categorySection(rows, categoryNames, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无支出'));
          }

          // ── 3. 各人消费 — what the trip cost each person, spelled out ─────
          if (includePersonSpend) {
            out.add(pw.Header(level: 1, text: '各人消费 · Per-person Spend'));
            out.add(_legend(
                '每人这趟实际花掉的钱：个人消费全额 + 每笔 AA 的人头份 + 自己请客的全额'
                '（别人请客不计）。「÷N」是该笔分摊的人数。这里不代表谁欠谁 —— 见最终结算。'));
            var any = false;
            for (final c in currencies) {
              final rows = shares
                  .where((r) => normalizeCurrency(r.tx.currencyCode) == c)
                  .toList();
              if (rows.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.add(_personSpendTable(
                  rows, _rosterOrder(splitByCurrency[c], rows), nameOf,
                  categoryNames, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无支出'));
          }

          // ── 4. Payment Statement (Req G #2, default OFF) ──────────────────
          if (includeStatement) {
            out.add(pw.Header(level: 1, text: '付款表 · Payment Statement'));
            out.add(_legend(
                '抵消前的明细：每行一位欠款人，单元格 = 该行欠该列（收款人）的金额。'
                '被排除在某笔分摊外的人，那笔不产生欠款。'));
            var any = false;
            for (final c in currencies) {
              final s = splitByCurrency[c];
              if (s == null || s.statement.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.add(_statementTable(s.statement, nameOf, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无可分摊的 AA 支出'));
          }

          // ── 5. Final Consolidate (Req G #3, default ON) ───────────────────
          // Grouped by person so each reader finds their own name and reads off
          // exactly what to do, rather than scanning a flat list of arrows.
          if (includeConsolidate) {
            out.add(pw.Header(level: 1, text: '最终结算 · Final Consolidate'));
            out.add(_legend(
                '两两互欠抵消后实际要转的账。找自己的名字，照着转即两清。'
                '每笔转账会同时出现在付款人和收款人名下（一次转账，两边各记一次）。'));
            var any = false;
            for (final c in currencies) {
              final s = splitByCurrency[c];
              if (s == null || s.consolidated.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.addAll(_consolidateByPerson(s, nameOf, c));
              out.add(pw.SizedBox(height: 8));
            }
            if (!any) {
              out.add(pw.Text('全部结清 · All settled up!',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.green700)));
            }
          }

          return out;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _currencySubheader(String currency) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(currency,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.brown700)),
      );

  /// One-line how-to-read note under a section header. The statement goes to
  /// travel companions who never saw the app — the tables must explain
  /// themselves.
  static pw.Widget _legend(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      );

  static pw.Widget _emptyNote(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
      );

  /// People in trip-roster order (the statement's row order), falling back to
  /// first appearance in the data when there's no statement for this currency.
  static List<String> _rosterOrder(
      CurrencySplit? split, List<ExpenseShares> rows) {
    final seen = <String>[
      for (final r in rows)
        for (final id in r.shares.keys) id,
    ];
    final order = <String>[
      ...?split?.statement.rowPersonIds,
      for (final id in seen) id,
    ];
    return <String>{...order}.where((id) => seen.contains(id)).toList();
  }

  /// Donut + a 类别/金额/占比 table. Answers "where did the money go" at a
  /// glance, which the flat 明细 can't.
  static pw.Widget _categorySection(
    List<Transaction> rows,
    Map<String, String> categoryNames,
    String currency,
  ) {
    final byCategory = <String, double>{};
    for (final t in rows) {
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return _emptyNote('该币种暂无支出');

    String pct(double v) => '${(v / total * 100).toStringAsFixed(1)}%';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 170,
          height: 170,
          child: pw.Chart(
            grid: pw.PieGrid(),
            datasets: [
              for (var i = 0; i < sorted.length; i++)
                pw.PieDataSet(
                  value: sorted[i].value,
                  color: _kPdfChartColors[i % _kPdfChartColors.length],
                  legend: pct(sorted[i].value),
                  legendStyle: const pw.TextStyle(fontSize: 8),
                  innerRadius: 28,
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.TableHelper.fromTextArray(
            headers: ['类别', '金额', '占比'],
            data: [
              for (var i = 0; i < sorted.length; i++)
                [
                  categoryNames[sorted[i].key] ?? sorted[i].key,
                  formatMoneyWithSymbol(sorted[i].value, currency),
                  pct(sorted[i].value),
                ],
              ['合计', formatMoneyWithSymbol(total, currency), '100%'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.brown100),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        ),
      ],
    );
  }

  /// 各人消费: each person's 承担 with its arithmetic written out —
  /// `RM 200 ÷ 5 (炸鸡) + RM 50 ÷ 5 (MCD)` — then the total. Showing only the
  /// total asks the reader to trust it; showing the terms lets them check it.
  static pw.Widget _personSpendTable(
    List<ExpenseShares> rows,
    List<String> people,
    String Function(String?) nameOf,
    Map<String, String> categoryNames,
    String currency,
  ) {
    /// What to call an expense: its own note if it has one, else its category.
    String label(Transaction t) {
      final note = (t.note ?? '').trim();
      return note.isNotEmpty
          ? note
          : (categoryNames[t.categoryId] ?? t.categoryId);
    }

    final data = <List<String>>[];
    for (final pid in people) {
      final terms = <String>[];
      var total = 0.0;
      for (final r in rows) {
        final share = r.shares[pid];
        if (share == null) continue;
        total += share;
        final n = r.shares.length;
        final amount = formatMoneyWithSymbol(r.tx.amount, currency);
        terms.add(n > 1
            ? '$amount ÷ $n (${label(r.tx)})'
            : '$amount (${label(r.tx)}'
                '${r.tx.splitType == 'treat' ? '・请客' : ''})');
      }
      if (terms.isEmpty) continue;
      data.add([
        nameOf(pid),
        terms.join('  +  '),
        formatMoneyWithSymbol(roundHalfUp(total), currency),
      ]);
    }
    if (data.isEmpty) return _emptyNote('暂无支出');

    return pw.TableHelper.fromTextArray(
      headers: ['参与者', '承担明细', '合计'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.brown100),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FlexColumnWidth(1.3),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
    );
  }

  /// 最终结算 grouped by person: one block per participant listing what they
  /// pay and what they collect.
  static List<pw.Widget> _consolidateByPerson(
    CurrencySplit split,
    String Function(String?) nameOf,
    String currency,
  ) {
    final out = <pw.Widget>[];
    for (final pid in split.statement.rowPersonIds) {
      final pays = split.consolidated.where((d) => d.fromPersonId == pid);
      final collects = split.consolidated.where((d) => d.toPersonId == pid);
      if (pays.isEmpty && collects.isEmpty) continue;

      out.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
        child: pw.Text(nameOf(pid),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ));
      for (final d in pays) {
        out.add(_settleLine(
            '应付', nameOf(d.toPersonId), d.amount, currency, PdfColors.red700));
      }
      for (final d in collects) {
        out.add(_settleLine('应收', nameOf(d.fromPersonId), d.amount, currency,
            PdfColors.green700));
      }
    }
    return out;
  }

  static pw.Widget _settleLine(String verb, String other, double amount,
          String currency, PdfColor color) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 14, bottom: 3),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 30,
            child: pw.Text(verb,
                style: pw.TextStyle(fontSize: 10, color: color)),
          ),
          pw.Expanded(
              child: pw.Text(other, style: const pw.TextStyle(fontSize: 10))),
          pw.Text(formatMoneyWithSymbol(amount, currency),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  static pw.Widget _expensesTable(
    List<Transaction> rows,
    Map<String, String> categoryNames,
    Map<String, String> personNames,
    Map<String, int> sharerCounts,
    String currency,
  ) {
    /// Who ends up carrying the row — the answer 方式 alone doesn't give. AA
    /// shows the head count so an exclusion is visible ("AA ÷2" on a
    /// three-person trip says someone sat this one out).
    String bearer(Transaction t) {
      switch (t.splitType) {
        case 'split_aa':
          final n = sharerCounts[t.id];
          return n == null ? 'AA 分摊' : 'AA ÷$n';
        case 'treat':
          return '${personNames[t.payerPersonId] ?? ''} 请客';
        default:
          return '本人';
      }
    }

    final total = rows.fold<double>(0, (sum, t) => sum + t.amount);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          // 项目 is the expense's own note — the category alone doesn't say what
          // was actually bought.
          headers: ['日期', '项目', '类别', '金额', '付款人', '承担'],
          data: rows
              .map((t) => [
                    _dateFmt.format(t.txnDate),
                    (t.note ?? '').trim(),
                    categoryNames[t.categoryId] ?? '',
                    formatMoneyWithSymbol(t.amount, currency),
                    personNames[t.payerPersonId] ?? '',
                    bearer(t),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.brown100),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.6),
            1: const pw.FlexColumnWidth(2.4),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.3),
            5: const pw.FlexColumnWidth(1.6),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text('小计 ${formatMoneyWithSymbol(total, currency)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.Widget _statementTable(
    PaymentStatement statement,
    String Function(String) nameOf,
    String currency,
  ) {
    // Header: [欠款人, ...payees, 合计]; each cell is what the row owes a payee.
    final headers = <String>[
      '欠款人 \\ 收款人',
      ...statement.payeePersonIds.map(nameOf),
      '合计',
    ];
    final data = <List<String>>[];
    for (final row in statement.rowPersonIds) {
      final rowTotal = statement.rowTotal(row);
      if (rowTotal == 0) continue; // skip participants who owe nothing
      data.add([
        nameOf(row),
        for (final payee in statement.payeePersonIds)
          () {
            final v = statement.owed(row, payee);
            return v == 0 ? '' : formatMoneyWithSymbol(v, currency);
          }(),
        formatMoneyWithSymbol(rowTotal, currency),
      ]);
    }
    if (data.isEmpty) return _emptyNote('无人需付款');
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle:
          pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.brown100),
      cellStyle: const pw.TextStyle(fontSize: 10),
      // Name column left, every money column right so the digits line up.
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildPhotoGrid(List<Uint8List> photoBytes) {
    if (photoBytes.isEmpty) return pw.SizedBox();

    final images = photoBytes.map((bytes) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Image(pw.MemoryImage(bytes),
              height: 150, fit: pw.BoxFit.cover),
        ));

    return pw.Column(children: [
      pw.Header(level: 1, text: 'Photo Highlights'),
      pw.Wrap(children: images.toList()),
    ]);
  }
}
