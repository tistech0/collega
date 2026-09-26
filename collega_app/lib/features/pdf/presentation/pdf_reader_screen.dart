import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/domain/pdf_labels.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';
import 'package:collega_app/features/pdf/presentation/pdf_document_view.dart';
import 'package:collega_app/features/pdf/presentation/pdf_missing_view.dart';

/// Lecteur plein écran (partie B, option A) : tout le PDF, ouvert à [page]
/// (base 1) ; depuis un item, bandeau « Item N · p. X–Y » et « ↑ Début ».
/// Sans [page] : dernière page lue du collège, sinon p. 1.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.refId, this.page, this.itemId});

  final int refId;
  final int? page;
  final String? itemId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  int? _page;
  int? _pageCount;
  Future<void> Function(int page)? _goTo;

  /// Page d'ouverture et copie à lire, calculées une fois par écran.
  Future<(int, File?)>? _open;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final name = collegeCatalogEntry(widget.refId)?.name ?? 'Collège';
    final status =
        ref.watch(collegesProvider).valueOrNull?.where((e) => e.catalog.refId == widget.refId).firstOrNull?.userStatus;
    final item = widget.itemId == null ? null : ref.watch(itemInfoProvider(widget.itemId!)).valueOrNull;
    final backLabel = item == null ? name : 'Item ${item.itemNumber}';

    Widget body;
    if (status == null) {
      body = const Center(child: CgSkeletonList(rows: 3));
    } else {
      final key = (collegeId: status.collegeId, version: status.pdfVersion);
      final download = ref.watch(pdfDownloadProvider(status.collegeId));
      ref.listen(pdfDownloadProvider(status.collegeId), (_, next) {
        if (next is PdfDownloadDone) {
          _open = null;
          ref.invalidate(collegePdfStatusProvider(key));
        }
      });
      final local = ref.watch(collegePdfStatusProvider(key)).valueOrNull;
      body = switch (local) {
        null => const Center(child: CgSkeletonList(rows: 3)),
        LocalPdfStatus.upToDate => _document(status.collegeId, status.pdfVersion),
        _ => PdfMissingView(
            collegeName: name,
            sizeBytes: status.pdfSize,
            outdated: local == LocalPdfStatus.outdated,
            available: status.pdfVersion != null,
            download: download,
            onDownload: () {
              final version = status.pdfVersion;
              if (version != null) ref.read(pdfDownloadProvider(status.collegeId).notifier).start(version);
            },
          ),
      };
    }

    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _TopBar(
            backLabel: backLabel,
            pageLabel: _page == null || _pageCount == null ? null : 'p. $_page / $_pageCount',
            onBack: () => context.pop(),
          ),
          Expanded(child: body),
          if (item?.startPage != null && _goTo != null)
            _ItemBand(
              label: 'Item ${item!.itemNumber} · ${pageRangeLabel(item.startPage!, item.endPage)}',
              onTop: () => _goTo!(item.startPage! + 1),
            ),
        ]),
      ),
    );
  }

  Future<(int, File?)> _openFor(String collegeId, String? version) => _open ??= () async {
        final store = await ref.read(localPdfStoreProvider.future);
        final first = widget.page ?? await store.lastPage(collegeId) ?? 1;
        return (first, await store.readable(collegeId, version));
      }();

  Widget _document(String collegeId, String? version) => FutureBuilder<(int, File?)>(
        future: _openFor(collegeId, version),
        builder: (context, snap) {
          final (first, file) = snap.data ?? (1, null);
          if (file == null) return const Center(child: CgSkeletonList(rows: 3));
          return ref.read(pdfDocumentBuilderProvider)(
            path: file.path,
            initialPage: first,
            onPage: (page, count) {
              if (!mounted) return;
              setState(() {
                _page = page;
                _pageCount = count;
              });
              if (widget.itemId == null) {
                ref.read(localPdfStoreProvider.future).then((s) => s.saveLastPage(collegeId, page));
              }
            },
            onReady: (goTo) {
              if (mounted) setState(() => _goTo = goTo);
            },
          );
        },
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.backLabel, required this.pageLabel, required this.onBack});

  final String backLabel;
  final String? pageLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s2),
      child: Row(children: [
        Semantics(
          button: true,
          label: 'Retour, $backLabel',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
              child: Row(children: [
                CgIcon(CgIcons.chevronLeft, color: c.accent),
                Text(backLabel, style: CgType.body.copyWith(color: c.accent)),
              ]),
            ),
          ),
        ),
        const Spacer(),
        if (pageLabel != null)
          Text(pageLabel!, style: CgType.bodyS.copyWith(color: c.ink, fontWeight: FontWeight.w600)),
        const SizedBox(width: CgSpace.s2),
      ]),
    );
  }
}

class _ItemBand extends StatelessWidget {
  const _ItemBand({required this.label, required this.onTop});

  final String label;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Container(
      margin: const EdgeInsets.all(CgSpace.s2),
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: CgRadius.sAll),
      child: Row(children: [
        Expanded(child: Text(label, style: CgType.bodyS.copyWith(color: c.accent, fontWeight: FontWeight.w600))),
        Semantics(
          button: true,
          label: 'Revenir au début de l’item',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTop,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget, minWidth: CgSpace.tapTarget),
              child: Center(
                  child: Text('↑ Début', style: CgType.bodyS.copyWith(color: c.accent, fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      ]),
    );
  }
}
