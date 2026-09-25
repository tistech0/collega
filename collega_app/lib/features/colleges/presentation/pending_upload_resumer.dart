import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/features/colleges/colleges_import_providers.dart';

/// Reprend un upload par morceaux interrompu (Story 7.11 : app tuée pendant
/// l'envoi) au démarrage et à chaque retour au premier plan, quel que soit
/// l'onglet ouvert. Posé autour du shell des onglets.
class PendingUploadResumer extends ConsumerStatefulWidget {
  const PendingUploadResumer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PendingUploadResumer> createState() => _PendingUploadResumerState();
}

class _PendingUploadResumerState extends ConsumerState<PendingUploadResumer> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _resume);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
    _lifecycle; // écoute le retour au premier plan
  }

  void _resume() {
    if (!mounted) return;
    ref.read(collegeImportProvider.notifier).resumePendingUpload();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
