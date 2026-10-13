import 'dart:typed_data';

class SensorBatch {
  SensorBatch({required this.startMicros, required this.values});

  final int startMicros;
  final Float32List values;

  int get count {
    return values.length;
  }
}

class SensorInfo {
  const SensorInfo({required this.model, required this.maxHz});

  final String model;
  final int maxHz;
}

class SensorFault implements Exception {
  const SensorFault({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() {
    return 'SensorFault($code: $message)';
  }
}
