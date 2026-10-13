import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/sensor_provider.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SensorProvider sensor = Provider.of<SensorProvider>(context);

    String infoText = 'Native sensor: …';
    if (sensor.info != null) {
      infoText = '${sensor.info!.model} · max ${sensor.info!.maxHz} Hz';
    }

    List<Widget> faultWidgets = [];
    if (sensor.faults.isEmpty) {
      faultWidgets.add(const Text('None'));
    }
    for (int i = 0; i < sensor.faults.length; i++) {
      faultWidgets.add(Text('${sensor.faults[i].code}: ${sensor.faults[i].message}'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Reading · 200 Hz')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(infoText),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (SensorProvider.graphSize - 1).toDouble(),
                  minY: -1.5,
                  maxY: 1.5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: buildSpots(sensor),
                      color: Colors.green,
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [HorizontalLine(y: 0, color: Colors.red, strokeWidth: 1)],
                  ),
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                ),
                duration: Duration.zero,
              ),
            ),
            // const SizedBox(height: 16),
            statRow('Batches / s (≤ 20)', sensor.batchesPerSec),
            statRow('Samples / s', sensor.samplesPerSec),
            statRow('Last batch size', sensor.lastBatchSize),
            statRow('Largest batch (coalesced)', sensor.biggestBatch),
            statRow('Last startMicros', sensor.lastStartMicros),
            statRow('Total samples', sensor.totalSamples),
            statRow('Timeline gaps', sensor.gaps),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: sensor.toggle,
                  icon: Icon(sensor.running ? Icons.stop : Icons.play_arrow),
                  label: Text(sensor.running ? 'Stop' : 'Start 200 Hz'),
                ),
                OutlinedButton(onPressed: sensor.running ? sensor.blockUi : null, child: const Text('Block UI 400 ms')),
                OutlinedButton(
                  onPressed: sensor.running ? sensor.injectFault : null,
                  child: const Text('Inject fault'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Faults (typed, separate stream)'),
            const SizedBox(height: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: faultWidgets),
          ],
        ),
      ),
    );
  }

  List<FlSpot> buildSpots(SensorProvider sensor) {
    List<FlSpot> spots = [];
    for (int i = 0; i < sensor.graph.length; i++) {
      spots.add(FlSpot(i.toDouble(), sensor.graph[i]));
    }
    return spots;
  }

  Widget statRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
