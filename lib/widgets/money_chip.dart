import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class MoneyChip extends StatelessWidget {
  final double amount;
  final String currency;
  final bool isExpense;

  const MoneyChip({
    super.key,
    required this.amount,
    required this.currency,
    this.isExpense = true,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final color = isExpense ? AppColors.expense : AppColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${isExpense ? '-' : '+'}$currency ${fmt.format(amount)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
