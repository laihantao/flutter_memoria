import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme_extension.dart';
import 'expense_export_screen.dart' show showExportActions;

/// Full-screen, pinch-zoomable preview of an already-generated PDF.
///
/// `printing`'s own [PdfPreview] widget can't zoom, which makes dense
/// statement tables unreadable on a phone. So this rasterizes each page to a
/// PNG once (150 dpi — sharp enough to zoom into, small enough for mobile
/// memory) and shows them in a [PhotoViewGallery]: swipe between pages, pinch
/// into a page. Same pattern as Pocket Gold's preview.
class PdfPreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  final String filename;

  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  /// null while rasterizing; empty when the document produced no pages.
  List<Uint8List>? _pages;
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _rasterize();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _rasterize() async {
    final pages = <Uint8List>[];
    await for (final raster in Printing.raster(widget.bytes, dpi: 150)) {
      pages.add(await raster.toPng());
    }
    if (mounted) setState(() => _pages = pages);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    final pages = _pages;
    final total = pages?.length ?? 0;

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text(
          pages != null && total > 0
              ? l10n.exportPageOf(_currentPage + 1, total)
              : l10n.exportPreviewButton,
          style: TextStyle(color: t.textPrimary, fontSize: 16),
        ),
        actions: [
          // The same 下载/分享 sheet as the settings page, so whichever place
          // the user decides from, the actions are the same.
          IconButton(
            icon: Icon(Icons.ios_share, color: t.textPrimary, size: 22),
            tooltip: l10n.exportButton,
            onPressed: () =>
                showExportActions(context, widget.bytes, widget.filename),
          ),
        ],
      ),
      body: switch (pages) {
        null => const Center(child: CircularProgressIndicator()),
        [] => Center(
            child: Text(l10n.exportPreviewEmpty,
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
          ),
        _ => PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: pages.length,
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: MemoryImage(pages[index]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4.0,
              filterQuality: FilterQuality.high,
              heroAttributes: PhotoViewHeroAttributes(tag: 'pdf_page_$index'),
            ),
            onPageChanged: (index) => setState(() => _currentPage = index),
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: BoxDecoration(color: t.backgroundColor),
          ),
      },
    );
  }
}
