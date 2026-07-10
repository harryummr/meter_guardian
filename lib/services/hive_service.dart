import 'package:hive_flutter/hive_flutter.dart';

import '../models/meter.dart';
import '../models/bill_record.dart';
import '../models/ocr_region_memory.dart';

/// Single access point for all local (offline) storage. Everything lives on
/// the device only — nothing is ever uploaded anywhere.
class HiveService {
  HiveService._();
  static final HiveService instance = HiveService._();

  static const _metersBoxName = 'meters';
  static const _billsBoxName = 'bill_records';
  static const _ocrMemoryBoxName = 'ocr_region_memory';

  late Box<Meter> _metersBox;
  late Box<BillRecord> _billsBox;
  late Box<OcrRegionMemory> _ocrMemoryBox;

  Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(MeterAdapter());
    Hive.registerAdapter(BillRecordAdapter());
    Hive.registerAdapter(OcrRegionMemoryAdapter());

    _metersBox = await Hive.openBox<Meter>(_metersBoxName);
    _billsBox = await Hive.openBox<BillRecord>(_billsBoxName);
    _ocrMemoryBox = await Hive.openBox<OcrRegionMemory>(_ocrMemoryBoxName);
  }

  // ---------------- Meters ----------------

  List<Meter> getAllMeters() => _metersBox.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Meter? getMeter(String id) =>
      _metersBox.values.where((m) => m.id == id).firstOrNull;

  Future<void> saveMeter(Meter meter) async {
    await _metersBox.put(meter.id, meter);
  }

  Future<void> deleteMeter(String id) async {
    await _metersBox.delete(id);
    final relatedBills = _billsBox.values.where((b) => b.meterId == id).toList();
    for (final b in relatedBills) {
      await b.delete();
    }
    final bill = await _ocrMemoryBox.get('${id}_bill');
    if (bill != null) await bill.delete();
    final meterPhoto = await _ocrMemoryBox.get('${id}_meter_photo');
    if (meterPhoto != null) await meterPhoto.delete();
  }

  // ---------------- Bill Records ----------------

  List<BillRecord> getBillsForMeter(String meterId) {
    final bills = _billsBox.values.where((b) => b.meterId == meterId).toList();
    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bills;
  }

  /// The most recent bill record for a meter (the one the dashboard shows).
  BillRecord? getActiveBillForMeter(String meterId) {
    final bills = getBillsForMeter(meterId);
    return bills.isNotEmpty ? bills.first : null;
  }

  Future<void> saveBillRecord(BillRecord record) async {
    await _billsBox.put(record.id, record);
  }

  Future<void> deleteBillRecord(String id) async {
    await _billsBox.delete(id);
  }

  // ---------------- OCR Region Memory ----------------

  OcrRegionMemory? getOcrRegionMemory(String meterId, String scanType) {
    return _ocrMemoryBox.get('${meterId}_$scanType');
  }

  Future<void> saveOcrRegionMemory(OcrRegionMemory memory) async {
    await _ocrMemoryBox.put(memory.id, memory);
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
