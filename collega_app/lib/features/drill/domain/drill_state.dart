enum DrillEvaluationResult {
  aRevoir,
  bien,
  maitrise,
}

extension DrillEvaluationResultX on DrillEvaluationResult {
  bool get slidesUp => this == DrillEvaluationResult.maitrise;
  bool get slidesDown => this == DrillEvaluationResult.aRevoir;

  String get label {
    switch (this) {
      case DrillEvaluationResult.aRevoir:
        return 'À revoir';
      case DrillEvaluationResult.bien:
        return 'Bien';
      case DrillEvaluationResult.maitrise:
        return 'Maîtrisé';
    }
  }
}
