import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/planning_providers.dart';

class PlanningConfigScreen extends ConsumerStatefulWidget {
  const PlanningConfigScreen({super.key});

  @override
  ConsumerState<PlanningConfigScreen> createState() =>
      _PlanningConfigScreenState();
}

class _PlanningConfigScreenState
    extends ConsumerState<PlanningConfigScreen> {
  static const _minutesOptions = [15, 30, 45, 60, 90, 120];

  late Set<String> _selectedCollegeIds;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _dailyMinutes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
    _dailyMinutes = 30;
    _selectedCollegeIds = {};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromExistingConfig();
    });
  }

  void _prefillFromExistingConfig() {
    final planningState =
        ref.read(planningProvider).valueOrNull;
    final config = planningState?.config;
    if (config == null) return;
    setState(() {
      _selectedCollegeIds = Set.from(config.collegeIds);
      _startDate = config.startDate.toLocal();
      _endDate = config.endDate.toLocal();
      _dailyMinutes = config.dailyMinutes;
    });
  }

  bool get _isFormValid =>
      _selectedCollegeIds.isNotEmpty &&
      _endDate.isAfter(_startDate);

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? DateTime.now() : _startDate.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_isFormValid) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(planningProvider.notifier).generatePlanning(
            collegeIds: _selectedCollegeIds.toList(),
            startDate: _startDate,
            endDate: _endDate,
            dailyMinutes: _dailyMinutes,
          );
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collegesAsync = ref.watch(collegesProvider);
    final generationComplete = collegesAsync.valueOrNull
            ?.where((e) => e.isGenerationComplete)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon planning'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CollegeMultiSelect(
                      colleges: generationComplete,
                      selected: _selectedCollegeIds,
                      onChanged: (ids) =>
                          setState(() => _selectedCollegeIds = ids),
                    ),
                    const SizedBox(height: 16),
                    _DateRangePicker(
                      startDate: _startDate,
                      endDate: _endDate,
                      onPickStart: () => _pickDate(isStart: true),
                      onPickEnd: () => _pickDate(isStart: false),
                    ),
                    const SizedBox(height: 16),
                    _DailyMinutesStepper(
                      value: _dailyMinutes,
                      options: _minutesOptions,
                      onChanged: (v) =>
                          setState(() => _dailyMinutes = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: _isLoading
                  ? const ShadProgress()
                  : ShadButton(
                      onPressed: _isFormValid ? _submit : null,
                      width: double.infinity,
                      child: const Text('Générer mon planning'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _CollegeMultiSelect ──────────────────────────────────────────────────────

class _CollegeMultiSelect extends StatelessWidget {
  const _CollegeMultiSelect({
    required this.colleges,
    required this.selected,
    required this.onChanged,
  });

  final List<CollegeListEntry> colleges;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (colleges.isEmpty) {
      return Text(
        'Aucun collège disponible. Importez un collège depuis l\'onglet Collèges.',
        style: AppTypography.bodyMedium()
            .copyWith(color: const Color(0xFF6B7C6E)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Collèges à réviser', style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        ...colleges.where((e) => e.userStatus != null).map((e) {
          final id = e.userStatus!.collegeId;
          return CheckboxListTile(
            value: selected.contains(id),
            title: Text(e.catalog.name, style: AppTypography.bodyMedium()),
            onChanged: (checked) {
              final next = Set<String>.from(selected);
              if (checked == true) {
                next.add(id);
              } else {
                next.remove(id);
              }
              onChanged(next);
            },
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }
}

// ─── _DateRangePicker ─────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

class _DateRangePicker extends StatelessWidget {
  const _DateRangePicker({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Période de révision', style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Début',
                value: _formatDate(startDate),
                onTap: onPickStart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: 'Fin',
                value: _formatDate(endDate),
                onTap: onPickEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.labelMedium()
                          .copyWith(color: const Color(0xFF6B7C6E), fontSize: 11)),
                  Text(value, style: AppTypography.bodyMedium()),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

// ─── _DailyMinutesStepper ────────────────────────────────────────────────────

class _DailyMinutesStepper extends StatelessWidget {
  const _DailyMinutesStepper({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Disponibilité quotidienne',
            style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((min) {
            final isSelected = min == value;
            return GestureDetector(
              onTap: () => onChanged(min),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$min min',
                  style: AppTypography.labelMedium().copyWith(
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
