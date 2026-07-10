part of 'ocr_region_memory.dart';

class OcrRegionMemoryAdapter extends TypeAdapter<OcrRegionMemory> {
  @override
  final int typeId = 2;

  @override
  OcrRegionMemory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OcrRegionMemory(
      id: fields[0] as String,
      meterId: fields[1] as String,
      scanType: fields[2] as String,
      left: fields[3] as double,
      top: fields[4] as double,
      right: fields[5] as double,
      bottom: fields[6] as double,
      digitCount: fields[7] as int,
      updatedAt: fields[8] as DateTime,
      confirmCount: fields[9] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, OcrRegionMemory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.meterId)
      ..writeByte(2)
      ..write(obj.scanType)
      ..writeByte(3)
      ..write(obj.left)
      ..writeByte(4)
      ..write(obj.top)
      ..writeByte(5)
      ..write(obj.right)
      ..writeByte(6)
      ..write(obj.bottom)
      ..writeByte(7)
      ..write(obj.digitCount)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.confirmCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrRegionMemoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
