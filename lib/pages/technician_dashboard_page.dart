import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/app_update_service.dart';
import '../services/permission_access.dart';
import '../widgets/paradesk_shimmer.dart';
import 'complaint_details_page.dart';
import 'login_page.dart';
import 'service_call_reports_page.dart';
import 'installation_reports_page.dart';
import 'enquiries_page.dart';


class TechnicianDashboardPage extends StatefulWidget {
  const TechnicianDashboardPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<TechnicianDashboardPage> createState() => _TechnicianDashboardPageState();
}

class _TechnicianDashboardPageState extends State<TechnicianDashboardPage> with WidgetsBindingObserver {
  PermissionAccess? _access;
  Timer? _accessTimer;
  bool _refreshingAccess = false;
  static const _features = ['tech_dashboard', 'service_calls', 'installations', 'enquiries'];
  List<int> get _visibleTabs => [for(var i=0;i<_features.length;i++) if(_access?.can(_features[i]) ?? false) i];
  Future<void> _refreshAccess() async {
    if(_refreshingAccess) return;
    _refreshingAccess = true;
    try {
      final access = await PermissionAccess.load();
      if(!mounted) return;
      setState(() {
        _access = access;
        final allowed = _visibleTabs;
        _tabHistory.removeWhere((tab)=>!allowed.contains(tab));
        if(!allowed.contains(_selectedTab)) _selectedTab=allowed.isEmpty?-1:allowed.first;
        if(allowed.isNotEmpty && _tabHistory.isEmpty) _tabHistory.add(_selectedTab);
      });
    } catch (_) {
      if(mounted) setState(()=>_error='Unable to refresh access. Please retry.');
    } finally { _refreshingAccess=false; }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed) _refreshAccess();
  }
  int _selectedTab = 0;
  DateTime? _lastBackPressTime;
  final List<int> _tabHistory = [0];
  Map<String, dynamic>? _summary;
  List<dynamic> _complaints = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _accessTimer = Timer.periodic(const Duration(minutes: 3), (_) => _refreshAccess());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndShowUpdateDialog(context);
    });
  }

  @override
  void dispose() {
    _accessTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _switchTab(int newTab) {
    if(!_visibleTabs.contains(newTab)) return;
    if (_selectedTab == newTab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTab = newTab;
      _tabHistory.remove(newTab);
      _tabHistory.add(newTab);
    });
  }

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    // Only show full skeleton loader on initial cold load
    if (_summary == null && _complaints.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dio = await ApiConfig.getDio();
      
      // Resilient Parallel Execution:
      // Run Dashboard Summary, Complaints Queue, and Permissions concurrently.
      // Isolate failures so slow complaints do not prevent metrics from rendering.
      Future<Response?> safeGet(String path) async {
        try {
          return await dio.get(path);
        } catch (e) {
          debugPrint("⚠️ [Fetch Warning $path]: $e");
          return null;
        }
      }

      Future<PermissionAccess> safeLoadPermissions() async {
        try {
          return await PermissionAccess.load(forceRefresh: forceRefresh);
        } catch (e) {
          debugPrint("⚠️ [Permissions Fetch Warning]: $e");
          return _access ?? const PermissionAccess.empty();
        }
      }

      final results = await Future.wait([
        safeGet('mobile/technician/dashboard'),
        safeGet('mobile/technician/complaints?page=1&pageSize=25'),
        safeLoadPermissions(),
      ]);
      final dashboardResp = results[0] as Response?;
      final complaintsResp = results[1] as Response?;
      final access = results[2] as PermissionAccess;

      if (!mounted) return;
      setState(() {
        _access = access;

        if (dashboardResp?.data is Map) {
          final dashboardData = Map<String, dynamic>.from(dashboardResp!.data as Map);
          if (dashboardData['summary'] is Map) {
            _summary = Map<String, dynamic>.from(dashboardData['summary'] as Map);
          }
        }

        if (complaintsResp?.data is Map) {
          final complaintsData = Map<String, dynamic>.from(complaintsResp!.data as Map);
          if (complaintsData['items'] is List) {
            _complaints = List<dynamic>.from(complaintsData['items'] as List);
            _error = null;
          }
        } else if (_complaints.isEmpty) {
          _error = 'Unable to load service requests. Please tap refresh to retry.';
        }

        final allowed = _visibleTabs;
        _tabHistory.removeWhere((tab) => !allowed.contains(tab));
        if (!allowed.contains(_selectedTab)) _selectedTab = allowed.isEmpty ? -1 : allowed.first;
        if (allowed.isNotEmpty && _tabHistory.isEmpty) _tabHistory.add(_selectedTab);
      });
    } catch (e) {
      debugPrint("❌ [Dashboard Load Exception]: $e");
      if (mounted) setState(() => _error = 'Unable to load technician queue. Tap to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Color(0xffdc2626)),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to sign out from Paradesk?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffdc2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiConfig.clearToken();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openGoogleMaps(String address) async {
    if (address.trim().isEmpty) return;
    final query = Uri.encodeComponent(address.trim());
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final geoUrl = Uri.parse('geo:0,0?q=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _statCard({
    required String label,
    required dynamic value,
    required Color baseColor,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required String statusKey,
    required String sublabel,
    bool isPulse = false,
  }) {
    final isSelected = _statusFilter == statusKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _statusFilter = isSelected ? 'All' : statusKey;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? baseColor : borderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              else
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPulse) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? baseColor : const Color(0xff1e293b),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: baseColor, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${value ?? 0}',
                style: TextStyle(
                  color: baseColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sublabel,
                style: TextStyle(
                  color: isSelected ? baseColor.withValues(alpha: 0.8) : const Color(0xff64748b),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final filtered = _complaints.where((item) {
      final comp = Map<String, dynamic>.from(item as Map);
      final status = comp['status']?.toString().trim() ?? '';
      
      if (_statusFilter != 'All' && status != _statusFilter) {
        return false;
      }

      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;

      final number = comp['complaint_number']?.toString().toLowerCase() ?? '';
      final customer = comp['customer_name']?.toString().toLowerCase() ?? '';
      final company = comp['company_name']?.toString().toLowerCase() ?? '';
      final product = comp['product']?.toString().toLowerCase() ?? '';

      return number.contains(query) || customer.contains(query) || company.contains(query) || product.contains(query);
    }).toList();

    final username = widget.user['username']?.toString() ?? 'Technician';

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(forceRefresh: true),
      child: _loading && _complaints.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerBone(height: 68, borderRadius: 22),
                SizedBox(height: 16),
                DashboardMetricsSkeleton(),
                SizedBox(height: 20),
                ShimmerBone(height: 44, borderRadius: 14),
                SizedBox(height: 14),
                ComplaintCardSkeleton(),
                ComplaintCardSkeleton(),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              children: [
                // Executive Profile & Greeting Header Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff1d4ed8), Color(0xff3b82f6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff2563eb).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                username.isNotEmpty
                                    ? username.substring(0, username.length >= 2 ? 2 : 1).toUpperCase()
                                    : 'KT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xff10b981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Welcome back, $username',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xff0f172a),
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('👋', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Field Service Engineer • Paramount Office Systems',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xff64748b),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _loadDashboard(forceRefresh: true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xff2563eb),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms),

                const SizedBox(height: 14),

                // FULL 6-STATUS UNIQUE METRIC GRID (Apple HIG & Material 3)
                Column(
                  children: [
                    // Row 1: Assigned, Pending, On Hold
                    Row(
                      children: [
                        _statCard(
                          label: 'Assigned',
                          value: _summary?['assigned'],
                          baseColor: const Color(0xff0284c7),
                          bgColor: const Color(0xfff0f9ff),
                          borderColor: const Color(0xffbae6fd),
                          icon: Icons.assignment_rounded,
                          statusKey: 'All',
                          sublabel: 'Total Queue',
                        ),
                        const SizedBox(width: 8),
                        _statCard(
                          label: 'Pending',
                          value: _summary?['pending'],
                          baseColor: const Color(0xffd97706),
                          bgColor: const Color(0xfffffbeb),
                          borderColor: const Color(0xfffde68a),
                          icon: Icons.schedule_rounded,
                          statusKey: 'Pending',
                          sublabel: 'Need Start',
                        ),
                        const SizedBox(width: 8),
                        _statCard(
                          label: 'On Hold',
                          value: _summary?['on_hold'],
                          baseColor: const Color(0xff475569),
                          bgColor: const Color(0xfff8fafc),
                          borderColor: const Color(0xffe2e8f0),
                          icon: Icons.pause_circle_rounded,
                          statusKey: 'On Hold',
                          sublabel: 'SLA Paused',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: Ongoing, Rescheduled, Resolved
                    Row(
                      children: [
                        _statCard(
                          label: 'Ongoing',
                          value: _summary?['ongoing'],
                          baseColor: const Color(0xff1d4ed8),
                          bgColor: const Color(0xffeff6ff),
                          borderColor: const Color(0xffbfdbfe),
                          icon: Icons.sync_rounded,
                          statusKey: 'Ongoing',
                          sublabel: 'Live Repairs',
                          isPulse: true,
                        ),
                        const SizedBox(width: 8),
                        _statCard(
                          label: 'Resched',
                          value: _summary?['rescheduled'],
                          baseColor: const Color(0xffea580c),
                          bgColor: const Color(0xfffff7ed),
                          borderColor: const Color(0xfffed7aa),
                          icon: Icons.event_repeat_rounded,
                          statusKey: 'Rescheduled',
                          sublabel: 'Next Date',
                        ),
                        const SizedBox(width: 8),
                        _statCard(
                          label: 'Resolved',
                          value: _summary?['resolved'],
                          baseColor: const Color(0xff16a34a),
                          bgColor: const Color(0xfff0fdf4),
                          borderColor: const Color(0xffbbf7d0),
                          icon: Icons.check_circle_rounded,
                          statusKey: 'Resolved',
                          sublabel: 'Completed',
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(delay: 80.ms),

                const SizedBox(height: 18),

                // Section Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assigned Service Requests',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Color(0xff0f172a),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Text(
                        '${filtered.length} calls',
                        style: const TextStyle(fontSize: 11, color: Color(0xff475569), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Field with Soft Slate Placeholder (Never Black!)
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search complaint #, customer, company, product...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xff94a3b8), fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xff94a3b8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xff2563eb), width: 1.8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xff94a3b8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'Ongoing', 'On Hold', 'Rescheduled', 'Resolved'].map((st) {
                      final selected = _statusFilter == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(st),
                          selected: selected,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _statusFilter = st);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xff1e3a8a),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : const Color(0xff334155),
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: selected ? const Color(0xff1e3a8a) : const Color(0xffe2e8f0),
                            ),
                          ),
                          checkmarkColor: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                if (_error != null && _complaints.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff1f2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xfffecdd3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xffe11d48)),
                        const SizedBox(height: 10),
                        const Text(
                          'Connection Issue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff9f1239),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xffbe123c), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xffe11d48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: () => _loadDashboard(forceRefresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else if (filtered.isEmpty && !_loading)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined, size: 40, color: Color(0xff94a3b8)),
                        const SizedBox(height: 10),
                        const Text(
                          'No complaints matching criteria',
                          style: TextStyle(color: Color(0xff0f172a), fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try clearing your search keyword or switching the status filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xff64748b), fontSize: 12),
                        ),
                        if (_searchController.text.trim().isNotEmpty || _statusFilter != 'All') ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff1e3a8a),
                              side: const BorderSide(color: Color(0xffbfdbfe)),
                              backgroundColor: const Color(0xffeff6ff),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _searchController.clear();
                              setState(() => _statusFilter = 'All');
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                            label: const Text('Reset Filter & Show All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ...filtered.map((item) {
                    final comp = Map<String, dynamic>.from(item as Map);
                    final status = comp['status']?.toString().trim() ?? 'Pending';
                    final isResolved = status == 'Resolved';
                    final isOngoing = status == 'Ongoing';
                    final isRescheduled = status == 'Rescheduled';
                    final isOnHold = status == 'On Hold';
                    final priority = comp['priority']?.toString() ?? 'Medium';

                    Color priorityBg = const Color(0xffeff6ff);
                    Color priorityColor = const Color(0xff1d4ed8);
                    if (priority == 'High') {
                      priorityBg = const Color(0xfffef2f2);
                      priorityColor = const Color(0xffdc2626);
                    } else if (priority == 'Low') {
                      priorityBg = const Color(0xfff0fdf4);
                      priorityColor = const Color(0xff16a34a);
                    }

                    final rescheduleDateStr = comp['reschedule_date']?.toString() ?? comp['rescheduleDate']?.toString();
                    final rescheduleReasonStr = comp['reschedule_reason']?.toString() ?? comp['rescheduleReason']?.toString();

                    return RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRescheduled
                                ? const Color(0xfffed7aa)
                                : isOnHold
                                    ? const Color(0xfffde68a)
                                    : isOngoing
                                        ? const Color(0xffbfdbfe)
                                        : const Color(0xffe2e8f0),
                            width: isOngoing || isRescheduled ? 1.4 : 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComplaintDetailsPage(complaintId: comp['id'] as int),
                              ),
                            );
                            _loadDashboard();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: ID, Plan badge, Status Chip
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Hero(
                                          tag: 'complaint_number_${comp['id']}',
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Text(
                                              comp['complaint_number']?.toString() ?? '#${comp['id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                letterSpacing: -0.2,
                                                color: Color(0xff0f172a),
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff0f9ff),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xffbae6fd)),
                                        ),
                                        child: Text(
                                          comp['coverage_type']?.toString().toUpperCase() ?? 'AMC',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xff0284c7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Status Pill with HIG color
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: isResolved
                                          ? const Color(0xfff0fdf4)
                                          : isOngoing
                                              ? const Color(0xffeff6ff)
                                              : isOnHold
                                                  ? const Color(0xfff8fafc)
                                                  : isRescheduled
                                                      ? const Color(0xfffff7ed)
                                                      : const Color(0xfffffbeb),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isResolved
                                            ? const Color(0xffbbf7d0)
                                            : isOngoing
                                                ? const Color(0xffbfdbfe)
                                                : isOnHold
                                                    ? const Color(0xffe2e8f0)
                                                    : isRescheduled
                                                        ? const Color(0xfffed7aa)
                                                        : const Color(0xfffde68a),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isOngoing)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(right: 5),
                                            decoration: const BoxDecoration(
                                              color: Color(0xff1d4ed8),
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        else
                                          Icon(
                                            isResolved
                                                ? Icons.check_circle_rounded
                                                : isOnHold
                                                    ? Icons.pause_circle_rounded
                                                    : isRescheduled
                                                        ? Icons.event_repeat_rounded
                                                        : Icons.schedule_rounded,
                                            size: 11,
                                            color: isResolved
                                                ? const Color(0xff15803d)
                                                : isOnHold
                                                    ? const Color(0xff475569)
                                                    : isRescheduled
                                                        ? const Color(0xffc2410c)
                                                        : const Color(0xffb45309),
                                          ),
                                        const SizedBox(width: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: isResolved
                                                ? const Color(0xff15803d)
                                                : isOngoing
                                                    ? const Color(0xff1d4ed8)
                                                    : isOnHold
                                                        ? const Color(0xff475569)
                                                        : isRescheduled
                                                            ? const Color(0xffc2410c)
                                                            : const Color(0xffb45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Customer & Company
                              Text(
                                comp['company_name']?.toString() ?? comp['customer_name']?.toString() ?? 'Customer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                  color: Color(0xff0f172a),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${comp['city'] ?? comp['address'] ?? 'On-Site'} • Attn: ${comp['customer_name'] ?? 'Authorized Contact'}',
                                style: const TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Equipment strip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff8fafc),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xfff1f5f9)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffeff6ff),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.devices_rounded,
                                        color: Color(0xff2563eb),
                                        size: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${comp['product'] ?? 'Equipment'} ${comp['model'] != null && comp['model'].toString().trim().isNotEmpty ? '(${comp['model']})' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff1e293b),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: priorityBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        priority,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: priorityColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Rescheduled banner if any
                              if (isRescheduled && rescheduleDateStr != null && rescheduleDateStr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffff7ed),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xffffedd5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xffc2410c)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Rescheduled: ${rescheduleDateStr.split('T').first}${rescheduleReasonStr != null && rescheduleReasonStr.trim().isNotEmpty ? ' • $rescheduleReasonStr' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xff9a3412)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              // Action Buttons: Call, Maps, Open Details
                              Row(
                                children: [
                                  if (comp['customer_phone'] != null && comp['customer_phone'].toString().trim().isNotEmpty) ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          backgroundColor: const Color(0xfff0fdf4),
                                          side: const BorderSide(color: Color(0xffbbf7d0)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _makePhoneCall(comp['customer_phone'].toString()),
                                        icon: const Icon(Icons.call_rounded, size: 13, color: Color(0xff15803d)),
                                        label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xff15803d))),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        backgroundColor: const Color(0xffeff6ff),
                                        side: const BorderSide(color: Color(0xffbfdbfe)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _openGoogleMaps('${comp['company_name'] ?? ''} ${comp['address'] ?? ''} ${comp['city'] ?? ''}'),
                                      icon: const Icon(Icons.near_me_rounded, size: 13, color: Color(0xff1d4ed8)),
                                      label: const Text('Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xff1d4ed8))),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        backgroundColor: const Color(0xff1e3a8a),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        HapticFeedback.mediumImpact();
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ComplaintDetailsPage(complaintId: comp['id'] as int),
                                          ),
                                        );
                                        _loadDashboard();
                                      },
                                      child: const Text('Open →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
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
                  }),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username']?.toString() ?? 'Technician';
    final visibleTabs = _visibleTabs;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If currently on a sub-tab, smoothly return to the previous tab in history!
        if (_tabHistory.length > 1) {
          setState(() {
            _tabHistory.removeLast();
            _selectedTab = _tabHistory.last;
          });
          return;
        } else if (visibleTabs.isNotEmpty && _selectedTab != visibleTabs.first) {
          setState(() => _selectedTab = visibleTabs.first);
          return;
        }

        // 2. If ALREADY on Home tab, require double-press back to exit (no jarring accidental exits during testing!)
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit Paradesk'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff8fafc),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Row(
            children: const [
              Icon(Icons.support_agent, color: Color(0xff1e3a8a), size: 22),
              SizedBox(width: 8),
              Text(
                'PARADESK',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.0, color: Color(0xff0f172a)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Check App Updates',
              icon: const Icon(Icons.system_update_alt_rounded, color: Color(0xff1e3a8a), size: 22),
              onPressed: () => AppUpdateService.checkAndShowUpdateDialog(context, forceShow: true),
            ),
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout, color: Color(0xffdc2626), size: 20),
              onPressed: _logout,
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                // Executive Header Drawer Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff090d16), Color(0xff0f172a), Color(0xff1e3a8a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                username.isNotEmpty
                                    ? username.substring(0, username.length >= 2 ? 2 : 1).toUpperCase()
                                    : 'KT',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Color(0xff1d4ed8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xff10b981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Paramount Office Systems',
                        style: TextStyle(color: Color(0xff93c5fd), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'ROLE: TECHNICIAN',
                          style: TextStyle(
                            color: Color(0xffbfdbfe),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                if (visibleTabs.contains(0))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: _selectedTab == 0 ? const Color(0xffeff6ff) : Colors.transparent,
                      leading: Icon(
                        _selectedTab == 0 ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                        color: _selectedTab == 0 ? const Color(0xff1d4ed8) : const Color(0xff64748b),
                      ),
                      title: Text(
                        'Home Dashboard',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: _selectedTab == 0 ? const Color(0xff1d4ed8) : const Color(0xff1e293b),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xffeff6ff),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_complaints.length}',
                          style: const TextStyle(color: Color(0xff1d4ed8), fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                      selected: _selectedTab == 0,
                      onTap: () {
                        Navigator.pop(context);
                        _switchTab(0);
                      },
                    ),
                  ),
                if (visibleTabs.contains(1))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: _selectedTab == 1 ? const Color(0xffeff6ff) : Colors.transparent,
                      leading: Icon(
                        _selectedTab == 1 ? Icons.assignment_rounded : Icons.assignment_outlined,
                        color: _selectedTab == 1 ? const Color(0xff1d4ed8) : const Color(0xff64748b),
                      ),
                      title: Text(
                        'Service Call Reports',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: _selectedTab == 1 ? const Color(0xff1d4ed8) : const Color(0xff1e293b),
                        ),
                      ),
                      selected: _selectedTab == 1,
                      onTap: () {
                        Navigator.pop(context);
                        _switchTab(1);
                      },
                    ),
                  ),
                if (visibleTabs.contains(2))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: _selectedTab == 2 ? const Color(0xffeff6ff) : Colors.transparent,
                      leading: Icon(
                        _selectedTab == 2 ? Icons.build_circle_rounded : Icons.build_circle_outlined,
                        color: _selectedTab == 2 ? const Color(0xff1d4ed8) : const Color(0xff64748b),
                      ),
                      title: Text(
                        'Installation Reports',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: _selectedTab == 2 ? const Color(0xff1d4ed8) : const Color(0xff1e293b),
                        ),
                      ),
                      selected: _selectedTab == 2,
                      onTap: () {
                        Navigator.pop(context);
                        _switchTab(2);
                      },
                    ),
                  ),
                if (visibleTabs.contains(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: _selectedTab == 3 ? const Color(0xffeff6ff) : Colors.transparent,
                      leading: Icon(
                        _selectedTab == 3 ? Icons.help_center_rounded : Icons.help_outline_rounded,
                        color: _selectedTab == 3 ? const Color(0xff1d4ed8) : const Color(0xff64748b),
                      ),
                      title: Text(
                        'Customer Enquiries',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: _selectedTab == 3 ? const Color(0xff1d4ed8) : const Color(0xff1e293b),
                        ),
                      ),
                      selected: _selectedTab == 3,
                      onTap: () {
                        Navigator.pop(context);
                        _switchTab(3);
                      },
                    ),
                  ),
                const Spacer(),
                const Divider(color: Color(0xfff1f5f9)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.system_update_rounded, color: Color(0xff2563eb)),
                    title: const Text('Check App Update', style: TextStyle(color: Color(0xff1e293b), fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Version 3.8.0', style: TextStyle(fontSize: 11, color: Color(0xff64748b))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffeff6ff),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('v3.8', style: TextStyle(color: Color(0xff2563eb), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      AppUpdateService.checkAndShowUpdateDialog(context, forceShow: true);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xfffee2e2)),
                    ),
                    tileColor: const Color(0xfffff5f5),
                    leading: const Icon(Icons.logout_rounded, color: Color(0xffdc2626)),
                    title: const Text('Sign Out', style: TextStyle(color: Color(0xffdc2626), fontWeight: FontWeight.w800, fontSize: 13.5)),
                    onTap: _logout,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>('$_selectedTab:${_access?.revision}'),
            child: _access == null ? Center(child: _error==null ? const CircularProgressIndicator() : TextButton(onPressed:_loadDashboard,child:Text(_error!)))
                : visibleTabs.isEmpty ? const Center(child:Text('No mobile sections are enabled. Contact Helpdesk.'))
                : _selectedTab == 0
                ? _buildHomeTab()
                : _selectedTab == 1
                    ? const ServiceCallReportsPage()
                    : _selectedTab == 2
                        ? const InstallationReportsPage()
                        : const EnquiriesPage(),
          ),
        ),
        bottomNavigationBar: visibleTabs.length < 2
            ? null
            : NavigationBar(
                selectedIndex: visibleTabs.indexOf(_selectedTab),
                onDestinationSelected: (idx) => _switchTab(visibleTabs[idx]),
                elevation: 3,
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xffdbeafe),
                destinations: [
                  if (visibleTabs.contains(0))
                    const NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined, color: Color(0xff64748b)),
                      selectedIcon: Icon(Icons.grid_view_rounded, color: Color(0xff1d4ed8)),
                      label: 'Home',
                    ),
                  if (visibleTabs.contains(1))
                    const NavigationDestination(
                      icon: Icon(Icons.assignment_outlined, color: Color(0xff64748b)),
                      selectedIcon: Icon(Icons.assignment_rounded, color: Color(0xff1d4ed8)),
                      label: 'Service Reports',
                    ),
                  if (visibleTabs.contains(2))
                    const NavigationDestination(
                      icon: Icon(Icons.build_circle_outlined, color: Color(0xff64748b)),
                      selectedIcon: Icon(Icons.build_circle_rounded, color: Color(0xff1d4ed8)),
                      label: 'Installations',
                    ),
                  if (visibleTabs.contains(3))
                    const NavigationDestination(
                      icon: Icon(Icons.help_outline_rounded, color: Color(0xff64748b)),
                      selectedIcon: Icon(Icons.help_center_rounded, color: Color(0xff1d4ed8)),
                      label: 'Enquiries',
                    ),
                ],
              ),
      ),
    );
  }
}

