import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:rina/repr/PinecilState.dart';

class PinecilBLEController extends GetxController {
  PinecilBLEController({required this.device});

  BluetoothDevice device;
  var discoveredServices = <BluetoothService>[];
  var connected = false.obs;
  var lastRead = <int>[].obs;
  var temperatureHistory = <(int, int)>[].obs;
  late Timer updateStateTimer;
  late Timer reconnectTimer;

  PinecilState get pinecilState => PinecilState(lastRead);

  @override
  void onInit() async {
    super.onInit();

    await connect();

    reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!device.isConnected) {
        await connect();
      }
    });

    updateStateTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (device.isConnected) {
        await readState();
      }
    });
  }

  @override
  void onClose() async {
    updateStateTimer.cancel();
    reconnectTimer.cancel();
    await disconnect();
  }

  Future<void> connect() async {
    if (device.isConnected) {
      return;
    }

    var subscription = device.connectionState.listen((event) {
      if (event == BluetoothConnectionState.disconnected) {
        discoveredServices.clear();
        connected.value = false;
      }
    });
    device.cancelWhenDisconnected(subscription, next: true, delayed: true);

    await device.connect();
    connected.value = true;
  }

  Future<void> disconnect() async {
    if (!device.isConnected) {
      return;
    }

    await device.disconnect();
  }

  Future<void> readState() async {
    if (!device.isConnected) {
      return;
    }

    if (discoveredServices.isEmpty) {
      discoveredServices = await device.discoverServices();
    }
    for (BluetoothService service in discoveredServices) {
      for (BluetoothCharacteristic char in service.characteristics) {
        if (char.characteristicUuid ==
            Guid("9eae1001-9d0d-48c5-AA55-33e27f9bc533")) {
          var state = await char.read();
          lastRead.value = state;
        }
      }
    }

    if (temperatureHistory.length > 60) {
      temperatureHistory.removeAt(0);
    }
    temperatureHistory.add(
        (pinecilState.uptime.inMilliseconds, pinecilState.liveTemperature));
  }
}

class PinecilInfo extends StatelessWidget {
  final BluetoothDevice device;

  const PinecilInfo({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final PinecilBLEController controller =
        Get.put(PinecilBLEController(device: device));

    return Scaffold(
      appBar: AppBar(
        title: Text(device.advName),
      ),
      body: Center(
        child: Obx(() {
          if (controller.connected.value) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 2,
                child: LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                          spots: controller.temperatureHistory
                              .map((element) => FlSpot(element.$1.toDouble(),
                                  element.$2.toDouble()))
                              .toList(),
                          isCurved: true,
                          dotData: FlDotData(show: false)),
                    ],
                    titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: false,
                        )),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false))))),
              ),
            );
          } else {
            return const CircularProgressIndicator();
          }
        }),
      ),
    );
  }
}
