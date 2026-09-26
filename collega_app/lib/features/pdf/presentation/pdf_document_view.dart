import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

/// Rendu du PDF ; remplacé en test (pdfium ne tourne pas sous `flutter test`).
typedef PdfDocumentBuilder = Widget Function({
  required String path,
  required int initialPage,
  required void Function(int page, int pageCount) onPage,
  required void Function(Future<void> Function(int page) goTo) onReady,
});

final pdfDocumentBuilderProvider = Provider<PdfDocumentBuilder>((_) => pdfrxDocumentBuilder);

Widget pdfrxDocumentBuilder({
  required String path,
  required int initialPage,
  required void Function(int page, int pageCount) onPage,
  required void Function(Future<void> Function(int page) goTo) onReady,
}) =>
    _PdfrxView(path: path, initialPage: initialPage, onPage: onPage, onReady: onReady);

class _PdfrxView extends StatefulWidget {
  const _PdfrxView({required this.path, required this.initialPage, required this.onPage, required this.onReady});

  final String path;
  final int initialPage;
  final void Function(int page, int pageCount) onPage;
  final void Function(Future<void> Function(int page) goTo) onReady;

  @override
  State<_PdfrxView> createState() => _PdfrxViewState();
}

class _PdfrxViewState extends State<_PdfrxView> {
  final _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) => PdfViewer.file(
        widget.path,
        controller: _controller,
        initialPageNumber: widget.initialPage,
        params: PdfViewerParams(
          onViewerReady: (document, controller) {
            widget.onReady((page) => controller.goToPage(pageNumber: page));
            widget.onPage(controller.pageNumber ?? widget.initialPage, controller.pageCount);
          },
          onPageChanged: (page) {
            if (page != null) widget.onPage(page, _controller.pageCount);
          },
        ),
      );
}
