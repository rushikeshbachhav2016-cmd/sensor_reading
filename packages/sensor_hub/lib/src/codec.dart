import 'package:flutter/services.dart';

import 'models.dart';

const int batchType = 128;

class SensorHubCodec extends StandardMessageCodec {
  const SensorHubCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is SensorBatch) {
      buffer.putUint8(batchType);
      buffer.putInt64(value.startMicros);
      buffer.putInt32(value.count);
      buffer.putFloat32List(value.values);
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == batchType) {
      int startMicros = buffer.getInt64();
      int count = buffer.getInt32();
      return SensorBatch(startMicros: startMicros, values: buffer.getFloat32List(count));
    }
    return super.readValueOfType(type, buffer);
  }
}
