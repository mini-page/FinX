import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() => _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> with WidgetsBindingObserver {
  bool _smsGranted = false;
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final sms = await Permission.sms.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;
    final notification = await Permission.notification.isGranted;
    final camera = await Permission.camera.isGranted;

    if (mounted) {
      setState(() {
        _smsGranted = sms;
        _locationGranted = location;
        _notificationGranted = notification;
        _cameraGranted = camera;
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission(Permission permission, String name) async {
    final status = await permission.status;
    if (status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name permission is already granted.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await permission.request();
    if (result.isGranted) {
      _checkPermissions();
      return;
    }

    if (result.isPermanentlyDenied) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('$name Permission Required'),
          content: Text(
            'This permission was permanently denied. Please open device settings to enable it manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      _checkPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'System Permissions',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Informative Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security_rounded, size: 28, color: AppColors.primaryBlue),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage App Access',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'XPens requires system accesses to automate transaction imports, geolocation mapping, and QR scanners.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'SYSTEM PERMISSIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Permissions Card Grid / List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildPermissionTile(
                          icon: Icons.sms_rounded,
                          title: 'SMS Alerts Reader',
                          description: 'Read transaction messages to auto-import expense slips.',
                          isGranted: _smsGranted,
                          onTap: () => _requestPermission(Permission.sms, 'SMS'),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _buildPermissionTile(
                          icon: Icons.location_on_rounded,
                          title: 'GPS Location Access',
                          description: 'Attach exact location coordinates to transaction entries.',
                          isGranted: _locationGranted,
                          onTap: () => _requestPermission(Permission.locationWhenInUse, 'Location'),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _buildPermissionTile(
                          icon: Icons.notifications_active_rounded,
                          title: 'System Notifications',
                          description: 'Send budget overruns alerts, auto-logs alerts and reminders.',
                          isGranted: _notificationGranted,
                          onTap: () => _requestPermission(Permission.notification, 'Notification'),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _buildPermissionTile(
                          icon: Icons.camera_alt_rounded,
                          title: 'Camera Access',
                          description: 'Required by scanners to import bills and parse UPI QRs.',
                          isGranted: _cameraGranted,
                          onTap: () => _requestPermission(Permission.camera, 'Camera'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // System shortcut button
                  ElevatedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Open System App Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppColors.textDark,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final statusColor = isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusBg = isGranted ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final statusText = isGranted ? 'Granted' : 'Denied';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: statusColor,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          description,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3),
        ),
      ),
      onTap: onTap,
    );
  }
}
