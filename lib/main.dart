import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:torch_light/torch_light.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Future.delayed(Duration(milliseconds: 500)); // Optional for stability
  await initializeService();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: (_) async => true,
    ),
  );

  await service.startService();
}

Future<void> onStart(ServiceInstance service) async {
  await Firebase.initializeApp();

  if (service is AndroidServiceInstance) {
    try {
      service.setForegroundNotificationInfo(
        title: "Torch Service",
        content: "Listening for flashlight commands...",
      );
    } catch (_) {}
  }

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

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: FlashlightPage(),
    debugShowCheckedModeBanner: false,
  );
}

class FlashlightPage extends StatefulWidget {
  const FlashlightPage({super.key});

  @override
  State<FlashlightPage> createState() => _FlashlightPageState();
}

class _FlashlightPageState extends State<FlashlightPage> {
  bool _isTorchOn = false;
  final _dbRef = FirebaseDatabase.instance.ref('flashlight');
  StreamSubscription<DatabaseEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToFlashlightCommand();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToFlashlightCommand() {
    _subscription = _dbRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == 'on') {
        _toggleFlashlight(turnOn: true);
      } else if (value == 'off') {
        _toggleFlashlight(turnOn: false);
      }
    });
  }

  Future<void> _toggleFlashlight({bool? turnOn}) async {
    try {
      bool shouldTurnOn = turnOn ?? !_isTorchOn;

      if (shouldTurnOn && !_isTorchOn) {
        await TorchLight.enableTorch();
      } else if (!shouldTurnOn && _isTorchOn) {
        await TorchLight.disableTorch();
      }

      if (mounted) {
        setState(() {
          _isTorchOn = shouldTurnOn;
        });
      }
    } catch (e) {
      debugPrint('Error toggling flashlight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Torch not available or permission denied'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Firebase Flashlight')),
    body: Column(
      children: [
        const Spacer(),
        const Text(
          'Control flashlight via Firebase:\nSet `flashlight` = "on" or "off"',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Center(
            child: SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: _toggleFlashlight,
                child: Text(
                  _isTorchOn ? 'Turn Off' : 'Turn On',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
