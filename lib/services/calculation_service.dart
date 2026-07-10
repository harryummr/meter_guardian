import '../models/bill_record.dart';

enum SlabStatus { safe, warning, danger }

class MeterCalculation {
  final double? unitsUsed;
  final double? averagePerDay;
  final double? elapsedDays;
  final Map<int, double?> remainingUnitsByTarget; // target -> remaining
  final Map<int, double?> estimatedDaysLeftByTarget; // target -> days left
  final SlabStatus status;
  final int? alertThresholdCrossed; // e.g. 150, 180, 190, 195, 199, 200

  MeterCalculation({
    required this.unitsUsed,
    required this.averagePerDay,
    required this.elapsedDays,
    required this.remainingUnitsByTarget,
    required this.estimatedDaysLeftByTarget,
    required this.status,
    required this.alertThresholdCrossed,
  });

  static MeterCalculation empty() => MeterCalculation(
        unitsUsed: null,
        averagePerDay: null,
        elapsedDays: null,
        remainingUnitsByTarget: {},
        estimatedDaysLeftByTarget: {},
        status: SlabStatus.safe,
        alertThresholdCrossed: null,
      );
}

class CalculationService {
  static const List<int> pkAlertThresholds = [150, 180, 190, 195, 199, 200];

  /// Runs all the core math for a bill record against a set of slab targets
  /// (defaults to the standard 200/300/500 unit tariff breakpoints).
  static MeterCalculation calculate(
    BillRecord? bill, {
    List<int> targets = const [200, 300, 500],
  }) {
    if (bill == null) return MeterCalculation.empty();

    final units = bill.unitsUsedSinceBill;
    final avg = bill.averageUnitsPerDay;
    final elapsed = bill.elapsedDays;

    final remaining = <int, double?>{};
    final daysLeft = <int, double?>{};

    for (final target in targets) {
      if (units == null) {
        remaining[target] = null;
        daysLeft[target] = null;
        continue;
      }
      final rem = target - units;
      remaining[target] = rem;
      if (avg == null || avg <= 0) {
        daysLeft[target] = null;
      } else {
        daysLeft[target] = rem / avg;
      }
    }

    // Status is driven by proximity to the first (primary) target — normally 200.
    final primaryTarget = targets.isNotEmpty ? targets.first : 200;
    SlabStatus status = SlabStatus.safe;
    int? crossed;

    if (units != null) {
      if (units >= primaryTarget) {
        status = SlabStatus.danger;
      } else if (units >= primaryTarget * 0.95) {
        status = SlabStatus.danger;
      } else if (units >= primaryTarget * 0.75) {
        status = SlabStatus.warning;
      } else {
        status = SlabStatus.safe;
      }

      for (final threshold in pkAlertThresholds.reversed) {
        if (units >= threshold) {
          crossed = threshold;
          break;
        }
      }
    }

    return MeterCalculation(
      unitsUsed: units,
      averagePerDay: avg,
      elapsedDays: elapsed,
      remainingUnitsByTarget: remaining,
      estimatedDaysLeftByTarget: daysLeft,
      status: status,
      alertThresholdCrossed: crossed,
    );
  }
}
