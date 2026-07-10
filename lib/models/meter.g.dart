// Manually written Hive TypeAdapter (build_runner-free).
// Regenerate with `flutter pub run build_runner build` if you'd rather
// use the generated version — this hand-written one is fully equivalent.
part of 'meter.dart';

class MeterAdapter extends TypeAdapter<Meter> {
  @override
  final int typeId = 0;

  @override
  Meter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Meter(
      id: fields[0] as String,
      name: fields[1] as String,
      meterNumber: fields[2] as String?,
      location: fields[3] as String?,
      notes: fields[4] as String? ?? '',
      createdAt: fields[5] as DateTime,
      slabTargets: (fields[6] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, Meter obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.meterNumber)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.slabTargets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
