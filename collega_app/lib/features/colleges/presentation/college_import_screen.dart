import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class CollegeImportScreen extends ConsumerStatefulWidget {
  const CollegeImportScreen({super.key, required this.refId});

  final int refId;

  @override
  ConsumerState<CollegeImportScreen> createState() => _CollegeImportScreenState();
}

class _CollegeImportScreenState extends ConsumerState<CollegeImportScreen> {
  CollegeCatalogEntry get _catalogEntry => kCollegeCatalog.firstWhere(
        (e) => e.refId == widget.refId,
        orElse: () => kCollegeCatalog.first,
      );

  @override
  void initState() {
    super.initState();
    // Réinitialiser l'état à chaque ouverture de l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collegeImportProvider.notifier).reset();
    });
  }

  static const int _maxPdfSizeBytes = 500 * 1024 * 1024; // 500 MB

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final sizeBytes = await file.length();
    if (sizeBytes > _maxPdfSizeBytes) {
      if (!mounted) return;
      final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('PDF trop volumineux'),
          description: Text('Le fichier fait ${sizeMb} MB. Maximum : 500 MB.'),
        ),
      );
      return;
    }

    await ref.read(collegeImportProvider.notifier).startImport(widget.refId, file);
  }

  @override
  Widget build(BuildContext context) {
    final importAsync = ref.watch(collegeImportProvider);

    ref.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (_, next) {
      final value = next.valueOrNull;
      if (value is ImportStreaming) {
        context.push(
          '/colleges/${widget.refId}/import/progress',
          extra: {'collegeId': value.collegeId, 'refId': widget.refId},
        );
      } else if (value is ImportError) {
        _handleError(context, value.message);
      }
    });

    final isUploading = importAsync.valueOrNull is ImportUploading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _catalogEntry.name,
          style: AppTypography.titleMedium(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sectionSpacing),
            Icon(_catalogEntry.icon, size: 64, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sectionSpacing),
            Text(
              _catalogEntry.name,
              style: AppTypography.titleLarge(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.baseUnit),
            Text(
              _catalogEntry.editor,
              style: AppTypography.bodyMedium()
                  .copyWith(color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (isUploading)
              Column(
                children: [
                  const SizedBox(
                    height: 48,
                    child: Center(child: LinearProgressIndicator(color: AppColors.primary)),
                  ),
                  const SizedBox(height: AppSpacing.baseUnit),
                  Text('Upload en cours…', style: AppTypography.bodyMedium()),
                ],
              )
            else
              ShadButton(
                onPressed: _pickAndImport,
                child: const Text('Choisir un PDF'),
              ),
            const SizedBox(height: AppSpacing.sectionSpacing),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _handleError(BuildContext context, String message) {
    switch (message) {
      case 'subscription_required':
        context.push('/paywall');
      case 'job_in_progress':
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Import déjà en cours pour ce collège'),
          ),
        );
      case 'college_reload_limit':
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('Ce collège ne peut plus être retraité'),
          ),
        );
      case String s when s.startsWith('monthly_reload_limit:'):
        final resetAt = s.substring('monthly_reload_limit:'.length);
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Limite mensuelle atteinte'),
            description: Text('Réinitialisation le ${_formatDate(resetAt)}'),
          ),
        );
      default:
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur lors de l\'import'),
            description: Text(message),
          ),
        );
    }
  }
}
