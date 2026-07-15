import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_database.dart';
import '../services/expense_split_service.dart';
import '../utils/file_ops.dart';
import '../utils/money.dart';

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

  /// Expense report PDF (Req G). Emits only the sections whose flag is on,
  /// each grouped **per currency** (Req F). Section order: Expenses table →
  /// 各人收支 → Payment Statement → Final Consolidate.
  ///
  /// [transactions] are the memory's expenses via the `memoryId` FK path (only
  /// `type == 'expense'` rows are shown). [splits] and [personCosts] are
  /// pre-computed by [ExpenseSplitService]. All money is rounded half-up via the
  /// shared [money] helpers.
  ///
  /// [includePersonal] governs 个人 rows only. This document is what you hand a
  /// travel companion to settle up, and your own 个人 purchases are neither
  /// theirs to reimburse nor theirs to read — hence off by default. They never
  /// affect settlement either way (a 个人 expense is borne by its own payer), so
  /// dropping them changes the 明细 and 各人收支 detail but not who owes whom.
  ///
  /// Reads no files, so it is safe on web (unlike [generateKeepsake]).
  static Future<Uint8List> generateExpenseReport({
    required Memory memory,
    required List<Transaction> transactions,
    required Map<String, String> personNames,
    required Map<String, String> categoryNames,
    required List<CurrencySplit> splits,
    List<PersonCostTotals> personCosts = const [],
    bool includeExpensesTable = true,
    bool includePersonCosts = true,
    bool includeStatement = false,
    bool includeConsolidate = true,
    bool includePersonal = false,
  }) async {
    final expenseTxns = transactions
        .where((t) =>
            t.type == 'expense' &&
            (includePersonal || t.splitType != 'personal'))
        .toList();
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
              out.add(_expensesTable(rows, categoryNames, personNames, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无支出'));
            if (!includePersonal) {
              out.add(_emptyNote('* 个人消费未列入本报告'));
            }
          }

          // ── 2. 各人收支 — the bridge between the table and the settlement ──
          // Makes 个人/请客 visible: they move 付款 and 承担 together, so they
          // show up here without ever moving 差额.
          if (includePersonCosts) {
            out.add(pw.Header(level: 1, text: '各人收支 · Paid vs Borne'));
            var any = false;
            for (final c in currencies) {
              final rows =
                  personCosts.where((r) => r.currencyCode == c).toList();
              if (rows.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              out.add(_personCostsTable(rows, nameOf, c));
              out.add(pw.SizedBox(height: 12));
            }
            if (!any) out.add(_emptyNote('暂无支出'));
          }

          // ── 3. Payment Statement (Req G #2, default OFF) ──────────────────
          if (includeStatement) {
            out.add(pw.Header(level: 1, text: '付款表 · Payment Statement'));
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

          // ── 4. Final Consolidate (Req G #3, default ON) ───────────────────
          if (includeConsolidate) {
            out.add(pw.Header(level: 1, text: '最终结算 · Final Consolidate'));
            var any = false;
            for (final c in currencies) {
              final s = splitByCurrency[c];
              if (s == null || s.consolidated.isEmpty) continue;
              any = true;
              out.add(_currencySubheader(c));
              for (final d in s.consolidated) {
                out.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    '${nameOf(d.fromPersonId)}  →  ${nameOf(d.toPersonId)}'
                    '     ${formatMoneyWithSymbol(d.amount, c)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ));
              }
              out.add(pw.SizedBox(height: 12));
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

  static pw.Widget _emptyNote(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
      );

  /// 各人收支: 付款 / 承担 / 差额 per person. 差额 = 付款 − 承担 is the person's
  /// net settlement position, so this table reconciles against Final
  /// Consolidate — a reader can check one against the other.
  static pw.Widget _personCostsTable(
    List<PersonCostTotals> rows,
    String Function(String?) nameOf,
    String currency,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['参与者', '付款', '承担', '差额'],
      data: rows.map((r) {
        final net = r.net;
        return [
          nameOf(r.personId),
          formatMoneyWithSymbol(r.paid, currency),
          formatMoneyWithSymbol(r.borne, currency),
          net == 0
              ? '已结清'
              : '${net > 0 ? '应收' : '应付'} '
                  '${formatMoneyWithSymbol(net.abs(), currency)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.brown100),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _expensesTable(
    List<Transaction> rows,
    Map<String, String> categoryNames,
    Map<String, String> personNames,
    String currency,
  ) {
    /// Who ends up carrying the row — the answer 方式 alone doesn't give.
    String bearer(Transaction t) => switch (t.splitType) {
          'split_aa' => 'AA 分摊',
          'treat' => '${personNames[t.payerPersonId] ?? ''} 请客',
          _ => '本人',
        };

    final total = rows.fold<double>(0, (sum, t) => sum + t.amount);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headers: ['日期', '类别', '金额', '付款人', '承担'],
          data: rows
              .map((t) => [
                    _dateFmt.format(t.txnDate),
                    categoryNames[t.categoryId] ?? '',
                    formatMoneyWithSymbol(t.amount, currency),
                    personNames[t.payerPersonId] ?? '',
                    bearer(t),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.brown100),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
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
      cellAlignments: {0: pw.Alignment.centerLeft},
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
