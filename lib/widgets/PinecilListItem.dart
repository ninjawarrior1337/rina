import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class PinecilListTile extends StatelessWidget {
  final BluetoothDevice device;
  final Function()? onTap;

  const PinecilListTile({super.key, required this.device, this.onTap});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Card(
      child: ListTile(
        title: Text(device.advName),
        subtitle: Text(device.remoteId.str),
        leading: CircleAvatar(child: Icon(Icons.edit),),
        onTap: onTap,
        trailing: Icon(Icons.chevron_right),
      ),
    );
  }
}
