import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/bill_record.dart';
import '../models/meter.dart';
import '../services/calculation_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class MeterWithData {
  final Meter meter;
  final BillRecord? activeBill;
  final MeterCalculation calculation;

  MeterWithData({
    required this.meter,
    required this.activeBill,
    required this.calculation,
  });
}

class MeterProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  List<MeterWithData> _meters = [];

  List<MeterWithData> get meters => _meters;

  Future<void> loadAll() async {
    final rawMeters = HiveService.instance.getAllMeters();
    _meters = rawMeters.map((m) {
      final bill = HiveService.instance.getActiveBillForMeter(m.id);
      final calc = CalculationService.calculate(bill, targets: m.slabTargets);
      return MeterWithData(meter: m, activeBill: bill, calculation: calc);
    }).toList();
    notifyListeners();
  }

  Future<Meter> addMeter({
    required String name,
    String? meterNumber,
    String? location,
    String notes = '',
  }) async {
    final meter = Meter(
      id: _uuid.v4(),
      name: name,
      meterNumber: meterNumber,
      location: location,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await HiveService.instance.saveMeter(meter);
    await loadAll();
    return meter;
  }

  Future<void> deleteMeter(String meterId) async {
    await HiveService.instance.deleteMeter(meterId);
    await loadAll();
  }

  List<BillRecord> historyFor(String meterId) =>
      HiveService.instance.getBillsForMeter(meterId);

  /// Creates a new billing cycle record from OCR'd (or manually entered) bill data.
  Future<BillRecord> addBillRecord({
    required String meterId,
    required String billingMonth,
    required double presentReading,
    required double previousReading,
    required DateTime issueDate,
    DateTime? dueDate,
    String? billImagePath,
  }) async {
    final record = BillRecord(
      id: _uuid.v4(),
      meterId: meterId,
      billingMonth: billingMonth,
      presentReading: presentReading,
      previousReading: previousReading,
      issueDate: issueDate,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      billImagePath: billImagePath,
    );
    await HiveService.instance.saveBillRecord(record);
    await loadAll();
    return record;
  }

  /// Sets the "meter start" checkpoint (date + time) for a bill's counting period.
  Future<void> setMeterStart(String billId, DateTime startDateTime) async {
    final all = HiveService.instance.getBillsForMeter(
      HiveService.instance.getAllMeters().firstWhere(
        (m) => HiveService.instance
            .getBillsForMeter(m.id)
            .any((b) => b.id == billId),
      ).id,
    );
    final record = all.firstWhere((b) => b.id == billId);
    record.meterStartDateTime = startDateTime;
    await HiveService.instance.saveBillRecord(record);
    await loadAll();
  }

  /// Updates the live reading for a bill's counting period (from a meter photo
  /// scan) and fires any threshold alerts that were newly crossed.
  Future<void> updateCurrentReading({
    required Meter meter,
    required String billId,
    required double newReading,
  }) async {
    final bills = HiveService.instance.getBillsForMeter(meter.id);
    final record = bills.firstWhere((b) => b.id == billId);

    final previousCalc = CalculationService.calculate(record, targets: meter.slabTargets);
    final previousThreshold = previousCalc.alertThresholdCrossed ?? 0;

    record.currentReading = newReading;
    record.currentReadingUpdatedAt = DateTime.now();
    await HiveService.instance.saveBillRecord(record);

    final newCalc = CalculationService.calculate(record, targets: meter.slabTargets);
    final newThreshold = newCalc.alertThresholdCrossed ?? 0;

    if (newThreshold > previousThreshold && newCalc.unitsUsed != null) {
      await NotificationService.instance.showThresholdAlert(
        meterName: meter.name,
        threshold: newThreshold,
        unitsUsed: newCalc.unitsUsed!,
      );
    }

    if (newCalc.averagePerDay != null &&
        newCalc.remainingUnitsByTarget[200] != null &&
        newCalc.estimatedDaysLeftByTarget[200] != null &&
        newCalc.averagePerDay! > 15 &&
        (newCalc.estimatedDaysLeftByTarget[200] ?? 999) < 5) {
      await NotificationService.instance.showHighAverageWarning(
        meterName: meter.name,
        averagePerDay: newCalc.averagePerDay!,
        daysUntil200: newCalc.estimatedDaysLeftByTarget[200]!,
      );
    }

    await loadAll();
  }
}
