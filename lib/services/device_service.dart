import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Device service for managing device ID and pairing status
class DeviceService {
  static const String _deviceIdKey = 'device_id';
  static const String _parentDeviceIdKey = 'parent_device_id';
  static const String _parentIdKey = 'parent_id';
  static const String _isPairedKey = 'is_paired';
  
  /// Get or generate device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
  
  /// Generate UUID v4 format device ID
  static Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String platformInfo = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        platformInfo = '${androidInfo.id}-${androidInfo.device}-${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        platformInfo = '${iosInfo.identifierForVendor}-${iosInfo.model}';
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final combined = '$platformInfo-$timestamp';
      final hash = sha256.convert(utf8.encode(combined)).toString();
      
      // Format as UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuid = '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
                  '4${hash.substring(13, 16)}-${_getVariantChar(hash[16])}${hash.substring(17, 20)}-'
                  '${hash.substring(20, 32)}';
      
      return uuid.toLowerCase();
    } catch (e) {
      // Fallback to random UUID
      return _generateRandomUUID();
    }
  }
  
  static String _getVariantChar(String char) {
    final charCode = char.codeUnitAt(0);
    final variantDigit = ((charCode % 4) + 8).toRadixString(16);
    return variantDigit;
  }
  
  static String _generateRandomUUID() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode(random.toString())).toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
          '4${hash.substring(13, 16)}-8${hash.substring(17, 20)}-'
          '${hash.substring(20, 32)}';
  }
  
  /// Save pairing information after successful pairing
  static Future<void> savePairingInfo({
    required String parentDeviceId,
    required String parentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parentDeviceIdKey, parentDeviceId);
    await prefs.setString(_parentIdKey, parentId);
    await prefs.setBool(_isPairedKey, true);
  }
  
  /// Check if device is paired
  static Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPairedKey) ?? false;
  }
  
  /// Get parent device ID
  static Future<String?> getParentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_parentDeviceIdKey);
  }
  
  /// Get parent ID (UUID)
  static Future<String?> getParentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_parentIdKey);
  }
  
  /// Clear pairing information (for testing/reset)
  static Future<void> clearPairing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_parentDeviceIdKey);
    await prefs.remove(_parentIdKey);
    await prefs.setBool(_isPairedKey, false);
  }
  
  /// Get platform name
  static String getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    // For Windows testing, default to 'android' to satisfy backend validation
    return 'android';
  }
}
