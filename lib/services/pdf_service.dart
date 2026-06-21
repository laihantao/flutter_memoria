import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_database.dart';
import '../services/settle_up_service.dart';
import '../utils/file_ops.dart';

class PdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _moneyFmt = NumberFormat('#,##0.00');

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

  /// Settlement PDF: expense table + settle-up summary.
  /// Returns raw PDF bytes. Throws [UnsupportedError] on web.
  static Future<Uint8List> generateSettlement({
    required Memory memory,
    required List<Transaction> transactions,
    required Map<String, String> personNames,
    required Map<String, String> categoryNames,
    required List<SettlementEntry> settlements,
    String baseCurrency = 'MYR',
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('PDF export is not available on web.');
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
              child: pw.Text('${memory.title} — Expense Settlement',
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

            pw.Header(level: 1, text: 'Expenses'),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Amount', 'Payer', 'Split'],
              data: transactions
                  .where((t) => t.splitType != 'personal')
                  .map((t) => [
                        _dateFmt.format(t.txnDate),
                        categoryNames[t.categoryId] ?? '',
                        '${t.currencyCode} ${_moneyFmt.format(t.amount)}',
                        personNames[t.payerPersonId] ?? '',
                        t.splitType == 'treat' ? 'Treat' : 'Split AA',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.brown100),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 16),

            if (settlements.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Who Owes Whom'),
              ...settlements.map((s) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      '${personNames[s.fromPersonId] ?? s.fromPersonId}'
                      ' owes '
                      '${personNames[s.toPersonId] ?? s.toPersonId}'
                      '  ${s.currencyCode} ${_moneyFmt.format(s.amount)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  )),
            ] else
              pw.Text('All settled up!',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.green700)),
          ];
        },
      ),
    );

    return pdf.save();
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
