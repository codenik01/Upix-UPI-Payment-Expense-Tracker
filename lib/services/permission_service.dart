import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestSMSPermission() async {
    try {
      final status = await Permission.sms.status;

      if (!status.isGranted) {
        final result = await Permission.sms.request();
        return result.isGranted;
      }

      return true;
    } on PlatformException catch (e) {
      print('PlatformException when requesting SMS permission: $e');
      return false;
    }
  }

  static Future<bool> checkSMSPermission() async {
    try {
      final status = await Permission.sms.status;
      return status.isGranted;
    } on PlatformException catch (e) {
      print('PlatformException when checking SMS permission: $e');
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
