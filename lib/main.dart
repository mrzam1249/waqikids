import 'package:flutter/material.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'services/device_service.dart';
import 'services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaqiKidsChildApp());
}

class WaqiKidsChildApp extends StatefulWidget {
  const WaqiKidsChildApp({Key? key}) : super(key: key);

  @override
  State<WaqiKidsChildApp> createState() => _WaqiKidsChildAppState();
}

class _WaqiKidsChildAppState extends State<WaqiKidsChildApp> {
  bool? _isPaired;
  String? _subscriptionMessage;

  @override
  void initState() {
    super.initState();
    _checkPairingStatus();
  }

  Future<void> _checkPairingStatus() async {
    try {
      // Get device ID
      final deviceId = await DeviceService.getDeviceId();
      print('🔍 Checking pairing for device: $deviceId');
      
      // Check pairing status with backend (validates subscription too)
      final backendService = BackendService();
      final pairingStatus = await backendService.checkPairingStatus(deviceId);
      
      if (pairingStatus != null) {
        print('✅ Got pairing status from backend: $pairingStatus');
        
        // Backend returned status - trust it over local cache
        final paired = pairingStatus['paired'] == true;
        
        if (!paired) {
          // Not paired - clear local cache and show pairing screen
          await DeviceService.clearPairing();
          setState(() {
            _isPaired = false;
            _subscriptionMessage = null;
          });
          return;
        }
        
        // Device is paired - check subscription status
        final forcedLock = pairingStatus['forced_lock'] == true;
        final gracePeriod = pairingStatus['grace_period'] == true;
        final subscriptionStatus = pairingStatus['subscription_status'] as String?;
        final daysRemaining = pairingStatus['days_remaining'] as int?;
        final parentId = pairingStatus['parent_id'] as String?;
        
        // Save parent_id if we got it (needed for heartbeat)
        if (parentId != null && parentId.isNotEmpty) {
          await DeviceService.savePairingInfo(
            parentDeviceId: parentId,
            parentId: parentId,
          );
          print('✅ Saved parent_id from pairing status: $parentId');
        }
        
        if (forcedLock) {
          // Subscription expired - show message
          setState(() {
            _isPaired = true;
            _subscriptionMessage = '⚠️ Parent subscription expired. Internet is locked. Ask parent to renew.';
          });
        } else if (gracePeriod) {
          // Grace period - show warning
          setState(() {
            _isPaired = true;
            _subscriptionMessage = '⏰ Parent subscription in grace period ($daysRemaining days left). Renew soon!';
          });
        } else {
          // All good
          setState(() {
            _isPaired = true;
            _subscriptionMessage = null;
          });
        }
      } else {
        // Backend unreachable - fall back to local cache
        print('⚠️ Backend unreachable, using cached pairing status');
        final paired = await DeviceService.isPaired();
        setState(() {
          _isPaired = paired;
          _subscriptionMessage = paired 
            ? '⚠️ Offline mode - subscription status not verified'
            : null;
        });
      }
    } catch (e, stackTrace) {
      // Error during pairing check - use local cache
      print('❌ Error checking pairing status: $e');
      print('Stack trace: $stackTrace');
      final paired = await DeviceService.isPaired();
      setState(() {
        _isPaired = paired;
        _subscriptionMessage = paired 
          ? '⚠️ Offline mode - could not verify subscription'
          : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaqiKids Child',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: _isPaired == null
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : (_isPaired!
              ? HomeScreen(subscriptionMessage: _subscriptionMessage)
              : const PairingScreen()),
      routes: {
        '/pairing': (context) => const PairingScreen(),
        '/home': (context) => HomeScreen(subscriptionMessage: _subscriptionMessage),
      },
    );
  }
}
