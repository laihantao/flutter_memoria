import '../data/app_database.dart';

class SettlementEntry {
  final String fromPersonId;
  final String toPersonId;
  final double amount;
  final String currencyCode;

  const SettlementEntry({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
    required this.currencyCode,
  });
}

class SettleUpService {
  /// Given split_aa transactions, compute simplified repayment suggestions.
  /// Treat and Personal transactions are excluded.
  /// All amounts are converted to base via exchangeRateToBase before netting.
  List<SettlementEntry> compute({
    required List<Transaction> transactions,
    required Map<String, List<TransactionSplit>> splitsByTxId,
    required String baseCurrency,
  }) {
    // net balance per person: positive = owed money, negative = owes money
    final Map<String, double> balances = {};

    for (final tx in transactions) {
      if (tx.splitType != 'split_aa') continue;

      final baseAmount = tx.amount * tx.exchangeRateToBase;
      final splits = splitsByTxId[tx.id] ?? [];
      if (splits.isEmpty) continue;

      // Payer gains credit for baseAmount (skip if no payer assigned)
      if (tx.payerPersonId == null) continue;
      balances[tx.payerPersonId!] =
          (balances[tx.payerPersonId!] ?? 0) + baseAmount;

      // Each split participant owes their share
      for (final split in splits) {
        final share = split.shareAmount * tx.exchangeRateToBase;
        balances[split.personId] =
            (balances[split.personId] ?? 0) - share;
      }
    }

    // Debt simplification: greedy match largest creditor with largest debtor
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _Balance(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _Balance(e.key, -e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final settlements = <SettlementEntry>[];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];
      final amount = creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount;

      if (amount > 0.01) {
        settlements.add(SettlementEntry(
          fromPersonId: debtor.personId,
          toPersonId: creditor.personId,
          amount: double.parse(amount.toStringAsFixed(2)),
          currencyCode: baseCurrency,
        ));
      }

      creditor.amount -= amount;
      debtor.amount -= amount;

      if (creditor.amount < 0.01) ci++;
      if (debtor.amount < 0.01) di++;
    }

    return settlements;
  }
}

class _Balance {
  final String personId;
  double amount;
  _Balance(this.personId, this.amount);
}
