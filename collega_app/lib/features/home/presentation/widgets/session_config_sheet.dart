import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';
import 'package:collega_app/features/home/home_providers.dart';

class SessionConfigSheet extends ConsumerStatefulWidget {
  const SessionConfigSheet({
    super.key,
    required this.generationCompleteColleges,
    required this.initialConfig,
  });

  final List<CollegeListEntry> generationCompleteColleges;
  final HomeSessionConfig initialConfig;

  @override
  ConsumerState<SessionConfigSheet> createState() => _SessionConfigSheetState();
}

class _SessionConfigSheetState extends ConsumerState<SessionConfigSheet> {
  late String _selectedCollegeId;
  late String _selectedCollegeName;
  late List<String> _selectedRangs;
  late int _maxCards;
  late String _statusFilter;

  @override
  void initState() {
    super.initState();
    final validColleges = widget.generationCompleteColleges
        .where((e) => e.userStatus != null)
        .toList();
    final initialStillValid = validColleges
        .any((e) => e.userStatus!.collegeId == widget.initialConfig.collegeId);
    if (initialStillValid || validColleges.isEmpty) {
      _selectedCollegeId = widget.initialConfig.collegeId;
      _selectedCollegeName = widget.initialConfig.collegeName;
    } else {
      _selectedCollegeId = validColleges.first.userStatus!.collegeId;
      _selectedCollegeName = validColleges.first.catalog.name;
    }
    _selectedRangs = widget.initialConfig.rangs?.toList() ?? [];
    _maxCards = widget.initialConfig.maxCards;
    _statusFilter = widget.initialConfig.statusFilter;
  }

  void _saveAndClose() {
    final newConfig = HomeSessionConfig(
      collegeId: _selectedCollegeId,
      collegeName: _selectedCollegeName,
      rangs: _selectedRangs.isEmpty ? null : List.unmodifiable(_selectedRangs),
      maxCards: _maxCards,
      statusFilter: _statusFilter,
    );
    ref.read(homeSessionConfigProvider.notifier).setConfig(newConfig);
    ref.invalidate(homeProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.cardPadding,
                  AppSpacing.screenMargin,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text('Personnaliser la session', style: AppTypography.titleMedium()),
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    _CollegeSelector(
                      colleges: widget.generationCompleteColleges,
                      selectedId: _selectedCollegeId,
                      onChanged: (id, name) {
                        setState(() {
                          _selectedCollegeId = id;
                          _selectedCollegeName = name;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    _RangChips(
                      selected: _selectedRangs,
                      onChanged: (rangs) => setState(() => _selectedRangs = rangs),
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    _CardCountStepper(
                      value: _maxCards,
                      onChanged: (v) => setState(() => _maxCards = v),
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                    _StatusFilterChips(
                      selected: _statusFilter,
                      onChanged: (f) => setState(() => _statusFilter = f),
                    ),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                0,
                AppSpacing.screenMargin,
                AppSpacing.cardPadding,
              ),
              child: ShadButton(
                onPressed: _saveAndClose,
                width: double.infinity,
                child: const Text('Enregistrer la session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _CollegeSelector ─────────────────────────────────────────────────────────

class _CollegeSelector extends StatelessWidget {
  const _CollegeSelector({
    required this.colleges,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CollegeListEntry> colleges;
  final String selectedId;
  final void Function(String id, String name) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Collège', style: AppTypography.bodyMedium()),
        const SizedBox(height: 8),
        for (final entry in colleges)
          if (entry.userStatus != null)
            RadioListTile<String>(
              value: entry.userStatus!.collegeId,
              groupValue: selectedId,
              title: Text(entry.catalog.name, style: AppTypography.bodyMedium()),
              onChanged: (v) {
                if (v != null) onChanged(v, entry.catalog.name);
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
      ],
    );
  }
}

// ─── _RangChips ───────────────────────────────────────────────────────────────

class _RangChips extends StatelessWidget {
  const _RangChips({required this.selected, required this.onChanged});

  final List<String> selected;
  final void Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Rangs (vide = tous)', style: AppTypography.bodyMedium()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['A', 'B', 'C'].map((r) {
            final isSelected = selected.contains(r);
            return FilterChip(
              label: Text(r),
              selected: isSelected,
              onSelected: (on) {
                final updated = List<String>.from(selected);
                if (on) {
                  updated.add(r);
                } else {
                  updated.remove(r);
                }
                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── _CardCountStepper ────────────────────────────────────────────────────────

class _CardCountStepper extends StatelessWidget {
  const _CardCountStepper({required this.value, required this.onChanged});

  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Nombre de fiches (0 = toutes)', style: AppTypography.bodyMedium()),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                value == 0 ? 'Toutes' : '$value',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── _StatusFilterChips ───────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.selected, required this.onChanged});

  final String selected;
  final void Function(String) onChanged;

  static const _options = [
    ('all', 'Toutes'),
    ('a_revoir', 'À revoir'),
    ('non_vues', 'Non vues'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Statut des fiches', style: AppTypography.bodyMedium()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _options.map(((String, String) opt) {
            final (value, label) = opt;
            return FilterChip(
              label: Text(label),
              selected: selected == value,
              onSelected: (_) => onChanged(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
