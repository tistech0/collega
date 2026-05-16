import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/search/search_providers.dart';
import 'package:collega_app/features/search/widgets/search_result_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(searchNotifierProvider.notifier).onQueryChanged(value);
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchNotifierProvider.notifier).onQueryChanged('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);

    ref.listen(searchNotifierProvider, (prev, next) {
      if (next.isOffline && !(prev?.isOffline ?? false)) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('La recherche nécessite une connexion internet'),
          ),
        );
      }
      if (next.isEmpty && !(prev?.isEmpty ?? false)) {
        _focusNode.requestFocus();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.screenMargin,
                AppSpacing.screenMargin,
                8,
              ),
              child: ShadInput(
                controller: _controller,
                focusNode: _focusNode,
                placeholder:
                    const Text('Rechercher un item, un signe, une dose...'),
                onChanged: _onQueryChanged,
                suffix: state.hasQuery
                    ? GestureDetector(
                        onTap: _clearSearch,
                        child: const Icon(Icons.clear, size: 18),
                      )
                    : null,
              ),
            ),
            if (state.isLoading)
              const LinearProgressIndicator()
            else if (state.hasResults) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.results.length} ${state.results.length > 1 ? 'items trouvés' : 'item trouvé'}',
                    style: AppTypography.bodyMedium(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                  ),
                  itemCount: state.results.length,
                  itemBuilder: (ctx, i) =>
                      SearchResultTile(result: state.results[i]),
                ),
              ),
            ] else if (state.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Text(
                    "Aucun résultat pour '${state.query}' — essaie un autre mot",
                    style: AppTypography.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else if (state.error != null) ...[
              Expanded(
                child: Center(
                  child: Text(
                    state.error!,
                    style: AppTypography.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else ...[
              Expanded(child: Container()),
            ],
          ],
        ),
      ),
    );
  }
}
