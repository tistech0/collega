/// Série de l'Accueil (partie D) : badge « N jours d'affilée » à partir de 2.
const kStreakMinShown = 2;

/// Jours d'affilée avec une session du jour terminée, en remontant depuis
/// [today] (jours epoch).
///
/// - aujourd'hui non terminé ne casse pas : on compte alors depuis hier ;
/// - un jour [excused] (décalé, ou rien à réviser) ne casse pas et ne compte pas ;
/// - tout autre jour sans session terminée arrête la série.
int streakLength({required int today, required Set<int> completed, required Set<int> excused}) {
  if (completed.isEmpty) return 0;
  final oldest = completed.reduce((a, b) => a < b ? a : b);
  var count = completed.contains(today) ? 1 : 0;
  for (var day = today - 1; day >= oldest; day--) {
    if (completed.contains(day)) {
      count++;
    } else if (!excused.contains(day)) {
      break;
    }
  }
  return count;
}
