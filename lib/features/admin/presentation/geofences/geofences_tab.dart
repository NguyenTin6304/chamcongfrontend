// ignore_for_file: prefer_final_fields, unused_element, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/common/kpi_card.dart';
import '../../data/admin_api.dart';
import '../../data/admin_data_cache.dart';

part 'widgets/geofence_config_form.dart';
part 'widgets/geofence_list.dart';
part 'widgets/geofence_map.dart';

class GeofencesTab extends StatefulWidget {
  const GeofencesTab({required this.onNavigateTo, super.key});

  final void Function(String section) onNavigateTo;

  @override
  State<GeofencesTab> createState() => _GeofencesTabState();
}

class _GeofencesTabState extends State<GeofencesTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;

  bool _loadingGroups = false;
  bool _loadingGeofences = false;
  bool _searchingPlaces = false;
  bool _reversingAddress = false;
  bool _savingGeofence = false;
  bool _deletingGeofence = false;

  List<GroupLite> _groups = const [];
  List<DashboardGeofenceItem> _geofences = const [];
  DashboardGeofenceItem? _selectedGeofence;
  LatLng? _newGeofencePoint;
  List<GeoPlaceSuggestion> _placeSuggestions = const [];

  bool _zoneOvertimeEnabled = false;
  bool _zoneActive = true;
  final Set<int> _zoneAssignedGroupIds = {};

  final _geofenceSearchController = TextEditingController();
  final _zoneNameController = TextEditingController();
  final _zoneLatController = TextEditingController();
  final _zoneLngController = TextEditingController();
  final _zoneRadiusController = TextEditingController();
  final _zoneAddressController = TextEditingController();
  final _zoneStartTimeController = TextEditingController();
  final _zoneEndTimeController = TextEditingController();
  final _zoneOvertimeStartController = TextEditingController();

  final MapController _geofenceMapController = MapController();
  final _geofenceZoomNotifier = ValueNotifier<double>(14);

  List<CircleMarker>? _cachedGeofenceCircles;
  List<Marker>? _cachedGeofenceMarkers;
  List<DashboardGeofenceItem>? _cachedGeofenceListRef;
  int? _cachedGeofenceSelectedId;

  @override
  void initState() {
    super.initState();
    _zoneRadiusController.text = '200';
    _zoneStartTimeController.text = '08:00';
    _zoneEndTimeController.text = '17:30';
    _zoneOvertimeStartController.text = '18:00';
    _bootstrap();
  }

  @override
  void dispose() {
    _geofenceSearchController.dispose();
    _zoneNameController.dispose();
    _zoneLatController.dispose();
    _zoneLngController.dispose();
    _zoneRadiusController.dispose();
    _zoneAddressController.dispose();
    _zoneStartTimeController.dispose();
    _zoneEndTimeController.dispose();
    _zoneOvertimeStartController.dispose();
    _geofenceZoomNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted || token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _token = token;
    });

    await Future.wait<void>([_loadGroups(token), _loadGeofences(token)]);
  }

  Future<void> _loadGroups(String token) async {
    setState(() {
      _loadingGroups = true;
    });
    try {
      final groups = await AdminDataCache.instance.fetchGroups(token, _api);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = groups;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Khong the tai danh sach nhom.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  Future<void> _loadGeofences(String token) async {
    setState(() {
      _loadingGeofences = true;
    });
    try {
      final rows = await _api.listDashboardGeofences(token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = rows;
      });
      _syncSelectedGeofence();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = const [];
        _selectedGeofence = null;
      });
      _showSnack('Khong the tai danh sach vung dia ly.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGeofences = false;
        });
      }
    }
  }

  void _syncSelectedGeofence() {
    if (!mounted) {
      return;
    }
    if (_geofences.isEmpty) {
      setState(() {
        _selectedGeofence = null;
      });
      return;
    }
    if (_selectedGeofence == null) {
      _selectGeofenceForEdit(_geofences.first, moveMap: false);
      return;
    }

    DashboardGeofenceItem? refreshed;
    for (final item in _geofences) {
      if (item.id == _selectedGeofence!.id) {
        refreshed = item;
        break;
      }
    }
    if (refreshed == null) {
      _selectGeofenceForEdit(_geofences.first, moveMap: false);
      return;
    }
    _selectGeofenceForEdit(refreshed, moveMap: false);
  }

  void _selectGeofenceForEdit(
    DashboardGeofenceItem item, {
    bool moveMap = true,
  }) {
    _zoneNameController.text = item.name;
    _zoneLatController.text = (item.latitude ?? AppConfig.defaultMapCenterLat)
        .toStringAsFixed(6);
    _zoneLngController.text = (item.longitude ?? AppConfig.defaultMapCenterLng)
        .toStringAsFixed(6);
    _zoneRadiusController.text = (item.radiusMeters ?? 200).toString();
    _zoneAddressController.text = item.address ?? '';
    _zoneStartTimeController.text = item.startTime ?? '08:00';
    _zoneEndTimeController.text = item.endTime ?? '17:30';
    _zoneOvertimeEnabled = item.overtimeEnabled ?? false;
    _zoneOvertimeStartController.text = item.overtimeStartTime ?? '18:00';
    _zoneActive = item.active;
    _zoneAssignedGroupIds
      ..clear()
      ..addAll(item.groupId == null ? const <int>[] : <int>[item.groupId!]);
    setState(() {
      _selectedGeofence = item;
      _newGeofencePoint = null;
    });
    if (moveMap && item.latitude != null && item.longitude != null) {
      _geofenceMapController.move(
        LatLng(item.latitude!, item.longitude!),
        _geofenceZoomNotifier.value,
      );
    }
  }

  Future<void> _searchGeofencePlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _placeSuggestions = const [];
      });
      return;
    }
    setState(() {
      _searchingPlaces = true;
    });
    try {
      final result = await _api.searchGeoapifyPlaces(query: q);
      if (!mounted) {
        return;
      }
      setState(() {
        _placeSuggestions = result;
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchingPlaces = false;
        });
      }
    }
  }

  Future<void> _reverseZoneAddress() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    final lat = double.tryParse(_zoneLatController.text.trim());
    final lng = double.tryParse(_zoneLngController.text.trim());
    if (lat == null || lng == null) {
      return;
    }
    setState(() {
      _reversingAddress = true;
    });
    try {
      final address = await _api.reverseGeocodeAddress(
        token: token,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) {
        return;
      }
      if (address != null && address.isNotEmpty) {
        setState(() {
          _zoneAddressController.text = address;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reversingAddress = false;
        });
      }
    }
  }

  Future<void> _onGeofenceMapTap(LatLng point) async {
    setState(() {
      _newGeofencePoint = point;
      _zoneLatController.text = point.latitude.toStringAsFixed(6);
      _zoneLngController.text = point.longitude.toStringAsFixed(6);
    });
    _showSnack('Da chon diem moi tren ban do.');
    await _reverseZoneAddress();
  }

  Future<void> _pickZoneTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final current = controller.text.trim();
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(current);
    final initial = match == null
        ? now
        : TimeOfDay(
            hour: int.tryParse(match.group(1)!) ?? now.hour,
            minute: int.tryParse(match.group(2)!) ?? now.minute,
          );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) {
      return;
    }
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveGeofenceConfig() async {
    final token = _token;
    final selected = _selectedGeofence;
    if (token == null || token.isEmpty || selected == null) {
      _showSnack('Khong the luu cau hinh vung.');
      return;
    }
    final name = _zoneNameController.text.trim();
    final lat = double.tryParse(_zoneLatController.text.trim());
    final lng = double.tryParse(_zoneLngController.text.trim());
    final radius = int.tryParse(_zoneRadiusController.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null) {
      _showSnack('Vui long nhap day du thong tin vung dia ly.');
      return;
    }
    setState(() {
      _savingGeofence = true;
    });
    try {
      final updated = await _api.updateGeofence(
        token: token,
        geofenceId: selected.id,
        name: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius.clamp(10, 2000),
        active: _zoneActive,
        startTime: _zoneStartTimeController.text.trim(),
        endTime: _zoneEndTimeController.text.trim(),
        overtimeEnabled: _zoneOvertimeEnabled,
        overtimeStartTime: _zoneOvertimeEnabled
            ? _zoneOvertimeStartController.text.trim()
            : null,
        groupIds: _zoneAssignedGroupIds.toList(growable: false),
        address: _zoneAddressController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = _geofences
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
      _selectGeofenceForEdit(updated);
      _showSnack('Da cap nhat vung dia ly.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Khong the cap nhat vung dia ly.');
    } finally {
      if (mounted) {
        setState(() {
          _savingGeofence = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedGeofence() async {
    final token = _token;
    final selected = _selectedGeofence;
    if (token == null || token.isEmpty || selected == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoa vung dia ly'),
        content: Text('Ban co chac muon xoa "${selected.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    setState(() {
      _deletingGeofence = true;
    });
    try {
      await _api.deleteGeofence(token: token, geofenceId: selected.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = _geofences
            .where((item) => item.id != selected.id)
            .toList(growable: false);
      });
      _syncSelectedGeofence();
      _showSnack('Da xoa vung dia ly.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Khong the xoa vung dia ly.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingGeofence = false;
        });
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatThousands(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  Color _colorForGeofenceIndex(int index) {
    const palette = <Color>[
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.overtime,
      AppColors.earlyTeal,
    ];
    return palette[index % palette.length];
  }

  Widget _buildGeofencesPage() {
    return _buildGeofencesPageExtracted();
  }

  Widget _buildGeofenceMapCard() {
    return _buildGeofenceMapCardExtracted();
  }

  Widget _buildGeofenceSidePanel() {
    return _buildGeofenceSidePanelExtracted();
  }

  Widget _buildGeofenceConfigForm(DashboardGeofenceItem selected) {
    return _buildGeofenceConfigFormExtracted(selected);
  }

  @override
  Widget build(BuildContext context) {
    return _buildGeofencesPage();
  }
}
