import 'package:hive/hive.dart';

part 'meter.g.dart';

/// Represents a single electricity meter tracked by the user.
/// Each meter is fully independent: its own bills, readings, averages and history.
@HiveType(typeId: 0)
class Meter extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? meterNumber;

  @HiveField(3)
  String? location;

  @HiveField(4)
  String notes;

  @HiveField(5)
  DateTime createdAt;

  /// Tariff slab targets this meter should be warned about (defaults to PK slabs).
  @HiveField(6)
  List<int> slabTargets;

  Meter({
    required this.id,
    required this.name,
    this.meterNumber,
    this.location,
    this.notes = '',
    required this.createdAt,
    List<int>? slabTargets,
  }) : slabTargets = slabTargets ?? [200, 300, 500];
}
