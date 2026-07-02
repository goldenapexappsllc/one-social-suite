import 'package:flutter/material.dart';
import 'app.dart';
import 'services/app_lock_service.dart';
import 'services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.instance.init();
  await AppLockService.instance.load();
  runApp(const OneSocialSuiteApp());
}
