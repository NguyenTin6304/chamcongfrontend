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
  final _vnDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final _vnDateFormat = DateFormat('dd/MM/yyyy');
  final _vnTimeFormat = DateFormat('HH:mm:ss');
  final _dayKeyFormat = DateFormat('yyyy-MM-dd');
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

      final timingNotice = _timingNotice(result);
      _showSnack(
        timingNotice == null ? result.message : '${result.message} | $timingNotice',
      );
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
    return '${_vnDateTimeFormat.format(dt)} (VN)';
  }

  String _formatTimeVn(String raw) {
    final dt = _parseToVn(raw);
    if (dt == null) {
      return '--:--';
    }
    return _vnTimeFormat.format(dt);
  }

  String _formatDateVn(DateTime dt) => _vnDateFormat.format(dt);

  String _formatLocalAsVn(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final vn = value.toUtc().add(_vnOffset);
    return '${_vnDateTimeFormat.format(vn)} (VN)';
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
  String? _timingNotice(AttendanceActionResult result) {
    final type = result.type.toUpperCase();
    if (type == 'IN') {
      final status = (result.punctualityStatus ?? '').toUpperCase();
      if (status.isEmpty) {
        return null;
      }
      return 'Giờ vào: ${_checkinTimingLabel(status)}';
    }

    if (type == 'OUT') {
      final status = (result.checkoutStatus ?? '').toUpperCase();
      if (status.isEmpty) {
        return null;
      }
      return 'Giờ về: ${_checkoutTimingLabel(status)}';
    }

    return null;
  }

  String _checkinTimingLabel(String status) {
    switch (status) {
      case 'EARLY':
        return 'Đi sớm';
      case 'ON_TIME':
        return 'Đúng giờ';
      case 'LATE':
        return 'Đi trễ';
      default:
        return status;
    }
  }

  String _checkoutTimingLabel(String status) {
    switch (status) {
      case 'EARLY':
        return 'Về sớm';
      case 'ON_TIME':
        return 'Về đúng giờ';
      case 'LATE':
        return 'Về trễ';
      default:
        return status;
    }
  }

  Color _stateColor(String? state) {
    switch (state) {
      case 'IN':
        return Colors.green;
      case 'OUT':
        return Colors.blue;
      case 'UNASSIGNED':
        return Colors.orange;
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

  Color _actionColor({required String type, required bool isOutOfRange}) {
    if (isOutOfRange) {
      return Colors.orange;
    }
    return type == 'OUT' ? Colors.blue : Colors.green;
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

  Widget _buildRangeBadge({
    required bool isOutOfRange,
    String? type,
  }) {
    final normalizedType = (type ?? '').toUpperCase();
    final color = isOutOfRange
        ? Colors.orange
        : (normalizedType == 'OUT' ? Colors.blue : Colors.green);
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

  Widget _buildActionChip({
    required String type,
    required bool isOutOfRange,
  }) {
    final color = _actionColor(type: type, isOutOfRange: isOutOfRange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  DateTime _logSortTime(AttendanceLogItem log) {
    return _parseToVn(log.time) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _pairSortTime(_AttendancePair pair) {
    final outTime = pair.outLog != null ? _parseToVn(pair.outLog!.time) : null;
    if (outTime != null) {
      return outTime;
    }
    final inTime = pair.inLog != null ? _parseToVn(pair.inLog!.time) : null;
    if (inTime != null) {
      return inTime;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<_AttendancePair> _buildHistoryPairs(List<AttendanceLogItem> logs) {
    if (logs.isEmpty) {
      return const [];
    }

    final sorted = [...logs]..sort((a, b) => _logSortTime(a).compareTo(_logSortTime(b)));

    final pairs = <_AttendancePair>[];
    AttendanceLogItem? pendingIn;

    for (final log in sorted) {
      final type = log.type.toUpperCase();
      if (type == 'IN') {
        if (pendingIn != null) {
          pairs.add(_AttendancePair(inLog: pendingIn));
        }
        pendingIn = log;
      } else if (type == 'OUT') {
        if (pendingIn != null) {
          pairs.add(_AttendancePair(inLog: pendingIn, outLog: log));
          pendingIn = null;
        } else {
          pairs.add(_AttendancePair(outLog: log));
        }
      }
    }

    if (pendingIn != null) {
      pairs.add(_AttendancePair(inLog: pendingIn));
    }

    return pairs;
  }

  List<_AttendanceDayGroup> _buildGroupedHistory(List<AttendanceLogItem> logs) {
    final pairs = _buildHistoryPairs(logs);
    final map = <String, List<_AttendancePair>>{};
    final dateByKey = <String, DateTime?>{};

    for (final pair in pairs) {
      final baseTime =
          (pair.inLog != null ? _parseToVn(pair.inLog!.time) : null) ??
          (pair.outLog != null ? _parseToVn(pair.outLog!.time) : null);

      final key = baseTime == null ? 'unknown' : _dayKeyFormat.format(baseTime);
      map.putIfAbsent(key, () => <_AttendancePair>[]).add(pair);
      dateByKey[key] = baseTime;
    }

    final groups = map.entries.map((entry) {
      final items = entry.value..sort((a, b) => _pairSortTime(b).compareTo(_pairSortTime(a)));
      return _AttendanceDayGroup(
        dayKey: entry.key,
        dayDate: dateByKey[entry.key],
        items: items,
      );
    }).toList();

    groups.sort((a, b) {
      final ad = a.dayDate;
      final bd = b.dayDate;
      if (ad == null && bd == null) {
        return 0;
      }
      if (ad == null) {
        return 1;
      }
      if (bd == null) {
        return -1;
      }
      return bd.compareTo(ad);
    });

    return groups;
  }

  Widget _buildPairCard(_AttendancePair pair) {
    final inLog = pair.inLog;
    final outLog = pair.outLog;

    final isOutOfRange = (inLog?.isOutOfRange ?? false) || (outLog?.isOutOfRange ?? false);

    final inTime = inLog != null ? _formatTimeVn(inLog.time) : '--:--';
    final outTime = outLog != null ? _formatTimeVn(outLog.time) : '--:--';

    final fallbackReason =
        ((outLog?.fallbackReason ?? '').isNotEmpty ? outLog?.fallbackReason : inLog?.fallbackReason);

    final tone = _actionColor(type: outLog != null ? 'OUT' : 'IN', isOutOfRange: isOutOfRange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
        color: tone.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildActionChip(type: 'IN', isOutOfRange: isOutOfRange),
              Text(inTime, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Icon(Icons.arrow_right_alt, size: 16),
              _buildActionChip(type: 'OUT', isOutOfRange: isOutOfRange),
              Text(outTime, style: const TextStyle(fontWeight: FontWeight.w600)),
              _buildRangeBadge(isOutOfRange: isOutOfRange, type: outLog?.type ?? inLog?.type),
            ],
          ),
          if ((fallbackReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Fallback: ${_fallbackReasonLabel(fallbackReason)}',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySection(_AttendanceDayGroup group, {required bool initiallyExpanded}) {
    final title = group.dayDate == null ? 'Không xác định ngày' : _formatDateVn(group.dayDate!);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey<String>('history-day-${group.dayKey}'),
        initiallyExpanded: initiallyExpanded,
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${group.items.length} dòng'),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: group.items.map(_buildPairCard).toList(),
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
    final groups = _buildGroupedHistory(_history);
    final hasGps = _position != null;
    final lastTimingNotice = _lastAction == null ? null : _timingNotice(_lastAction!);

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
                        Text('Trạng thái GPS: ${hasGps ? 'Đã sẵn sàng' : 'Chưa lấy vị trí'}'),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
                        if (lastTimingNotice != null) ...[
                          const SizedBox(height: 4),
                          Text(lastTimingNotice),
                        ],
                        const SizedBox(height: 6),
                        _buildRangeBadge(
                          isOutOfRange: _lastAction?.isOutOfRange ?? false,
                          type: _lastAction?.type,
                        ),
                        if ((_lastAction?.fallbackReason ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Fallback: ${_fallbackReasonLabel(_lastAction?.fallbackReason)}'),
                        ],
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
                if (_history.isNotEmpty)
                  ...groups.asMap().entries.map(
                    (entry) => _buildDaySection(
                      entry.value,
                      initiallyExpanded: entry.key == 0,
                    ),
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

class _AttendancePair {
  const _AttendancePair({
    this.inLog,
    this.outLog,
  });

  final AttendanceLogItem? inLog;
  final AttendanceLogItem? outLog;
}

class _AttendanceDayGroup {
  const _AttendanceDayGroup({
    required this.dayKey,
    required this.dayDate,
    required this.items,
  });

  final String dayKey;
  final DateTime? dayDate;
  final List<_AttendancePair> items;
}

