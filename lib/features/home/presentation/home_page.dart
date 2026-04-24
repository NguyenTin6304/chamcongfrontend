import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:birdle/core/layout/responsive.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/utils/vn_date_utils.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';
import 'package:birdle/features/auth/data/auth_session_service.dart';
import 'package:birdle/features/home/presentation/widgets/activity_section.dart';
import 'package:birdle/features/home/presentation/widgets/cta_button.dart';
import 'package:birdle/features/home/presentation/widgets/gps_status_chip.dart';
import 'package:birdle/features/home/presentation/widgets/home_header.dart';
import 'package:birdle/features/home/presentation/widgets/map_panel.dart';
import 'package:birdle/features/home/presentation/widgets/summary_section.dart';

class HomePageBody extends StatefulWidget {
  const HomePageBody({super.key, this.onNavigate, this.onAttendanceChanged});

  final ValueChanged<int>? onNavigate;
  final VoidCallback? onAttendanceChanged;

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {

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
  late final ValueNotifier<DateTime> _nowNotifier;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nowNotifier = ValueNotifier(DateTime.now());
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _nowNotifier.value = DateTime.now(),
    );
    _loadPageData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _positionStream?.cancel();
    _nowNotifier.dispose();
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
        unawaited(Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false));
        return null;
      }
      return token;
    } on Exception catch (e) {
      if (!mounted) return null;
      _showSnack('Không thể khôi phục phiên đăng nhập: $e');
      return null;
    }
  }

  Future<void> _loadStatus(String token) async {
    try {
      final status = await _attendanceApi.getStatus(token);
      if (mounted) setState(() => _status = status);
    } on Exception catch (e) {
      dev.log('_loadStatus: $e', name: 'HomePageBody');
    }
  }

  Future<void> _loadLogs(String token) async {
    try {
      final logs = await _attendanceApi.getMyLogs(token);
      if (mounted) setState(() => _recentLogs = logs);
    } on Exception catch (e) {
      dev.log('_loadLogs: $e', name: 'HomePageBody');
    }
  }

  Future<void> _loadGeofences(String token) async {
    try {
      final geofences = await _attendanceApi.getMyGeofences(token);
      if (mounted) setState(() => _geofences = geofences);
    } on Exception catch (e) {
      dev.log('_loadGeofences: $e', name: 'HomePageBody');
    }
  }

  /// Returns true if GPS service is on and permission is granted.
  /// Optionally shows a snack on failure.
  Future<bool> _hasGpsAccess({bool showSnackOnFailure = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showSnackOnFailure) _showSnack('Dịch vụ GPS đang tắt.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (showSnackOnFailure) _showSnack('Chưa cấp quyền vị trí.');
      return false;
    }
    return true;
  }

  Future<void> _fetchLocation() async {
    try {
      if (!await _hasGpsAccess()) return;

      // First fix: always accept regardless of accuracy so the map shows immediately.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (mounted) setState(() => _currentPosition = position);

      // Stream: only replace when new fix is strictly better (prevents WiFi-noise jumps).
      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final current = _currentPosition;
        if (current != null && pos.accuracy >= current.accuracy) return;
        setState(() => _currentPosition = pos);
        try {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            _mapController.camera.zoom,
          );
        } on Exception catch (_) {}
      });
    } on Exception catch (_) {}
  }

  // ── GPS Refresh ───────────────────────────────────────────────────────────

  Future<void> _refreshLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      if (!await _hasGpsAccess(showSnackOnFailure: true)) return;
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
      } on Exception catch (_) {}

      // Restart stream if it was never started (e.g. GPS disabled on initial load).
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
        } on Exception catch (_) {}
      });
    } on Exception catch (e) {
      if (mounted) _showSnack('Không thể lấy vị trí: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Action Handlers ───────────────────────────────────────────────────────

  Future<void> _handleCheckin() => _doAction(isCheckin: true);
  Future<void> _handleCheckout() => _doAction(isCheckin: false);

  Future<void> _doAction({required bool isCheckin}) async {
    setState(() => _isLoadingAction = true);
    try {
      final token = await _resolveToken();
      if (token == null) return;

      Position position;
      if (_currentPosition != null) {
        position = _currentPosition!;
      } else {
        if (!await _hasGpsAccess()) {
          throw Exception('GPS không khả dụng hoặc chưa cấp quyền.');
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
    } on Exception catch (e) {
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
    final mapHeight = isDesktop
        ? AppSizes.mapHeightDesktop
        : AppSizes.mapHeightMobile;

    return SafeArea(
      child: Column(
        children: [
          HomeHeader(
            onNavigateToProfile: () => widget.onNavigate?.call(2),
          ),
          Expanded(
            child: _isLoadingPage
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadPageData,
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        GpsStatusChip(hasGps: _currentPosition != null),
                        if (_isEmployeeInactive) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildEmployeeInactiveNotice(),
                        ] else if (_employeeNotAssigned) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildEmployeePendingNotice(),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _nowNotifier,
                          builder: (_, now, _) => Column(
                            children: [
                              Center(
                                child: Text(
                                  DateFormat('HH:mm').format(now),
                                  style: AppTextStyles.clockDisplay.copyWith(
                                    fontSize: context.clockSize,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Center(
                                child: Text(
                                  '${VnDateUtils.weekdays[now.weekday - 1]}, ngày ${now.day} tháng ${now.month}',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildPunctualityChips(),
                        const SizedBox(height: AppSpacing.lg),
                        MapPanel(
                          mapController: _mapController,
                          currentPosition: _currentPosition,
                          geofences: _geofences,
                          isLocating: _isLocating,
                          onRefreshLocation: _refreshLocation,
                          mapHeight: mapHeight,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        CtaButton(
                          status: _status,
                          isLoadingAction: _isLoadingAction,
                          isEmployeeInactive: _isEmployeeInactive,
                          employeeNotAssigned: _employeeNotAssigned,
                          onCheckin: _handleCheckin,
                          onCheckout: _handleCheckout,
                          isDesktop: isDesktop,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        SummarySection(
                          todayWorkDuration: _todayWorkDuration,
                          weekWorkDuration: _weekWorkDuration,
                          onViewHistory: () => widget.onNavigate?.call(1),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        ActivitySection(logs: _recentLogs),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Inline notice widgets (task 1.7) ─────────────────────────────────────

  Widget _buildEmployeeInactiveNotice() {
    return Container(
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.error, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tài khoản bị vô hiệu hoá',
                  style: AppTextStyles.bodyBold.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Admin đã vô hiệu hoá tài khoản nhân viên của bạn. Vui lòng liên hệ quản trị viên để được hỗ trợ.',
                  style: AppTextStyles.bodySmall.copyWith(
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
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa được gán nhân viên',
                  style: AppTextStyles.bodyBold.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tài khoản của bạn chưa được admin gán nhân viên. Bạn chưa thể chấm công cho đến khi được duyệt.',
                  style: AppTextStyles.bodySmall.copyWith(
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

  // ── Clock & date — rebuilt only by ValueNotifier, not full setState ─────

  // ── Punctuality chip ─────────────────────────────────────────────────────

  Widget _buildPunctualityChips() {
    final punctuality = _lastInLog?.punctualityStatus;
    if (_status?.currentState != 'IN' || punctuality == null) {
      return const SizedBox.shrink();
    }

    final (Color bg, Color fg, String label) = switch (
        punctuality.toUpperCase()) {
      'EARLY' => (AppColors.successLight, AppColors.success, 'Vào sớm'),
      'LATE' => (AppColors.warningLight, AppColors.warning, 'Vào muộn'),
      _ => (AppColors.successLight, AppColors.success, 'Đúng giờ'),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.chipAll),
        child: Text(
          label,
          style: AppTextStyles.chipText.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
