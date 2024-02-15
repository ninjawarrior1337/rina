import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:rina/views/PinecilInfo.dart';
import 'package:rina/widgets/PinecilListItem.dart';

void main() {
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
    return GetMaterialApp(
      home: MyApp(),
      theme: ThemeData(colorScheme: lightDynamic),
      darkTheme: ThemeData(colorScheme: darkDynamic),
      themeMode: ThemeMode.system,
    );
  }));
}

class BluetoothController extends GetxController {
  var devices = <BluetoothDevice>[].obs;
  var scanning = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await beginScan();
  }

  Future<void> beginScan() async {
    if (scanning.isTrue) {
      return;
    }
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          if (!devices.contains(r.device)) {
            devices.add(r.device);
          }
          print(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');
        }
      },
      onError: (e) => print(e),
    );

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    // Start scanning w/ timeout
    // Optional: you can use `stopScan()` as an alternative to using a timeout
    // Note: scan filters use an *or* behavior. i.e. if you set `withServices` & `withNames`
    //   we return all the advertisments that match any of the specified services *or* any
    //   of the specified names.
    devices.clear();
    await FlutterBluePlus.startScan(
        withServices: [Guid("9eae1000-9d0d-48c5-AA55-33e27f9bc533")], timeout: const Duration(seconds: 3));
    scanning.value = true;
    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    scanning.value = false;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(context) {
    // Instantiate your class using Get.put() to make it available for all "child" routes there.
    final BluetoothController ble = Get.put(BluetoothController());

    return Scaffold(
        // Use Obx(()=> to update Text() whenever count is changed.
        appBar: AppBar(title: Text("Rina")),

        // Replace the 8 lines Navigator.push by a simple Get.to(). You don't need context
        body: Stack(children: [
          Obx(
            () => RefreshIndicator(
                onRefresh: ble.beginScan,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: ble.devices.length,
                  itemBuilder: (_, idx) {
                    var device = ble.devices[idx];
                    return PinecilListTile(device: device, onTap: () async {
                      await ble.stopScan();
                      Get.to(() => PinecilInfo(device: device));
                    });
                  },
                )),
          )
        ]),
        floatingActionButton: Obx(() => ble.scanning.isTrue
            ? CircularProgressIndicator()
            : FloatingActionButton(
                child: Icon(Icons.refresh),
                onPressed: () async => ble.beginScan())));
  }
}