import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Service for child app to communicate with backend
class BackendService {
  static String get baseUrl => ApiConfig.baseUrl;
  
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }

  /// Pair this child device with parent using 6-digit code
  /// Returns: { success, parent_device_id, child_device_id }
  Future<Map<String, dynamic>?> pairDevice({
    required String childDeviceId,
    required String childDeviceName,
    required String platform,
    required String pairingCode,
  }) async {
    try {
      print('🔗 Pairing device with code: $pairingCode');
      
      final response = await http.post(
        Uri.parse('$baseUrl/devices/pair'),
        headers: _getHeaders(),
        body: json.encode({
          'child_device_id': childDeviceId,
          'child_device_name': childDeviceName,
          'platform': platform,
          'pairing_code': pairingCode,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('   ✅ Device paired successfully');
        return data;
      } else {
        print('   ❌ Pairing failed: ${response.statusCode}');
        print('   Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error pairing device: $e');
      return null;
    }
  }

  /// Get allowed websites for this child device from parent
  Future<List<dynamic>?> getDeviceWebsites(String deviceId) async {
    try {
      print('🌐 Getting websites for device: $deviceId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId/websites'),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> websites = data['websites'] ?? [];
        print('   ✅ Retrieved ${websites.length} websites');
        return websites;
      } else {
        print('   ❌ Failed to get websites: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting websites: $e');
      return null;
    }
  }

  /// Report activity/usage to backend
  Future<bool> reportActivity({
    required String deviceId,
    required String domain,
    required String action, // 'allowed' or 'blocked'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/activity/log'),
        headers: _getHeaders(),
        body: json.encode({
          'device_id': deviceId,
          'domain': domain,
          'action': action,
          'activity_type': 'access',
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('⚠️ Failed to report activity: $e');
      return false;
    }
  }

  /// Check if backend is reachable
  Future<bool> isBackendReachable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status/health'),
      ).timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check pairing status with backend
  /// Returns: { paired, parent_id, subscription_status, subscription_active, days_remaining, forced_lock, grace_period }
  Future<Map<String, dynamic>?> checkPairingStatus(String deviceId) async {
    try {
      print('🔍 Checking pairing status for device: $deviceId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/device/pairing-status/$deviceId'),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectionTimeout);

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          print('   ✅ Pairing status: ${data['paired']}');
          if (data['subscription_status'] != null) {
            print('   📊 Subscription: ${data['subscription_status']} (${data['days_remaining']} days remaining)');
          }
          return data;
        } catch (e) {
          print('   ⚠️ JSON decode error: $e');
          throw Exception('Invalid response format');
        }
      } else {
        print('   ❌ Failed to check pairing status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error checking pairing status: $e');
      rethrow;
    }
  }

  /// Send heartbeat to backend to indicate device is online
  Future<bool> sendHeartbeat(String deviceId, String parentId, String deviceName, String deviceType, String platform) async {
    try {
      print('🔵 Sending heartbeat to $baseUrl/device/heartbeat');
      print('   Device: $deviceId, Parent: $parentId, Name: $deviceName, Type: $deviceType, Platform: $platform');
      
      final response = await http.post(
        Uri.parse('$baseUrl/device/heartbeat'),
        headers: _getHeaders(),
        body: json.encode({
          'device_id': deviceId,
          'parent_id': parentId,
          'device_name': deviceName,
          'device_type': deviceType,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('   ✅ Heartbeat sent successfully');
      } else {
        print('   ❌ Heartbeat failed: ${response.statusCode} - ${response.body}');
      }
      
      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Failed to send heartbeat: $e');
      return false;
    }
  }
}
