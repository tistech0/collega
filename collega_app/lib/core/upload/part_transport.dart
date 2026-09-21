import 'dart:async';
import 'dart:io';

/// Un morceau à envoyer : `PUT /v1/colleges/import/{uploadId}/parts/{partIndex}` avec [file] en body.
class PartUpload {
  const PartUpload({required this.uploadId, required this.partIndex, required this.file});
  final String uploadId;
  final int partIndex;
  final File file;
}

sealed class PartEvent {
  const PartEvent(this.uploadId, this.partIndex);
  final String uploadId;
  final int partIndex;
}

/// Progression 0..1 d'un morceau.
class PartProgress extends PartEvent {
  const PartProgress(super.uploadId, super.partIndex, this.fraction);
  final double fraction;
}

class PartDone extends PartEvent {
  const PartDone(super.uploadId, super.partIndex);
}

class PartFailed extends PartEvent {
  const PartFailed(super.uploadId, super.partIndex, this.error);
  final Object error;
}

/// Transport des morceaux — implémenté en arrière-plan par background_downloader,
/// en mémoire pour les tests.
abstract class PartTransport {
  Future<void> enqueue(PartUpload part);

  /// Broadcast : progression / fin / échec de chaque morceau.
  Stream<PartEvent> get events;

  /// Morceaux déjà en file ou en cours pour cet upload (à ne pas ré-enqueuer).
  Future<Set<int>> queued(String uploadId);

  Future<void> cancelAll(String uploadId);
}

/// Transport de test : chaque morceau est "envoyé" immédiatement (ou échoue s'il est dans [failing]).
class InMemoryPartTransport implements PartTransport {
  InMemoryPartTransport({this.failing = const {}});
  final Set<int> failing;
  final List<PartUpload> enqueued = [];
  final _controller = StreamController<PartEvent>.broadcast();

  @override
  Stream<PartEvent> get events => _controller.stream;

  @override
  Future<void> enqueue(PartUpload part) async {
    enqueued.add(part);
    scheduleMicrotask(() {
      _controller.add(PartProgress(part.uploadId, part.partIndex, 1));
      _controller.add(
        failing.contains(part.partIndex)
            ? PartFailed(part.uploadId, part.partIndex, StateError('fail'))
            : PartDone(part.uploadId, part.partIndex),
      );
    });
  }

  @override
  Future<Set<int>> queued(String uploadId) async => {};

  @override
  Future<void> cancelAll(String uploadId) async {}
}
