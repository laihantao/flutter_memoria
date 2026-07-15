import 'money.dart';

/// Pure helpers for split math. Kept free of Flutter/DB types so the
/// add-expense form, the split service, and tests all share the same rules.
/// See docs/expenses-split-enhancement-spec.md.
///
/// All three modes reduce to one shape: a payer plus a `personId → amount` map
/// of who *bears* the cost ([buildShares]). Debt only arises where bearer !=
/// payer, so 个人 and 请客 — whose sole bearer IS the payer — settle to zero
/// without any mode-specific branch downstream.

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

/// `shareType` written for an even AA share.
const kShareEqual = 'equal';

/// `shareType` written when one person bears the whole amount (个人 / 请客).
const kShareFull = 'full';

/// Who bears [amount], for any split mode — the single rule the form, the
/// settlement math, and the dashboards all share.
///
/// - `personal` / `treat`: `{payerId: amount}`. The bearer is the payer, so no
///   debt is produced. The two differ only in who the form lets you pick as
///   payer (个人 forces "me"; 请客 lets you pick the treater).
/// - `split_aa`: [amount] spread evenly over `rosterIds − excludedIds`, with
///   the payer force-included (see [computeSharerIds]).
///
/// Returns empty when there is no payer, or for AA with an empty roster.
Map<String, double> buildShares({
  required String splitType,
  required double amount,
  required String? payerId,
  required Iterable<String> rosterIds,
  required Set<String> excludedIds,
}) {
  if (payerId == null) return const {};
  if (splitType != 'split_aa') return {payerId: amount};

  final sharers = computeSharerIds(
    rosterIds: rosterIds,
    excludedIds: excludedIds,
    payerId: payerId,
  );
  if (sharers.isEmpty) return const {};
  final perHead = perHeadShare(amount, sharers.length);
  return {for (final id in sharers) id: perHead};
}

/// The `shareType` that pairs with [buildShares] for [splitType].
String shareTypeFor(String splitType) =>
    splitType == 'split_aa' ? kShareEqual : kShareFull;

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
