import 'package:hive/hive.dart';

part 'bill_record.g.dart';

/// Represents one billing cycle for a specific meter: the bill OCR data,
/// the meter-start checkpoint, and the latest confirmed live reading.
@HiveType(typeId: 1)
class BillRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String meterId;

  @HiveField(2)
  String billingMonth;

  /// "Present Reading" printed on the bill (the reading the bill was issued at).
  @HiveField(3)
  double presentReading;

  /// "Previous Reading" printed on the bill (start of the billed period).
  @HiveField(4)
  double previousReading;

  @HiveField(5)
  DateTime issueDate;

  @HiveField(6)
  DateTime? dueDate;

  /// When the user started counting usage against this bill's present reading
  /// (date + time combined into one DateTime).
  @HiveField(7)
  DateTime? meterStartDateTime;

  /// Most recent confirmed reading taken from a live meter-photo scan.
  @HiveField(8)
  double? currentReading;

  @HiveField(9)
  DateTime? currentReadingUpdatedAt;

  @HiveField(10)
  DateTime createdAt;

  /// Path to the original bill image (kept for reference/history view).
  @HiveField(11)
  String? billImagePath;

  BillRecord({
    required this.id,
    required this.meterId,
    required this.billingMonth,
    required this.presentReading,
    required this.previousReading,
    required this.issueDate,
    this.dueDate,
    this.meterStartDateTime,
    this.currentReading,
    this.currentReadingUpdatedAt,
    required this.createdAt,
    this.billImagePath,
  });

  /// Units used on the *bill itself* (previous cycle), for history charts.
  double get billedUnits => presentReading - previousReading;

  /// Units used since this bill was issued, based on the latest live reading.
  double? get unitsUsedSinceBill {
    if (currentReading == null) return null;
    final units = currentReading! - presentReading;
    return units < 0 ? 0 : units;
  }

  /// Elapsed time since the meter-start checkpoint, in fractional days.
  double? get elapsedDays {
    if (meterStartDateTime == null) return null;
    final ref = currentReadingUpdatedAt ?? DateTime.now();
    final diff = ref.difference(meterStartDateTime!);
    final days = diff.inMinutes / (60 * 24);
    return days <= 0 ? null : days;
  }

  /// Average units/day since the meter-start checkpoint.
  double? get averageUnitsPerDay {
    final units = unitsUsedSinceBill;
    final days = elapsedDays;
    if (units == null || days == null || days <= 0) return null;
    return units / days;
  }
}
