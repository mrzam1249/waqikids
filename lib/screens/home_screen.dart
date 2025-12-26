import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/backend_service.dart';
import '../services/device_service.dart';
import 'dart:async';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final String? subscriptionMessage;
  
  const HomeScreen({Key? key, this.subscriptionMessage}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BackendService _backend = BackendService();
  List<dynamic> _websites = [];
  bool _isLoading = true;
  String? _deviceId;
  String? _parentId;
  String _deviceName = 'Unknown Device';
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  /// Handle heartbeat response - check if device was unlinked
  Future<void> _handleHeartbeatResponse(Map<String, dynamic>? response) async {
    if (response == null) return; // Network error, don't logout
    
    final paired = response['paired'] == true;
    if (!paired) {
      print('🚫 Device was unlinked by parent! Clearing local data and redirecting to pairing...');
      await DeviceService.clearPairing();
      
      if (mounted) {
        // Navigate to pairing screen and remove all previous routes
        Navigator.of(context).pushNamedAndRemoveUntil('/pairing', (route) => false);
      }
    }
  }

  void _startHeartbeat() {
    // Send heartbeat every 2 minutes (production-ready interval)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_deviceId != null && _parentId != null) {
        print('📡 Sending periodic heartbeat: deviceId=$_deviceId, parentId=$_parentId');
        final response = await _backend.sendHeartbeat(
          _deviceId!, 
          _parentId!, 
          _deviceName, 
          Platform.isWindows || Platform.isMacOS || Platform.isLinux ? 'tablet' : 'phone',
          DeviceService.getPlatform()
        );
        
        // Check if device was unlinked (uses heartbeat response - no extra API call)
        await _handleHeartbeatResponse(response);
      } else {
        print('⚠️ Cannot send heartbeat: deviceId=$_deviceId, parentId=$_parentId');
      }
    });
    
    // Send initial heartbeat immediately
    Future.delayed(const Duration(seconds: 2), () async {
      if (_deviceId != null && _parentId != null) {
        print('📡 Sending initial heartbeat: deviceId=$_deviceId, parentId=$_parentId');
        final response = await _backend.sendHeartbeat(
          _deviceId!, 
          _parentId!, 
          _deviceName, 
          Platform.isWindows || Platform.isMacOS || Platform.isLinux ? 'tablet' : 'phone',
          DeviceService.getPlatform()
        );
        
        // Check if device was unlinked on startup
        await _handleHeartbeatResponse(response);
      } else {
        print('⚠️ Cannot send initial heartbeat: deviceId=$_deviceId, parentId=$_parentId');
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _deviceId = await DeviceService.getDeviceId();
    _parentId = await DeviceService.getParentId();
    _deviceName = Platform.isWindows ? 'Windows PC' : 
                 Platform.isAndroid ? 'Android Device' : 
                 Platform.isIOS ? 'iOS Device' : 'Unknown';
    await _fetchWebsites();
    setState(() => _isLoading = false);
    
    // Start heartbeat AFTER we have deviceId and parentId
    _startHeartbeat();
  }

  Future<void> _fetchWebsites() async {
    if (_deviceId == null) return;
    
    final websites = await _backend.getDeviceWebsites(_deviceId!);
    if (websites != null) {
      setState(() => _websites = websites);
    }
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEF3C7), // Warm yellow
              Color(0xFFBFDBFE), // Sky blue
              Color(0xFFFCE7F3), // Soft pink
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9333EA)),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive padding based on screen width
                    final isTablet = constraints.maxWidth > 600;
                    final padding = isTablet ? 32.0 : 16.0;
                    
                    return RefreshIndicator(
                      onRefresh: _loadData,
                      color: Color(0xFF9333EA),
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(isTablet),
                            // Subscription message banner
                            if (widget.subscriptionMessage != null) ...[
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.subscriptionMessage!.contains('expired')
                                      ? Colors.red.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.subscriptionMessage!.contains('expired')
                                        ? Colors.red.shade300
                                        : Colors.orange.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.subscriptionMessage!.contains('expired')
                                          ? Icons.lock_outline
                                          : Icons.warning_amber_rounded,
                                      color: widget.subscriptionMessage!.contains('expired')
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.subscriptionMessage!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: widget.subscriptionMessage!.contains('expired')
                                              ? Colors.red.shade900
                                              : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: isTablet ? 32 : 24),
                            _buildPrayerTimes(isTablet),
                            SizedBox(height: isTablet ? 32 : 24),
                            _buildWebsitesSection(isTablet),
                            SizedBox(height: isTablet ? 32 : 24),
                            _buildDuaaSection(isTablet),
                            SizedBox(height: 24), // Bottom padding
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    final fontSize = isTablet ? 28.0 : 24.0;
    final subtitleSize = isTablet ? 16.0 : 14.0;
    
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.child_care, color: Colors.white, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assalamu Alaikum! 🌙',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose what to explore today',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimes(bool isTablet) {
    final titleSize = isTablet ? 22.0 : 20.0;
    final itemHeight = isTablet ? 110.0 : 100.0;
    
    final now = DateTime.now();
    final prayers = [
      {'name': 'Fajr', 'time': '05:30 AM', 'icon': Icons.wb_twilight},
      {'name': 'Dhuhr', 'time': '12:15 PM', 'icon': Icons.wb_sunny},
      {'name': 'Asr', 'time': '03:30 PM', 'icon': Icons.brightness_6},
      {'name': 'Maghrib', 'time': '05:45 PM', 'icon': Icons.brightness_3},
      {'name': 'Isha', 'time': '07:15 PM', 'icon': Icons.nightlight_round},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFF8B5CF6), size: 24),
              SizedBox(width: 8),
              Text(
                'Prayer Times 🕌',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: itemHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: prayers.length,
            itemBuilder: (context, index) {
              final prayer = prayers[index];
              return Container(
                width: 110,
                margin: EdgeInsets.only(right: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      prayer['icon'] as IconData,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 8),
                    Text(
                      prayer['name'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      prayer['time'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebsitesSection(bool isTablet) {
    final titleSize = isTablet ? 22.0 : 20.0;
    final columns = isTablet ? 3 : 2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.language, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 8),
              Text(
                'My Websites 🌐',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _websites.isEmpty
            ? Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.web_asset_off, size: 48, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 12),
                      Text(
                        'No websites yet! 📱',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ask your parent to add some',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _websites.length,
                itemBuilder: (context, index) {
                  final website = _websites[index];
                  return _buildWebsiteCard(
                    website['domain'] ?? 'Website',
                    website['description'] ?? '',
                    _getWebsiteIcon(website['domain'] ?? ''),
                    _getWebsiteColor(index),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildWebsiteCard(String domain, String description, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _openWebsite(domain),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            SizedBox(height: 12),
            Text(
              domain.split('.')[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDuaaSection(bool isTablet) {
    final titleSize = isTablet ? 22.0 : 20.0;
    
    final duaas = [
      {
        'title': 'Morning Duaa ☀️',
        'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        'translation': 'We have entered morning and the kingdom belongs to Allah'
      },
      {
        'title': 'Before Eating 🍽️',
        'arabic': 'بِسْمِ اللَّهِ',
        'translation': 'In the name of Allah'
      },
      {
        'title': 'After Eating 🙏',
        'arabic': 'الْحَمْدُ لِلَّهِ',
        'translation': 'Praise be to Allah'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.menu_book, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 8),
              Text(
                'Daily Duaas 📖',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        ...duaas.map((duaa) => Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duaa['title']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    duaa['arabic']!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF059669),
                      height: 1.8,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 8),
                  Text(
                    duaa['translation']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _getWebsiteIcon(String domain) {
    if (domain.contains('youtube')) return Icons.play_circle;
    if (domain.contains('google')) return Icons.search;
    if (domain.contains('wiki')) return Icons.book;
    if (domain.contains('khan')) return Icons.school;
    if (domain.contains('game')) return Icons.games;
    return Icons.public;
  }

  Color _getWebsiteColor(int index) {
    final colors = [
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Green
      Color(0xFFF59E0B), // Orange
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan
    ];
    return colors[index % colors.length];
  }
}
