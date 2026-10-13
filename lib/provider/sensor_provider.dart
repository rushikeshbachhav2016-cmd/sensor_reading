import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensor_hub/sensor_hub.dart';

class SensorProvider extends ChangeNotifier {
  static  int hz = 200;
  static  int graphSize = 400; // last 2 seconds at 200 Hz

  SensorHubImpl hub = SensorHub.instance;

  // last 400 readings for the graph, oldest first
  List<double> graph = [];

  SensorInfo? info;
  bool running = false;
  List<SensorFault> faults = [];

  // stats shown on screen
  int batchesPerSec = 0;
  int samplesPerSec = 0;
  int lastBatchSize = 0;
  int biggestBatch = 0;
  int lastStartMicros = 0;
  int totalSamples = 0;
  int gaps = 0;

  // for working out batches/samples per second
  Stopwatch secondTimer = Stopwatch();
  int batchCount = 0;
  int sampleCount = 0;

  StreamSubscription<SensorBatch>? batchSub;
  StreamSubscription<SensorFault>? faultSub;

  SensorProvider() {
    batchSub = hub.batches.listen(onBatch);
    faultSub = hub.faults.listen(addFault);
    loadInfo();
  }

  Future<void> loadInfo() async {
    try {
      info = await hub.describe();
      notifyListeners();
    } on SensorFault catch (fault) {
      addFault(fault);
    }
  }

  Future<void> toggle() async {
    if (running) {
      await stop();
    } else {
      await start();
    }
  }

  Future<void> start() async {
    try {
      await hub.start(hz: hz);
      lastBatchSize = 0;
      secondTimer.reset();
      secondTimer.start();
      running = true;
      notifyListeners();
    } on SensorFault catch (fault) {
      addFault(fault);
    }
  }

  Future<void> stop() async {
    running = false;
    notifyListeners();
    try {
      await hub.stop();
    } on SensorFault catch (fault) {
      addFault(fault);
    }
  }

  Future<void> injectFault() async {
    try {
      await hub.injectFault('Injected from the UI');
    } on SensorFault catch (fault) {
      addFault(fault);
    }
  }

  // Freezes the UI on purpose so native has to put more samples in each batch.
  void blockUi() {
    Stopwatch watch = Stopwatch();
    watch.start();
    while (watch.elapsedMilliseconds < 400) {}
  }

  void onBatch(SensorBatch batch) {
    // the new batch should start right where the last one ended
    if (lastBatchSize > 0) {
      int expected = lastStartMicros + lastBatchSize * 1000000 ~/ hz;
      if ((batch.startMicros - expected).abs() > 1) {
        gaps++;
      }
    }

    for (int i = 0; i < batch.count; i++) {
      graph.add(batch.values[i]);
    }
    while (graph.length > graphSize) {
      graph.removeAt(0);
    }

    lastStartMicros = batch.startMicros;
    lastBatchSize = batch.count;
    totalSamples += batch.count;
    if (batch.count > biggestBatch) {
      biggestBatch = batch.count;
    }

    batchCount++;
    sampleCount += batch.count;
    int ms = secondTimer.elapsedMilliseconds;
    if (ms >= 1000) {
      batchesPerSec = (batchCount * 1000 / ms).round();
      samplesPerSec = (sampleCount * 1000 / ms).round();
      batchCount = 0;
      sampleCount = 0;
      secondTimer.reset();
      secondTimer.start();
    }

    notifyListeners();
  }

  void addFault(SensorFault fault) {
    faults.insert(0, fault);
    if (faults.length > 5) {
      faults.removeLast();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    batchSub?.cancel();
    faultSub?.cancel();
    super.dispose();
  }
}
