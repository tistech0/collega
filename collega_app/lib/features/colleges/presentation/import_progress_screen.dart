import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

enum _StepStatus { done, active, pending }

class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({
    super.key,
    required this.collegeId,
    required this.refId,
  });

  final String collegeId;
  final int refId;

  @override
  ConsumerState<ImportProgressScreen> createState() => _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  late final AppLifecycleListener _lifecycleListener;
  DateTime? _streamStartTime;

  @override
  void initState() {
    super.initState();
    _streamStartTime = DateTime.now();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref
          .read(collegeImportProvider.notifier)
          .reconnectIfActive(widget.collegeId),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final importAsync = ref.watch(collegeImportProvider);

    ref.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (_, next) {
      final value = next.valueOrNull;
      if (value is ImportComplete) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Fiches générées avec succès !'),
          ),
        );
        context.go('/colleges');
      }
    });

    return importAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Erreur: $e')),
      ),
      data: (state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, CollegeImportState state) {
    final streaming = state is ImportStreaming ? state : null;
    final status = streaming?.status ?? 'pending';
    final ocrProgress = streaming?.ocrProgress ?? 0;
    final totalPages = streaming?.totalPages;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner prioritaire
            Container(
              color: AppColors.primaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.baseUnit * 1.5,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.baseUnit),
                  Expanded(
                    child: Text(
                      'Vous pouvez fermer l\'app — vous serez notifié dès que vos fiches seront prêtes',
                      style: AppTypography.bodyMedium()
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    Text(
                      'Import en cours',
                      style: AppTypography.titleLarge(),
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    _ProgressStepper(
                      status: status,
                      ocrProgress: ocrProgress,
                      totalPages: totalPages,
                      streamStartTime: _streamStartTime,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: ShadButton.outline(
                onPressed: () => context.pop(),
                child: const Text('Fermer et continuer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({
    required this.status,
    required this.ocrProgress,
    this.totalPages,
    this.streamStartTime,
  });

  final String status;
  final int ocrProgress;
  final int? totalPages;
  final DateTime? streamStartTime;

  _StepStatus _stepStatus(int stepIndex) {
    switch (status) {
      case 'pending':
        if (stepIndex == 0) return _StepStatus.done;
        if (stepIndex == 1) return _StepStatus.active;
        return _StepStatus.pending;
      case 'processing':
        if (stepIndex == 0) return _StepStatus.done;
        if (stepIndex == 1) return _StepStatus.active;
        return _StepStatus.pending;
      case 'ocr_complete':
        if (stepIndex <= 1) return _StepStatus.done;
        if (stepIndex == 2) return _StepStatus.active;
        return _StepStatus.pending;
      case 'generation_complete':
        return _StepStatus.done;
      default:
        return _StepStatus.pending;
    }
  }

  String? _activeSubtext(int stepIndex) {
    if (status == 'ocr_complete' && stepIndex == 2) return 'Génération en cours…';
    if (stepIndex != 1) return null;
    if (status != 'processing' && status != 'pending') return null;
    if (ocrProgress > 0 && totalPages != null && totalPages! > 0 && ocrProgress <= totalPages!) {
      final elapsed = streamStartTime != null
          ? DateTime.now().difference(streamStartTime!).inSeconds.clamp(1, 999999)
          : 1;
      final remaining = ((totalPages! - ocrProgress) / ocrProgress) * elapsed;
      final remainingMin = (remaining / 60).ceil();
      return remainingMin > 0
          ? 'Page $ocrProgress / $totalPages · ~$remainingMin min restantes'
          : 'Page $ocrProgress / $totalPages · < 1 min restante';
    }
    if (ocrProgress > 0) return 'Page $ocrProgress';
    return 'Analyse en cours…';
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      'PDF reçu',
      'OCR en cours',
      'Génération Claude',
      'Classement des fiches',
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final stepStatus = _stepStatus(i);
        final subtext = stepStatus == _StepStatus.active ? _activeSubtext(i) : null;
        return _StepTile(
          label: steps[i],
          status: stepStatus,
          subtext: subtext,
          isLast: i == steps.length - 1,
        );
      }),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.label,
    required this.status,
    required this.isLast,
    this.subtext,
  });

  final String label;
  final _StepStatus status;
  final bool isLast;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    final Color iconBg;
    final Widget icon;
    final Color borderColor;

    switch (status) {
      case _StepStatus.done:
        iconBg = AppColors.primaryContainer;
        borderColor = AppColors.primaryContainer;
        icon = const Icon(Icons.check, color: AppColors.primary, size: 20);
      case _StepStatus.active:
        iconBg = Colors.white;
        borderColor = AppColors.primary;
        icon = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        );
      case _StepStatus.pending:
        iconBg = Colors.white;
        borderColor = Colors.grey.shade300;
        icon = Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Center(child: icon),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: status == _StepStatus.done
                    ? AppColors.primaryContainer
                    : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.baseUnit * 1.5),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium().copyWith(
                    fontWeight: status == _StepStatus.active
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: status == _StepStatus.pending
                        ? Colors.grey.shade400
                        : AppColors.onSurface,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: AppTypography.labelMedium()
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
