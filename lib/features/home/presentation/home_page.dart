import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/notification_bell.dart';
import '../../attendance/data/attendance_api.dart';
import '../../auth/data/auth_session_service.dart';

class HomePageBody extends StatefulWidget {
  const HomePageBody({super.key, this.onNavigate, this.onAttendanceChanged});

  /// Called when this body wants to switch tabs in AppScaffold.
  final ValueChanged<int>? onNavigate;

  /// Called after a successful check-in or check-out so other tabs can refresh.
  final VoidCallback? onAttendanceChanged;

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  static const _vnWeekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  final _authSession = AuthSessionService();
  final _attendanceApi = const AttendanceApi();
  final MapController _mapController = MapController();

  AttendanceStatusResult? _status;
  Position? _currentPosition;
  List<GeofencePoint> _geofences = [];
  bool _isLoadingAction = false;
  bool _isLoadingPage = true;
  bool _isLocating = false;
  List<AttendanceLogItem> _recentLogs = [];
  Timer? _clockTimer;
  StreamSubscription<Position>? _positionStream;
  DateTime _now = DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    _loadPageData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> _loadPageData() async {
    if (!mounted) return;
    setState(() => _isLoadingPage = true);

    final token = await _resolveToken();
    if (!mounted) return;

    if (token == null) {
      setState(() => _isLoadingPage = false);
      return;
    }

    await Future.wait([
      _loadStatus(token),
      _loadLogs(token),
      _fetchLocation(),
      _loadGeofences(token),
    ]);

    if (mounted) setState(() => _isLoadingPage = false);
  }

