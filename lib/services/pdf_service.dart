import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_database.dart';
import '../services/expense_split_service.dart';
import '../utils/file_ops.dart';
import '../utils/money.dart';

class PdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

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
  /// Payment Statement → Final Consolidate.
  ///
  /// [transactions] are the memory's expenses via the `memoryId` FK path (only
  /// `type == 'expense'` rows are shown). [splits] is the pre-computed
  /// per-currency settlement from [ExpenseSplitService]. All money is rounded
  /// half-up via the shared [money] helpers.
  ///
  /// Reads no files, so it is safe on web (unlike [generateKeepsake]).
  static Future<Uint8List> generateExpenseReport({
    required Memory memory,
    required List<Transaction> transactions,
    required Map<String, String> personNames,
    required Map<String, String> categoryNames,
    required List<CurrencySplit> splits,
    bool includeExpensesTable = true,
    bool includeStatement = false,
    bool includeConsolidate = true,
  }) async {
    final expenseTxns =
        transactions.where((t) => t.type == 'expense').toList();
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
          }

          // ── 2. Payment Statement (Req G #2, default OFF) ──────────────────
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

          // ── 3. Final Consolidate (Req G #3, default ON) ───────────────────
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

  static pw.Widget _expensesTable(
    List<Transaction> rows,
    Map<String, String> categoryNames,
    Map<String, String> personNames,
    String currency,
  ) {
    const modeLabel = {
      'personal': '个人',
      'split_aa': 'AA',
      'treat': '请客',
    };
    final total = rows.fold<double>(0, (sum, t) => sum + t.amount);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headers: ['日期', '类别', '金额', '付款人', '方式'],
          data: rows
              .map((t) => [
                    _dateFmt.format(t.txnDate),
                    categoryNames[t.categoryId] ?? '',
                    formatMoneyWithSymbol(t.amount, currency),
                    personNames[t.payerPersonId] ?? '',
                    modeLabel[t.splitType] ?? t.splitType,
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
