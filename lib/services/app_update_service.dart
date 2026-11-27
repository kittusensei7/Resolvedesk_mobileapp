import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class AppUpdateService {
  // Current app version built into this release
  static const int currentVersionCode = 14;
  static const String currentVersionName = '3.9';

  static Future<void> checkAndShowUpdateDialog(
    BuildContext context, {
    bool forceShow = false,
  }) async {
    try {
      final dio = await ApiConfig.getDio();
      final response = await dio.get('app-version');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final serverVersionCode = data['versionCode'] as int? ?? 1;
        final serverVersionName = data['versionName'] as String? ?? '1.0.0';
        final downloadUrl =
            data['downloadUrl'] as String? ??
            '${ApiConfig.defaultBaseUrl}/download-apk';
        final forceUpdate = data['forceUpdate'] as bool? ?? false;
        final releaseNotes =
            data['releaseNotes'] as String? ??
            'New performance & security updates available.';

        if (serverVersionCode > currentVersionCode || forceShow) {
          if (!context.mounted) return;
          _showUpdateDialog(
            context,
            serverVersionName: serverVersionName,
            downloadUrl: downloadUrl,
            forceUpdate: forceShow ? false : forceUpdate,
            releaseNotes: releaseNotes,
            isLatest: serverVersionCode <= currentVersionCode,
          );
        }
      }
    } catch (e) {
      debugPrint('App update check error: $e');
      if (forceShow && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to connect to update server. Please check your internet connection.',
            ),
          ),
        );
      }
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String serverVersionName,
    required String downloadUrl,
    required bool forceUpdate,
    required String releaseNotes,
    bool isLatest = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        canPop: !forceUpdate,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Rocket Icon Badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff1d4ed8), Color(0xff3b82f6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x403b82f6),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Version Badge
                Text(
                  isLatest ? 'App Up to Date ✅' : 'Update Available! 🚀',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffeff6ff),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xffbfdbfe)),
                  ),
                  child: Text(
                    'Version $serverVersionName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1d4ed8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Explanation
                Text(
                  isLatest
                      ? 'You are running the latest version of Paradesk. Click below to re-download the APK installer if needed.'
                      : 'A new version of Paradesk is ready to install on your device.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xff475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // What's New Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 16,
                            color: Color(0xff2563eb),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'What\'s New in Version $serverVersionName:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1e293b),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        releaseNotes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff64748b),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    if (!forceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xffcbd5e1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Later',
                            style: TextStyle(
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff16a34a),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          final uri = Uri.parse(downloadUrl);
                          try {
                            bool launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.platformDefault,
                              );
                            }
                          } catch (e) {
                            debugPrint('Failed to launch URL: $e');
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
