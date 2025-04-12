import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:torch_light/torch_light.dart';

Future<void> onStart(ServiceInstance service) async {
  // 🟢 IMMEDIATELY show foreground notification
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Torch Service",
      content: "Starting service...",
    );
  }

  // 🟢 THEN initialize Firebase
  await Firebase.initializeApp();

  // 🔦 Optional: check torch availability
  bool isTorchAvailable = false;
  try {
    isTorchAvailable = await TorchLight.isTorchAvailable();
  } catch (e) {
    print("Torch check failed: $e");
  }

  final dbRef = FirebaseDatabase.instance.ref('flashlight');

  dbRef.onValue.listen((event) async {
    final value = event.snapshot.value;
    try {
      if (!isTorchAvailable) return;

      if (value == 'on') {
        await TorchLight.enableTorch();
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Torch Service",
            content: "Torch is ON",
          );
        }
      } else if (value == 'off') {
        await TorchLight.disableTorch();
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Torch Service",
            content: "Torch is OFF",
          );
        }
      }
    } catch (e) {
      print("Background error: $e");
    }
  });

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}
