import 'money.dart';

/// Pure helpers for AA (equal) split math. Kept free of Flutter/DB types so the
/// add-expense form, the (Phase 2) split service, and tests all share the same
/// rules. See docs/expenses-split-enhancement-spec.md.

/// The people who actually share an AA expense: everyone in [rosterIds] except
/// those in [excludedIds]. The payer always shares and can never be excluded,
/// so [payerId] is force-included when present in the roster (defensive — the
/// UI already disables excluding the payer).
Set<String> computeSharerIds({
  required Iterable<String> rosterIds,
  required Set<String> excludedIds,
  required String? payerId,
}) {
  final roster = rosterIds.toList();
  final sharers = <String>{
    for (final id in roster)
      if (!excludedIds.contains(id)) id,
  };
  if (payerId != null && roster.contains(payerId)) sharers.add(payerId);
  return sharers;
}

/// Per-head amount for an equal split, rounded half-up to 2dp (D8).
/// Returns 0 when there are no sharers (defensive; the UI guarantees ≥1 because
/// the payer always shares).
double perHeadShare(double amount, int sharerCount) {
  if (sharerCount <= 0) return 0;
  return roundHalfUp(amount / sharerCount);
}

/// Reconstructs the exclude set when editing a saved AA expense (D1): everyone
/// in the current [rosterIds] who is NOT among the persisted [sharerIds].
Set<String> reconstructExcluded({
  required Iterable<String> rosterIds,
  required Set<String> sharerIds,
}) {
  return {
    for (final id in rosterIds)
      if (!sharerIds.contains(id)) id,
  };
}
