import '../data/progress_models.dart';

/// A personal-record card, per the concept's `screenProgress()` `.pr-card`
/// ("New personal record — Back Squat 82.5kg +2.5kg").
class PersonalRecord {
  const PersonalRecord({required this.exerciseName, required this.weightKg, this.previousBestKg});

  final String exerciseName;
  final num weightKg;
  final num? previousBestKg;

  /// The exercise's second-highest logged weight, regardless of when it was
  /// logged relative to the PR -- not necessarily the weight logged
  /// immediately before the PR. Null when there's only one weight logged
  /// for this exercise, so the concept's "+2.5kg" delta badge has nothing
  /// to compare against.
  num? get deltaKg => previousBestKg == null ? null : weightKg - previousBestKg!;
}

/// The most recently-set personal record across every exercise the client
/// has logged a weight for: for each exercise name, its max
/// actual_weight_kg is that exercise's PR; this returns whichever PR was
/// logged most recently, with the delta against that same exercise's
/// next-highest weight (if any). Pure function, unit-tested without
/// mocking Supabase. Null when `entries` is empty (nothing logged yet).
PersonalRecord? findMostRecentPersonalRecord(List<WeightLogEntry> entries) {
  if (entries.isEmpty) return null;

  final byExercise = <String, List<WeightLogEntry>>{};
  for (final entry in entries) {
    byExercise.putIfAbsent(entry.exerciseName, () => []).add(entry);
  }

  PersonalRecord? best;
  DateTime? bestAchievedOn;
  for (final entries in byExercise.values) {
    final sorted = [...entries]..sort((a, b) => b.weightKg.compareTo(a.weightKg));
    final top = sorted.first;
    final previousBest = sorted.length > 1 ? sorted[1].weightKg : null;

    if (bestAchievedOn == null || top.logDate.isAfter(bestAchievedOn)) {
      best = PersonalRecord(exerciseName: top.exerciseName, weightKg: top.weightKg, previousBestKg: previousBest);
      bestAchievedOn = top.logDate;
    }
  }
  return best;
}
