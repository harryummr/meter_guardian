import 'package:hive/hive.dart';

part 'ocr_region_memory.g.dart';

/// Learned "where the real reading lives" pattern for a specific meter and
/// scan type ("bill" or "meter_photo"). After the user confirms a reading once,
/// we remember the normalized bounding box + digit-count so future scans of
/// the *same physical meter/bill* can be matched with much higher confidence,
/// instead of re-guessing from scratch every time.
@HiveType(typeId: 2)
class OcrRegionMemory extends HiveObject {
  @HiveField(0)
  String id; // "${meterId}_${scanType}"

  @HiveField(1)
  String meterId;

  @HiveField(2)
  String scanType; // 'bill' | 'meter_photo'

  /// Normalized bounding box (0.0-1.0 relative to image width/height) of the
  /// text block that held the confirmed reading last time.
  @HiveField(3)
  double left;

  @HiveField(4)
  double top;

  @HiveField(5)
  double right;

  @HiveField(6)
  double bottom;

  /// Digit count of the confirmed reading (e.g. "42685" -> 5). Readings on a
  /// given physical meter/bill layout almost always keep the same digit count,
  /// so this is a strong secondary signal.
  @HiveField(7)
  int digitCount;

  @HiveField(8)
  DateTime updatedAt;

  /// How many times this region has been confirmed correct in a row —
  /// used to weight confidence higher the more consistent it's been.
  @HiveField(9)
  int confirmCount;

  OcrRegionMemory({
    required this.id,
    required this.meterId,
    required this.scanType,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.digitCount,
    required this.updatedAt,
    this.confirmCount = 1,
  });

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}
