import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rina/views/PinecilInfo.dart';
import 'package:rina/widgets/PinecilListItem.dart';

void main() {
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
    return ProviderScope(
        child: MaterialApp(
      home: MyApp(),
      theme: ThemeData(colorScheme: lightDynamic),
      darkTheme: ThemeData(colorScheme: darkDynamic),
      themeMode: ThemeMode.system,
    ));
  }));
}

class BleChangeNotifier extends ChangeNotifier {
  List<BluetoothDevice> devices = [];
  bool isScanning = false;

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> startScan() async {
    if (isScanning) {
      return;
    }
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          if (!devices.contains(r.device)) {
            devices.add(r.device);
            notifyListeners();
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
        withServices: [Guid("9eae1000-9d0d-48c5-AA55-33e27f9bc533")],
        timeout: const Duration(seconds: 3));
    isScanning = true;
    notifyListeners();
    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    stopScan();
  }
}

final bleChangeNotifierProvider =
    ChangeNotifierProvider((ref) => BleChangeNotifier());

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(context, ref) {
    final bleChangeNotifier = ref.watch(bleChangeNotifierProvider);

    useEffect(() {
      bleChangeNotifier.startScan();
      return null;
    }, []);

    return Scaffold(
        appBar: AppBar(title: const Text("Rina")),

        body: Stack(children: [
          RefreshIndicator(
              onRefresh: bleChangeNotifier.startScan,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: bleChangeNotifier.devices.length,
                itemBuilder: (_, idx) {
                  var device = bleChangeNotifier.devices[idx];
                  return PinecilListTile(
                      device: device,
                      onTap: () async {
                        await bleChangeNotifier.stopScan();
                        if (!context.mounted) {
                          return;
                        }
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (ctx) => PinecilInfo(device: device)));
                      });
                },
              ))
        ]),
        floatingActionButton: bleChangeNotifier.isScanning
            ? const CircularProgressIndicator()
            : FloatingActionButton(
                onPressed: bleChangeNotifier.startScan,
                child: const Icon(Icons.refresh)));
  }
}
