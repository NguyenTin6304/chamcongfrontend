import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/token_storage.dart';
import '../../attendance/data/attendance_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.email,
    super.key,
  });

  final String email;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _vnOffset = Duration(hours: 7);

  final _tokenStorage = TokenStorage();
  final _attendanceApi = const AttendanceApi();
  final _vnDateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final _scrollController = ScrollController();

  String? _token;
  Position? _position;
  DateTime? _positionAt;

  bool _loadingLocation = false;
  bool _loadingStatus = false;
  bool _loadingAction = false;
  bool _loadingHistory = false;

  String? _activeAction;

  AttendanceStatusResult? _status;
  AttendanceActionResult? _lastAction;
  List<AttendanceLogItem> _history = const [];

  bool get _isAnyLoading =>
      _loadingStatus || _loadingHistory || _loadingLocation || _loadingAction;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      _showSnack('Chưa có token. Hãy đăng nhập lại.');
      return;
    }

    setState(() {
      _token = token;
    });

    await _refreshAll(fetchLocation: true, showSnack: false);
  }

  Future<void> _refreshAll({required bool fetchLocation, bool showSnack = true}) async {
    await _refreshStatus(showSnack: showSnack);
    await _refreshHistory(showSnack: showSnack);
    if (fetchLocation) {
      await _fetchCurrentLocation(showSnack: showSnack);
    }
  }

  Future<void> _refreshStatus({bool showSnack = true}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingStatus = true;
    });

    try {
      final status = await _attendanceApi.getStatus(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
    } catch (error) {
      if (showSnack) {
        _showSnack('Lấy trạng thái thất bại: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStatus = false;
        });
      }
    }
  }

  Future<void> _refreshHistory({bool showSnack = true}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingHistory = true;
    });

    try {
      final logs = await _attendanceApi.getMyLogs(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _history = logs;
      });
    } catch (error) {
      if (showSnack) {
        _showSnack('Lấy lịch sử thất bại: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
        });
      }
    }
  }

  Future<Position?> _fetchCurrentLocation({bool showSnack = true}) async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ vị trí đang tắt. Hãy bật GPS.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Bạn chưa cấp quyền vị trí.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền vị trí đã bị từ chối vĩnh viễn.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) {
        return position;
      }

      setState(() {
        _position = position;
        _positionAt = DateTime.now();
      });

      return position;
    } catch (error) {
      if (showSnack) {
        _showSnack('Lấy GPS thất bại: $error');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _checkin() async {
    await _doAttendanceAction(isCheckin: true);
  }

  Future<void> _checkout() async {
    await _doAttendanceAction(isCheckin: false);
  }

  Future<void> _doAttendanceAction({required bool isCheckin}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Thiếu token đăng nhập.');
      return;
    }

    setState(() {
      _loadingAction = true;
      _activeAction = isCheckin ? 'IN' : 'OUT';
    });

    try {
      final position = await _fetchCurrentLocation(showSnack: true);
      if (position == null) {
        return;
      }

      final result = isCheckin
          ? await _attendanceApi.checkin(token: token, lat: position.latitude, lng: position.longitude)
          : await _attendanceApi.checkout(
              token: token,
              lat: position.latitude,
              lng: position.longitude,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastAction = result;
      });

      _showSnack(result.message);
      await _refreshStatus(showSnack: false);
      await _refreshHistory(showSnack: false);
    } catch (error) {
      _showSnack('${isCheckin ? 'Check-in' : 'Check-out'} thất bại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = false;
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _tokenStorage.clearToken();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  DateTime? _parseToVn(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return null;
    }
    return dt.toUtc().add(_vnOffset);
  }

  String _formatDateTimeVn(String raw) {
    final dt = _parseToVn(raw);
    if (dt == null) {
      return raw.isEmpty ? '-' : raw;
    }
    return '${_vnDateFormat.format(dt)} (VN)';
  }

  String _formatLocalAsVn(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final vn = value.toUtc().add(_vnOffset);
    return '${_vnDateFormat.format(vn)} (VN)';
  }

  String _distanceText(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(1)} m';
  }

  String _geofenceSourceLabel(String? source) {
    switch (source) {
      case 'GROUP':
        return 'Theo group/geofence';
      case 'SYSTEM_FALLBACK':
        return 'Fallback system rule';
      default:
        return '-';
    }
  }

  String _fallbackReasonLabel(String? reason) {
    switch (reason) {
      case 'EMPLOYEE_NOT_ASSIGNED_GROUP':
        return 'Employee chưa gán group';
      case 'GROUP_INACTIVE_OR_NOT_FOUND':
        return 'Group bị tắt hoặc không tồn tại';
      case 'NO_ACTIVE_GEOFENCE_IN_GROUP':
        return 'Group không có geofence active';
      default:
        return reason ?? '-';
    }
  }

  Color _stateColor(String? state) {
    switch (state) {
      case 'IN':
        return Colors.green;
      case 'OUT':
        return Colors.orange;
      case 'UNASSIGNED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _stateLabel(String? state) {
    switch (state) {
      case 'IN':
        return 'Đang IN';
      case 'OUT':
        return 'Đang OUT';
      case 'UNASSIGNED':
        return 'Chưa gán nhân viên';
      default:
        return 'Chưa xác định';
    }
  }

  Widget _buildStatusBadge(String? state) {
    final color = _stateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _stateLabel(state),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRangeBadge(bool isOutOfRange) {
    final color = isOutOfRange ? Colors.red : Colors.green;
    final label = isOutOfRange ? 'Ngoài vùng' : 'Trong vùng';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCheckin = _status?.canCheckin ?? false;
    final canCheckout = _status?.canCheckout ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Demo'),
        actions: [
          IconButton(
            onPressed: (_loadingStatus || _loadingHistory) ? null : () => _refreshAll(fetchLocation: false),
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refreshAll(fetchLocation: true, showSnack: false),
            notificationPredicate: (_) => !kIsWeb,
            child: ListView(
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Xin chào, ${widget.email}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Trạng thái chấm công',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            _buildStatusBadge(_status?.currentState),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Message: ${_status?.message ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('Lần gần nhất: ${_status?.lastAction ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('Thời gian: ${_formatDateTimeVn(_status?.lastActionTime ?? '')}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Vị trí hiện tại',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _loadingLocation ? null : _fetchCurrentLocation,
                              icon: _loadingLocation
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location),
                              label: const Text('Lấy GPS'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Latitude: ${_position?.latitude.toStringAsFixed(6) ?? '-'}'),
                        Text('Longitude: ${_position?.longitude.toStringAsFixed(6) ?? '-'}'),
                        Text('Độ chính xác: ${_distanceText(_position?.accuracy)}'),
                        Text('Cập nhật: ${_formatLocalAsVn(_positionAt)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_loadingAction || !canCheckin) ? null : _checkin,
                        icon: _loadingAction && _activeAction == 'IN'
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Check-in'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: (_loadingAction || !canCheckout) ? null : _checkout,
                        icon: _loadingAction && _activeAction == 'OUT'
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('Check-out'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kết quả API gần nhất',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('Type: ${_lastAction?.type ?? '-'}'),
                        Text('Time: ${_formatDateTimeVn(_lastAction?.time ?? '')}'),
                        Text('Nearest distance: ${_distanceText(_lastAction?.nearestDistanceM ?? _lastAction?.distanceM)}'),
                        Text('Geofence match: ${_lastAction?.matchedGeofence ?? '-'}'),
                        Text('Nguồn geofence: ${_geofenceSourceLabel(_lastAction?.geofenceSource)}'),
                        if ((_lastAction?.fallbackReason ?? '').isNotEmpty)
                          Text('Lý do fallback: ${_fallbackReasonLabel(_lastAction?.fallbackReason)}'),
                        Text('Giờ vào: ${_lastAction?.punctualityStatus ?? '-'}'),
                        Text('Giờ về: ${_lastAction?.checkoutStatus ?? '-'}'),
                        const SizedBox(height: 6),
                        _buildRangeBadge(_lastAction?.isOutOfRange ?? false),
                        const SizedBox(height: 6),
                        Text('Message: ${_lastAction?.message ?? '-'}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lịch sử chấm công',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingHistory ? null : () => _refreshHistory(showSnack: true),
                      child: const Text('Tải lại'),
                    ),
                  ],
                ),
                if (_history.isEmpty && !_loadingHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Chưa có dữ liệu lịch sử.'),
                  ),
                ..._history.map(
                  (log) {
                    final tone = log.isOutOfRange ? Colors.red : Colors.green;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tone.withValues(alpha: 0.25)),
                        color: tone.withValues(alpha: 0.03),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tone.withValues(alpha: 0.15),
                          child: Text(
                            log.type,
                            style: TextStyle(color: tone, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(_formatDateTimeVn(log.time)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Nearest distance: ${_distanceText(log.nearestDistanceM ?? log.distanceM)}'),
                            if (log.matchedGeofence != null && log.matchedGeofence!.isNotEmpty)
                              Text('Geofence match: ${log.matchedGeofence}'),
                            Text('Nguồn geofence: ${_geofenceSourceLabel(log.geofenceSource)}'),
                            if ((log.fallbackReason ?? '').isNotEmpty)
                              Text('Lý do fallback: ${_fallbackReasonLabel(log.fallbackReason)}'),
                            if (log.punctualityStatus != null)
                              Text('Giờ vào: ${log.punctualityStatus}'),
                            if (log.checkoutStatus != null)
                              Text('Giờ về: ${log.checkoutStatus}'),
                            const SizedBox(height: 4),
                            _buildRangeBadge(log.isOutOfRange),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('lat ${log.lat.toStringAsFixed(5)}'),
                            Text('lng ${log.lng.toStringAsFixed(5)}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_isAnyLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}














