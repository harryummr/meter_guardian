part of 'bill_record.dart';

class BillRecordAdapter extends TypeAdapter<BillRecord> {
  @override
  final int typeId = 1;

  @override
  BillRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillRecord(
      id: fields[0] as String,
      meterId: fields[1] as String,
      billingMonth: fields[2] as String,
      presentReading: fields[3] as double,
      previousReading: fields[4] as double,
      issueDate: fields[5] as DateTime,
      dueDate: fields[6] as DateTime?,
      meterStartDateTime: fields[7] as DateTime?,
      currentReading: fields[8] as double?,
      currentReadingUpdatedAt: fields[9] as DateTime?,
      createdAt: fields[10] as DateTime,
      billImagePath: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BillRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.meterId)
      ..writeByte(2)
      ..write(obj.billingMonth)
      ..writeByte(3)
      ..write(obj.presentReading)
      ..writeByte(4)
      ..write(obj.previousReading)
      ..writeByte(5)
      ..write(obj.issueDate)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.meterStartDateTime)
      ..writeByte(8)
      ..write(obj.currentReading)
      ..writeByte(9)
      ..write(obj.currentReadingUpdatedAt)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.billImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
