import 'dart:async';

import 'package:flutter/services.dart';

import 'codec.dart';
import 'models.dart';

abstract class SensorHub {
  static final SensorHubImpl instance = SensorHubImpl();

  Future<void> start({required int hz});
  Future<void> stop();
  Future<SensorInfo> describe();
  Stream<SensorBatch> get batches;
  Stream<SensorFault> get faults;
}

class SensorHubImpl implements SensorHub {
  final MethodChannel controlChannel = const MethodChannel('sensor_hub/control');
  final BasicMessageChannel<Object?> dataChannel = const BasicMessageChannel<Object?>('sensor_hub/data', SensorHubCodec());

  final StreamController<SensorBatch> batchController = StreamController<SensorBatch>.broadcast(sync: true);
  final StreamController<SensorFault> faultController = StreamController<SensorFault>.broadcast(sync: true);

  bool attached = false;
  int? sessionId;

  @override
  Stream<SensorBatch> get batches {
    return batchController.stream;
  }

  @override
  Stream<SensorFault> get faults {
    return faultController.stream;
  }

  @override
  Future<SensorInfo> describe() async {
    await attach();
    Map? info = await invoke<Map>('describe');
    return SensorInfo(model: info!['model'] as String, maxHz: info['maxHz'] as int);
  }

  @override
  Future<void> start({required int hz}) async {
    sessionId = null;
    await attach();
    sessionId = await invoke<int>('start', {'hz': hz});
  }

  @override
  Future<void> stop() async {
    sessionId = null;
    if (!attached) {
      return;
    }
    await invoke<void>('stop');
  }

  Future<void> injectFault(String message) async {
    await attach();
    await invoke<void>('injectFault', {'message': message});
  }

  Future<void> attach() async {
    if (attached) {
      return;
    }
    dataChannel.setMessageHandler(onMessage);
    await invoke<void>('attach');
    attached = true;
  }

  Future<Object?> onMessage(Object? message) async {
    if (sessionId != null && message is List && message[0] == sessionId) {
      Object? payload = message[1];
      if (payload is SensorBatch) {
        batchController.add(payload);
      }
      if (payload is Map) {
        faultController.add(SensorFault(code: payload['code'] as String, message: payload['message'] as String));
      }
    }
    return true;
  }

  Future<T?> invoke<T>(String method, [Object? arguments]) async {
    try {
      return await controlChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw SensorFault(code: e.code, message: e.message ?? e.code);
    } on MissingPluginException {
      throw const SensorFault(code: 'unavailable', message: 'sensor_hub is not supported on this platform');
    }
  }
}
