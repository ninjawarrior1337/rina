import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rina/repr/PinecilState.dart';

final bleConnectionStateProvider =
    StreamProvider.family<BluetoothConnectionState, BluetoothDevice>(
        (ref, device) {
  return device.connectionState;
});

final pinecilDataProvider =
    StreamProvider.autoDispose.family<PinecilState, BluetoothDevice>((ref, device) async* {
  final connState = ref.watch(bleConnectionStateProvider(device));

  await device.connect();
  ref.onDispose(() async {await device.disconnect();});

  if (connState.value == BluetoothConnectionState.connected) {
    final services = await device.discoverServices();
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.characteristicUuid ==
              Guid("9eae1001-9d0d-48c5-AA55-33e27f9bc533")) {
            if(device.isConnected) {
              var data = await char.read();
              yield PinecilState(data);
            }
          }
        }
      }
    }
  }
});

class PinecilInfo extends HookConsumerWidget {
  final BluetoothDevice device;

  const PinecilInfo({super.key, required this.device});

  Widget PinecilLineChart(List<(double, double)> data) {
    return LineChart(LineChartData(
        lineBarsData: [
          LineChartBarData(
              spots: data.map((e) => FlSpot(e.$1, e.$2)).toList(),
              isCurved: true,
              dotData: FlDotData(show: false)),
        ],
        titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: false,
                )),
            topTitles:
            AxisTitles(sideTitles: SideTitles(showTitles: false)))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(bleConnectionStateProvider(device));
    final pinecilState = ref.watch(pinecilDataProvider(device));

    final pinecilTemperatureHistory = useState(<(double, double)>[]);

    useEffect(() {
      if(pinecilState.hasValue) {
        final newTemperature = pinecilState.value!.liveTemperature.toDouble();
        final newUptime = pinecilState.value!.uptime.inMilliseconds.toDouble();

        if(pinecilTemperatureHistory.value.length > 60) {
          pinecilTemperatureHistory.value.removeAt(0);
        }
        pinecilTemperatureHistory.value = [...pinecilTemperatureHistory.value, (newUptime, newTemperature)];
      }
      return null;
    }, [pinecilState]);

    return Scaffold(
      appBar: AppBar(
        title: Text(device.advName),
      ),
      body: Center(
        child: connState.whenOrNull(
            data: (conn) {
              switch (conn) {
                case BluetoothConnectionState.disconnected:
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(
                        height: 15,
                      ),
                      Chip(
                          label: Text("Trying to connect to ${device.advName}"))
                    ],
                  );
                case BluetoothConnectionState.connected:
                  return pinecilState.whenOrNull(
                      data: (state) => Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: PinecilLineChart(pinecilTemperatureHistory.value),
                                ),
                              ),
                              Text(state.uptime.toString())
                            ],
                          ),
                      loading: () => CircularProgressIndicator());
                default:
                  return CircularProgressIndicator();
              }
            },
            loading: () => CircularProgressIndicator()),
      ),
    );
  }
}
