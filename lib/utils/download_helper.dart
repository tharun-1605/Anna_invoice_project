import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadHelper {
  static Future<void> saveFileWithPermission({
    required BuildContext context,
    required String name,
    required Uint8List bytes,
    required String fileExtension,
    required MimeType mimeType,
  }) async {
    bool hasPermission = false;

    if (kIsWeb) {
      hasPermission = true;
    } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final plugin = DeviceInfoPlugin();
          final androidInfo = await plugin.androidInfo;
          
          if (androidInfo.version.sdkInt >= 33) {
            // Android 13+: Storage permission is deprecated, FileSaver uses SAF automatically.
            hasPermission = true;
          } else if (androidInfo.version.sdkInt >= 29) {
            // Android 10-12: Try to request, but SAF still works even if denied.
            final status = await Permission.storage.request();
            hasPermission = status.isGranted || status.isPermanentlyDenied; // SAF fallback
          } else {
            // Android 9 and below: Must have permission
            final status = await Permission.storage.request();
            hasPermission = status.isGranted;
          }
        } catch (e) {
          // If device_info_plus throws an exception (e.g., missing plugin from lack of full restart)
          final status = await Permission.storage.request();
          hasPermission = status.isGranted || status.isPermanentlyDenied; 
        }
      } else {
        // iOS
        final status = await Permission.storage.request();
        hasPermission = status.isGranted;
      }
    } else {
      // Desktop platforms
      hasPermission = true;
    }

    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download files.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final path = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: fileExtension,
        mimeType: mimeType,
      );

      if (context.mounted && path != null && path.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded successfully to $path'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> requestStoragePermissionOnStartup() async {
    if (kIsWeb) return;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final plugin = DeviceInfoPlugin();
        final androidInfo = await plugin.androidInfo;
        
        if (androidInfo.version.sdkInt < 33) {
          await Permission.storage.request();
        }
      } catch (e) {
        // Fallback if plugin fails
        await Permission.storage.request();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.storage.request();
    }
  }
}

