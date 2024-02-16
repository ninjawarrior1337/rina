import 'package:flutter/foundation.dart';

@immutable
class PinecilState {
  final List<int> rawData;
  const PinecilState(this.rawData);

  int _valueFromParameterIndex(int idx) {
    var slice = rawData.sublist(idx*4, (idx*4)+4);

    final uint8List = Uint8List(4)
      ..[3] = slice[3]
      ..[2] = slice[2]
      ..[1] = slice[1]
      ..[0] = slice[0];
    return ByteData.sublistView(uint8List).getUint32(0, Endian.little);
  }

  int get liveTemperature => _valueFromParameterIndex(0);
  get liveSetPoint => _valueFromParameterIndex(1);
  get dcInputVoltage => _valueFromParameterIndex(2)*0.1;
  get handleTemperature => _valueFromParameterIndex(3);
  get powerLevel => _valueFromParameterIndex(4);
  get powerSource => _valueFromParameterIndex(5);
  Duration get uptime => Duration(milliseconds: 100*_valueFromParameterIndex(7));
  get timeOfLastMovement => _valueFromParameterIndex(8);
  get rawTipReading => _valueFromParameterIndex(10);
}
