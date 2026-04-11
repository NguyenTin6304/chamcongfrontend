import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/data/attendance_api.dart';

class HomePageBody extends StatefulWidget {
  const HomePageBody({super.key, this.onNavigate});

  /// Called when this body wants to switch tabs in AppScaffold.
  final ValueChanged<int>? onNavigate;

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

  final _tokenStorage = TokenStorage();
  final _attendanceApi = const AttendanceApi();

  String? _token;
  AttendanceStatusResult? _status;
  Position? _currentPosition;
  bool _isLoadingAction = false;
  bool _isLoadingPage = true;
  List<AttendanceLogItem> _recentLogs = [];
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );
    _loadPageData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> _loadPageData() async {
    if (!mounted) return;
    setState(() => _isLoadingPage = true);

    final token = await _tokenStorage.getToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() => _token = token);

    await Future.wait([
      _loadStatus(token),
      _loadLogs(token),
      _fetchLocation(),
    ]);

    if (mounted) setState(() => _isLoadingPage = false);
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (_) {}
  }

  // ── Action Handlers ───────────────────────────────────────────────────────

  Future<void> _handleCheckin() => _doAction(isCheckin: true);
  Future<void> _handleCheckout() => _doAction(isCheckin: false);

  Future<void> _doAction({required bool isCheckin}) async {
    final token = _token;
    if (token == null) return;

    setState(() => _isLoadingAction = true);
    try {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPosition = position);

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

  List<AttendanceLogItem> get _todayLogs {
    final today = DateTime.now();
    return _recentLogs.where((log) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) return false;
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }).toList();
  }

  List<AttendanceLogItem> get _weekLogs {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _recentLogs.where((log) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) return false;
      return !dt.isBefore(weekStart);
    }).toList();
  }

  Duration get _todayWorkDuration => _computeWorkDuration(_todayLogs);
  Duration get _weekWorkDuration => _computeWorkDuration(_weekLogs);

  Duration _computeWorkDuration(List<AttendanceLogItem> logs) {
    final sorted = [...logs]..sort((a, b) {
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
    final inLogs = _recentLogs
        .where((l) => l.type.toUpperCase() == 'IN')
        .toList()
      ..sort((a, b) {
        final ta = DateTime.tryParse(b.time) ?? DateTime(0);
        final tb = DateTime.tryParse(a.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });
    return inLogs.isEmpty ? null : inLogs.first;
  }

  bool get _isOutOfRange {
    if (_recentLogs.isEmpty) return false;
    final sorted = [..._recentLogs]..sort((a, b) {
      final ta = DateTime.tryParse(b.time) ?? DateTime(0);
      final tb = DateTime.tryParse(a.time) ?? DateTime(0);
      return ta.compareTo(tb);
    });
    return sorted.first.isOutOfRange;
  }

  String? get _geofenceName {
    if (_recentLogs.isEmpty) return null;
    final sorted = [..._recentLogs]..sort((a, b) {
      final ta = DateTime.tryParse(b.time) ?? DateTime(0);
      final tb = DateTime.tryParse(a.time) ?? DateTime(0);
      return ta.compareTo(tb);
    });
    return sorted.first.matchedGeofence;
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
    final inRange = !_isOutOfRange;
    final punctuality = _lastInLog?.punctualityStatus;

    return Center(
      child: Wrap(
        spacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: inRange ? AppColors.border : AppColors.error,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: inRange ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  inRange ? 'Trong phạm vi' : 'Ngoài phạm vi',
                  style: TextStyle(
                    fontSize: 13,
                    color: inRange ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          if (_status?.currentState == 'IN' && punctuality != null)
            _buildPunctualityChip(punctuality),
        ],
      ),
    );
  }

  Widget _buildPunctualityChip(String punctuality) {
    final (Color bg, Color fg, String label) = switch (
      punctuality.toUpperCase()
    ) {
      'EARLY' => (AppColors.overtimeLight, AppColors.overtime, 'Về sớm'),
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
        style: TextStyle(
          fontSize: 13,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

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

    final center = LatLng(position.latitude, position.longitude);
    final geofenceName = _geofenceName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: mapHeight,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
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
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: 8,
                      color: AppColors.primary,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
            if (geofenceName != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        geofenceName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
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
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: onTap != null
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );

    if (context.isDesktop) {
      return Center(
        child: SizedBox(width: 480, child: button),
      );
    }
    return SizedBox(width: double.infinity, child: button);
  }

  // ── Summary Section ───────────────────────────────────────────────────────

  Widget _buildSummarySection() {
    final work = _todayWorkDuration;
    final hours = work.inHours;
    final minutes = work.inMinutes % 60;
    final weekHours = _weekWorkDuration.inMinutes / 60;

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
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GIỜ CÔNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${hours}h ${minutes.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tổng tuần: ${weekHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: AppColors.overtime, width: 3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TĂNG CA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.overtime,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '0.0h',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.overtime,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kỳ lương hiện tại',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Activity Section ──────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    final sorted = [..._recentLogs]..sort((a, b) {
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