  Future<String?> _resolveToken() async {
    try {
      final token = await _authSession.resolveAccessToken();
      if (!mounted) return null;
      if (token == null || token.isEmpty) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return null;
      }
      return token;
    } catch (error) {
      if (!mounted) return null;
      _showSnack('Không thể khôi phục phiên đăng nhập: $error');
      return null;
    }
  }

  Future<void> _loadStatus(String token) async {
    try {
      final status = await _attendanceApi.getStatus(token);
      if (mounted) setState(() => _status = status);
    } catch (_) {}
  }

  Future<void> _loadLogs(String token) async {
    try {
      final logs = await _attendanceApi.getMyLogs(token);
      if (mounted) setState(() => _recentLogs = logs);
    } catch (_) {}
  }

  Future<void> _loadGeofences(String token) async {
    try {
      final geofences = await _attendanceApi.getMyGeofences(token);
      if (mounted) setState(() => _geofences = geofences);
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // First fix: always accept regardless of accuracy so the map is visible.
      // On desktop, this may be a WiFi/IP fix (500–5000 m accuracy) — that's
      // fine as a starting point; the stream will replace it when a better
      // fix arrives.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (mounted) setState(() => _currentPosition = position);

      // Stream updates: only replace the current position when the new fix is
      // genuinely better — i.e. its accuracy is strictly smaller than what we
      // already have. This prevents WiFi-noise jumps on desktop where
      // successive fixes can differ by 1–2 km with no real movement.
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final current = _currentPosition;
        // Reject fix that is worse than or equal to what we already have
        if (current != null && pos.accuracy >= current.accuracy) return;
        setState(() => _currentPosition = pos);
        try {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            _mapController.camera.zoom,
          );
        } catch (_) {}
      });
    } catch (_) {}
  }

  // ── Locate / Refresh GPS ─────────────────────────────────────────────────

  Future<void> _refreshLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Dịch vụ GPS đang tắt.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Chưa cấp quyền vị trí.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      try {
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          _mapController.camera.zoom,
        );
      } catch (_) {}

      // Restart stream in case it was never started (e.g. GPS was disabled on
      // initial load and the user just enabled it before pressing refresh).
      _positionStream ??= Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((streamPos) {
          if (!mounted) return;
          final current = _currentPosition;
          if (current != null && streamPos.accuracy >= current.accuracy) return;
          setState(() => _currentPosition = streamPos);
          try {
            _mapController.move(
              LatLng(streamPos.latitude, streamPos.longitude),
              _mapController.camera.zoom,
            );
          } catch (_) {}
        });
    } catch (e) {
      if (mounted) _showSnack('Không thể lấy vị trí: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Action Handlers ───────────────────────────────────────────────────────

  Future<void> _handleCheckin() => _doAction(isCheckin: true);
  Future<void> _handleCheckout() => _doAction(isCheckin: false);

  Future<void> _doAction({required bool isCheckin}) async {
    // Show spinner immediately before any async work
    setState(() => _isLoadingAction = true);
    try {
      final token = await _resolveToken();
      if (token == null) return;

      // Reuse stream-maintained position if available — avoids 1–10s GPS
      // re-acquisition on every checkin. Stream (distanceFilter: 5m) keeps
      // _currentPosition fresh whenever the user moves, so this is safe.
      // Only fall back to a fresh fix when no position has been acquired yet.
      Position position;
      if (_currentPosition != null) {
        position = _currentPosition!;
      } else {
        // First-time: no stream position yet — request one now
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Dịch vụ GPS đang tắt.');

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Chưa cấp quyền vị trí.');
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
        if (mounted) setState(() => _currentPosition = position);
      }

      final result = isCheckin
          ? await _attendanceApi.checkin(
              token: token,
              lat: position.latitude,
              lng: position.longitude,
              accuracyM: position.accuracy > 0 ? position.accuracy : null,
              timestampClient: DateTime.now().toUtc(),
            )
          : await _attendanceApi.checkout(
              token: token,
              lat: position.latitude,
              lng: position.longitude,
              accuracyM: position.accuracy > 0 ? position.accuracy : null,
              timestampClient: DateTime.now().toUtc(),
            );

      _showSnack(result.message);
      widget.onAttendanceChanged?.call();
      if (mounted) await Future.wait([_loadStatus(token), _loadLogs(token)]);
    } on AttendanceActionException catch (e) {
      _showSnack(
        '${isCheckin ? 'Điểm danh vào' : 'Điểm danh ra'} thất bại: ${e.message}',
      );
    } catch (e) {
      _showSnack('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Computed Getters ──────────────────────────────────────────────────────

  /// Canonical work date for a log — uses backend-assigned [workDate] when
  /// available, falls back to local calendar date of [time] for legacy logs.
  DateTime _logWorkDate(AttendanceLogItem log) {
    if (log.workDate != null) return log.workDate!;
    return DateTime.tryParse(log.time)?.toLocal() ?? DateTime(2000);
  }

  AttendanceLogItem? get _latestLog {
    if (_recentLogs.isEmpty) return null;
    final sorted = [..._recentLogs]
      ..sort((a, b) {
        final ta = DateTime.tryParse(b.time) ?? DateTime(0);
        final tb = DateTime.tryParse(a.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });
    return sorted.first;
  }

  DateTime get _currentWorkDate {
    final state = _status?.currentState.toUpperCase();
    if (state == 'IN') {
      final lastIn = _lastInLog;
      if (lastIn != null) return _logWorkDate(lastIn);
    }
    if (state == 'OUT' && _status?.canCheckin == false) {
      final latest = _latestLog;
      if (latest != null) return _logWorkDate(latest);
    }
    return DateTime.now();
  }

  bool get _employeeNotAssigned => _status?.employeeAssigned == false;

  bool get _isEmployeeInactive =>
      _status?.currentState.toUpperCase() == 'INACTIVE';

  List<AttendanceLogItem> get _todayLogs {
    final today = _currentWorkDate;
    return _recentLogs.where((log) {
      final wd = _logWorkDate(log);
      return wd.year == today.year &&
          wd.month == today.month &&
          wd.day == today.day;
    }).toList();
  }

  List<AttendanceLogItem> get _weekLogs {
    final workDate = _currentWorkDate;
    final weekStart = DateTime(
      workDate.year,
      workDate.month,
      workDate.day - (workDate.weekday - 1),
    );
    return _recentLogs.where((log) {
      final wd = _logWorkDate(log);
      return !wd.isBefore(weekStart);
    }).toList();
  }

  Duration get _todayWorkDuration => _computeWorkDuration(_todayLogs);
  Duration get _weekWorkDuration => _computeWorkDuration(_weekLogs);

  Duration _computeWorkDuration(List<AttendanceLogItem> logs) {
    final sorted = [...logs]
      ..sort((a, b) {
        final ta = DateTime.tryParse(a.time) ?? DateTime(0);
        final tb = DateTime.tryParse(b.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });

    var total = Duration.zero;
    DateTime? inTime;

    for (final log in sorted) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) continue;
      if (log.type.toUpperCase() == 'IN') {
        inTime = dt;
      } else if (log.type.toUpperCase() == 'OUT' && inTime != null) {
        final delta = dt.difference(inTime);
        if (!delta.isNegative) total += delta;
        inTime = null;
      }
    }

    if (inTime != null && _status?.currentState == 'IN') {
      final delta = DateTime.now().difference(inTime);
      if (!delta.isNegative) total += delta;
    }

    return total;
  }

  AttendanceLogItem? get _lastInLog {
    final inLogs =
        _recentLogs.where((l) => l.type.toUpperCase() == 'IN').toList()
          ..sort((a, b) {
            final ta = DateTime.tryParse(b.time) ?? DateTime(0);
            final tb = DateTime.tryParse(a.time) ?? DateTime(0);
            return ta.compareTo(tb);
          });
    return inLogs.isEmpty ? null : inLogs.first;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final padding = context.pagePadding;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(isDesktop),
          Expanded(
            child: _isLoadingPage
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadPageData,
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      children: [
                        const SizedBox(height: 20),
                        _buildGpsChip(),
                        if (_isEmployeeInactive) ...[
                          const SizedBox(height: 12),
                          _buildEmployeeInactiveNotice(),
                        ] else if (_employeeNotAssigned) ...[
                          const SizedBox(height: 12),
                          _buildEmployeePendingNotice(),
                        ],
                        const SizedBox(height: 16),
                        _buildClock(context),
                        const SizedBox(height: 4),
                        _buildDateText(),
                        const SizedBox(height: 16),
                        _buildStatusChips(),
                        const SizedBox(height: 16),
                        _buildMap(context),
                        const SizedBox(height: 20),
                        _buildCtaButton(context),
                        const SizedBox(height: 24),
                        _buildSummarySection(),
                        const SizedBox(height: 24),
                        _buildActivitySection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDesktop) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.location_pin, color: AppColors.primary, size: 20),
          const SizedBox(width: 4),
          const Text(
            'Chấm Công',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const NotificationBell(iconColor: AppColors.primary),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => widget.onNavigate?.call(2),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── GPS Chip ──────────────────────────────────────────────────────────────

  Widget _buildGpsChip() {
    final hasGps = _currentPosition != null;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: hasGps ? AppColors.successLight : AppColors.warningLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hasGps ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              hasGps ? 'GPS đang hoạt động' : 'GPS không hoạt động',
              style: TextStyle(
                color: hasGps ? AppColors.success : AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInactiveNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.block, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tài khoản bị vô hiệu hoá',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Admin đã vô hiệu hoá tài khoản nhân viên của bạn. Vui lòng liên hệ quản trị viên để được hỗ trợ.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeePendingNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa được gán nhân viên',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tài khoản của bạn chưa được admin gán nhân viên. Bạn chưa thể chấm công cho đến khi được duyệt.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Clock ─────────────────────────────────────────────────────────────────

  Widget _buildClock(BuildContext context) {
    return Center(
      child: Text(
        DateFormat('HH:mm').format(_now),
        style: TextStyle(
          fontSize: context.clockSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDateText() {
    final weekday = _vnWeekdays[_now.weekday - 1];
    return Center(
      child: Text(
        '$weekday, ngày ${_now.day} tháng ${_now.month}',
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }

  // ── Status Chips ──────────────────────────────────────────────────────────

  Widget _buildStatusChips() {
    final punctuality = _lastInLog?.punctualityStatus;

    if (_status?.currentState != 'IN' || punctuality == null) {
      return const SizedBox.shrink();
    }

    return Center(child: _buildPunctualityChip(punctuality));
  }

  Widget _buildPunctualityChip(String punctuality) {
    final (Color bg, Color fg, String label) = switch (punctuality
        .toUpperCase()) {
      'EARLY' => (AppColors.successLight, AppColors.success, 'Vào sớm'),
      'LATE' => (AppColors.warningLight, AppColors.warning, 'Vào muộn'),
      _ => (AppColors.successLight, AppColors.success, 'Đúng giờ'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  /// Whether the user's current GPS position is inside ANY active geofence.
  bool get _isInsideGeofence {
    final pos = _currentPosition;
    if (pos == null || _geofences.isEmpty) return false;
    for (final g in _geofences) {
      final dist = const Distance().as(
        LengthUnit.Meter,
        LatLng(pos.latitude, pos.longitude),
        LatLng(g.latitude, g.longitude),
      );
      if (dist <= g.radiusM) return true;
    }
    return false;
  }

  Widget _buildMap(BuildContext context) {
    final mapHeight = context.isDesktop ? 260.0 : 200.0;
    final position = _currentPosition;

    if (position == null) {
      return Container(
        height: mapHeight,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.map_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // Map always centers on user's current GPS position
    final userPos = LatLng(position.latitude, position.longitude);
    final inside = _isInsideGeofence;

    // GPS accuracy circle — translucent, shows fix quality
    final accuracy = position.accuracy;
    final accuracyCircles = <CircleMarker>[
      if (accuracy > 0 && accuracy < 500)
        CircleMarker(
          point: userPos,
          radius: accuracy,
          useRadiusInMeter: true,
          color: AppColors.primary.withValues(alpha: 0.12),
          borderColor: AppColors.primary.withValues(alpha: 0.35),
          borderStrokeWidth: 1.0,
        ),
    ];

    final latStr = position.latitude.toStringAsFixed(6);
    final lngStr = position.longitude.toStringAsFixed(6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: mapHeight,
        child: Stack(
          children: [
            FlutterMap(
              // Stable key — MapController handles all position movements
              key: const ValueKey('user-map'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPos,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://maps.geoapify.com/v1/tile/${AppConfig.geoapifyMapStyle}/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}',
                  userAgentPackageName: 'com.example.birdle',
                ),
                // Accuracy halo (drawn first so it's behind everything)
                if (accuracyCircles.isNotEmpty)
                  CircleLayer(circles: accuracyCircles),
                // Blue dot marker — Google Maps style
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userPos,
                      width: 15,
                      height: 15,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.40),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Top-left: inside/outside status
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _geofences.isEmpty
                            ? AppColors.primary
                            : (inside ? AppColors.success : AppColors.error),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _geofences.isEmpty
                          ? 'GPS hiện tại'
                          : (inside ? 'Trong phạm vi' : 'Ngoài phạm vi'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _geofences.isEmpty
                            ? AppColors.textPrimary
                            : (inside ? AppColors.success : AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top-right: lat / lng + accuracy quality
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.10),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lat: $latStr',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Lng: $lngStr',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (accuracy > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '±${accuracy < 10 ? accuracy.toStringAsFixed(1) : accuracy.toStringAsFixed(0)}m',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accuracy <= 20
                              ? AppColors.success
                              : accuracy <= 100
                                  ? AppColors.warning
                                  : AppColors.error,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom-left: geofence name
            if (_geofences.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pin_drop_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _geofences.length == 1
                            ? _geofences.first.name
                            : '${_geofences.length} khu vực',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom-right: locate / refresh GPS button (Google Maps style)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _isLocating ? null : _refreshLocation,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          accuracy > 0 && accuracy <= 100
                              ? Icons.my_location
                              : Icons.location_searching,
                          size: 18,
                          color: accuracy <= 0
                              ? AppColors.textSecondary
                              : accuracy <= 100
                                  ? AppColors.primary
                                  : AppColors.warning,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CTA Button ────────────────────────────────────────────────────────────

  Widget _buildCtaButton(BuildContext context) {
    final canCheckin = _status?.canCheckin ?? false;
    final canCheckout = _status?.canCheckout ?? false;

    final Color bgColor;
    final String label;
    final VoidCallback? onTap;

    if (_isLoadingAction) {
      bgColor = canCheckout ? AppColors.error : AppColors.primary;
      label = '';
      onTap = null;
    } else if (_isEmployeeInactive) {
      bgColor = AppColors.errorLight;
      label = 'Tài khoản bị vô hiệu hoá';
      onTap = null;
    } else if (_employeeNotAssigned) {
      bgColor = AppColors.border;
      label = 'Chưa được gán nhân viên';
      onTap = null;
    } else if (canCheckin) {
      bgColor = AppColors.primary;
      label = 'Điểm danh vào →';
      onTap = _handleCheckin;
    } else if (canCheckout) {
      bgColor = AppColors.success;
      label = 'Điểm danh ra →';
      onTap = _handleCheckout;
    } else {
      bgColor = AppColors.border;
      label = 'Điểm danh vào →';
      onTap = null;
    }

    final button = SizedBox(
      height: 56,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: _isLoadingAction
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.surface,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: _isEmployeeInactive
                          ? AppColors.error
                          : (onTap != null
                                ? AppColors.surface
                                : AppColors.textSecondary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );

    if (context.isDesktop) {
      return Center(child: SizedBox(width: 480, child: button));
    }
    return SizedBox(width: double.infinity, child: button);
  }

  // ── Summary Section ───────────────────────────────────────────────────────

  Widget _buildSummarySection() {
    final todayWork = _todayWorkDuration;
    final todayH = todayWork.inHours;
    final todayM = todayWork.inMinutes % 60;
    final weekWork = _weekWorkDuration;
    final weekH = weekWork.inHours;
    final weekM = weekWork.inMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tổng hợp hôm nay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => widget.onNavigate?.call(1),
              child: const Text(
                'Xem nhật ký',
                style: TextStyle(fontSize: 14, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                label: 'GIỜ CÔNG HÔM NAY',
                value: '${todayH}h ${todayM.toString().padLeft(2, '0')}',
                accentColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'GIỜ CÔNG TUẦN',
                value: '${weekH}h ${weekM.toString().padLeft(2, '0')}',
                accentColor: AppColors.overtime,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity Section ──────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    final sorted = [..._recentLogs]
      ..sort((a, b) {
        final ta = DateTime.tryParse(b.time) ?? DateTime(0);
        final tb = DateTime.tryParse(a.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });
    final recent = sorted.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    final firstDt = DateTime.tryParse(recent.first.time)?.toLocal();
    final dateLabel = firstDt == null
        ? ''
        : '${_vnWeekdays[firstDt.weekday - 1]}, ${firstDt.day} tháng ${firstDt.month}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SỰ KIỆN GẦN NHẤT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recent.map(_buildActivityItem),
      ],
    );
  }

  Widget _buildActivityItem(AttendanceLogItem log) {
    final isIn = log.type.toUpperCase() == 'IN';
    final dt = DateTime.tryParse(log.time)?.toLocal();
    final timeStr = dt == null ? '--:--' : DateFormat('HH:mm').format(dt);
    final amPm = dt == null ? '' : (dt.hour < 12 ? 'SA' : 'CH');
    final isSuccess = !log.isOutOfRange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIn ? AppColors.primaryLight : AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIn ? Icons.login : Icons.logout,
              size: 20,
              color: isIn ? AppColors.primary : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIn ? 'Đã điểm danh vào' : 'Đã điểm danh ra',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.matchedGeofence ??
                      (isIn ? 'Bắt đầu ca làm' : 'Kết thúc ca làm'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$timeStr $amPm',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSuccess ? 'THÀNH CÔNG' : 'NGOÀI PHẠM VI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSuccess ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
