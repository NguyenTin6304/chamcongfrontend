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
  int? _selectedGroupId;

  List<GroupGeofenceLite> _geofences = const [];
  GroupGeofenceLite? _editingGeofence;
  bool _isCreating = false;

  LatLng? _newGeofencePoint;
  List<GeoPlaceSuggestion> _placeSuggestions = const [];

  bool _formActive = true;

  final _geofenceSearchController = TextEditingController();
  final _formNameController = TextEditingController();
  final _formLatController = TextEditingController();
  final _formLngController = TextEditingController();
  final _formRadiusController = TextEditingController();
  final _formAddressController = TextEditingController();

  final MapController _geofenceMapController = MapController();
  final _geofenceZoomNotifier = ValueNotifier<double>(14);

  List<CircleMarker>? _cachedGeofenceCircles;
  List<Marker>? _cachedGeofenceMarkers;
  List<GroupGeofenceLite>? _cachedGeofenceListRef;
  int? _cachedGeofenceSelectedId;

  @override
  void initState() {
    super.initState();
    _formRadiusController.text = '200';
    _bootstrap();
  }

  @override
  void dispose() {
    _geofenceSearchController.dispose();
    _formNameController.dispose();
    _formLatController.dispose();
    _formLngController.dispose();
    _formRadiusController.dispose();
    _formAddressController.dispose();
    _geofenceZoomNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted || token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _token = token;
    });

    await _loadGroups(token);

    if (_groups.isNotEmpty && _selectedGroupId == null) {
      _onGroupSelected(_groups.first.id);
    }
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
      _showSnack('Không thể tải danh sách nhóm.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  void _onGroupSelected(int groupId) {
    setState(() {
      _selectedGroupId = groupId;
      _editingGeofence = null;
      _isCreating = false;
      _newGeofencePoint = null;
    });
    _resetForm();
    final token = _token;
    if (token != null && token.isNotEmpty) {
      _loadGeofences(token, groupId);
    }
  }

  Future<void> _loadGeofences(String token, int groupId) async {
    setState(() {
      _loadingGeofences = true;
    });
    try {
      final rows = await _api.listGroupGeofences(
        token: token,
        groupId: groupId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = rows;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _geofences = const [];
      });
      _showSnack('Không thể tải danh sách vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGeofences = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Form helpers
  // ---------------------------------------------------------------------------

  void _resetForm() {
    _formNameController.clear();
    _formLatController.clear();
    _formLngController.clear();
    _formRadiusController.text = '200';
    _formAddressController.clear();
    _formActive = true;
    _newGeofencePoint = null;
    _cachedGeofenceCircles = null;
    _cachedGeofenceMarkers = null;
  }

  void _startCreate() {
    setState(() {
      _isCreating = true;
      _editingGeofence = null;
    });
    _resetForm();
  }

  void _startEdit(GroupGeofenceLite item) {
    _formNameController.text = item.name;
    _formLatController.text = item.latitude.toStringAsFixed(6);
    _formLngController.text = item.longitude.toStringAsFixed(6);
    _formRadiusController.text = item.radiusM.toString();
    _formAddressController.clear();
    _formActive = item.active;
    setState(() {
      _editingGeofence = item;
      _isCreating = false;
      _newGeofencePoint = null;
    });
    _geofenceMapController.move(
      LatLng(item.latitude, item.longitude),
      _geofenceZoomNotifier.value,
    );
  }

  void _cancelForm() {
    setState(() {
      _editingGeofence = null;
      _isCreating = false;
      _newGeofencePoint = null;
    });
    _resetForm();
  }

  // ---------------------------------------------------------------------------
  // CRUD actions
  // ---------------------------------------------------------------------------

  Future<void> _saveNew() async {
    final token = _token;
    final groupId = _selectedGroupId;
    if (token == null || token.isEmpty || groupId == null) {
      return;
    }
    final name = _formNameController.text.trim();
    final lat = double.tryParse(_formLatController.text.trim());
    final lng = double.tryParse(_formLngController.text.trim());
    final radius = int.tryParse(_formRadiusController.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null) {
      _showSnack('Vui lòng nhập đầy đủ thông tin (tên, tọa độ, bán kính).');
      return;
    }
    setState(() {
      _savingGeofence = true;
    });
    try {
      await _api.createGroupGeofence(
        token: token,
        groupId: groupId,
        name: name,
        latitude: lat,
        longitude: lng,
        radiusM: radius.clamp(10, 2000),
        active: _formActive,
      );
      if (!mounted) {
        return;
      }
      _cancelForm();
      await _loadGeofences(token, groupId);
      _showSnack('Đã thêm vùng địa lý mới.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể thêm vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _savingGeofence = false;
        });
      }
    }
  }

  Future<void> _saveEdit() async {
    final token = _token;
    final groupId = _selectedGroupId;
    final editing = _editingGeofence;
    if (token == null || token.isEmpty || groupId == null || editing == null) {
      return;
    }
    final name = _formNameController.text.trim();
    final lat = double.tryParse(_formLatController.text.trim());
    final lng = double.tryParse(_formLngController.text.trim());
    final radius = int.tryParse(_formRadiusController.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null) {
      _showSnack('Vui lòng nhập đầy đủ thông tin.');
      return;
    }
    setState(() {
      _savingGeofence = true;
    });
    try {
      await _api.updateGroupGeofence(
        token: token,
        groupId: groupId,
        geofenceId: editing.id,
        name: name,
        latitude: lat,
        longitude: lng,
        radiusM: radius.clamp(10, 2000),
        active: _formActive,
      );
      if (!mounted) {
        return;
      }
      _cancelForm();
      await _loadGeofences(token, groupId);
      _showSnack('Đã cập nhật vùng địa lý.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _savingGeofence = false;
        });
      }
    }
  }

  Future<void> _deleteGeofence() async {
    final token = _token;
    final groupId = _selectedGroupId;
    final editing = _editingGeofence;
    if (token == null || token.isEmpty || groupId == null || editing == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vùng địa lý'),
        content: Text('Bạn có chắc muốn xóa "${editing.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
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
      await _api.deleteGroupGeofence(
        token: token,
        groupId: groupId,
        geofenceId: editing.id,
      );
      if (!mounted) {
        return;
      }
      _cancelForm();
      await _loadGeofences(token, groupId);
      _showSnack('Đã xóa vùng địa lý.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xóa vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingGeofence = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Map & search helpers
  // ---------------------------------------------------------------------------

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

  Future<void> _reverseFormAddress() async {
    final lat = double.tryParse(_formLatController.text.trim());
    final lng = double.tryParse(_formLngController.text.trim());
    final token = _token;
    if (lat == null || lng == null || token == null || token.isEmpty) {
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
        _geofenceSearchController.text = address;
        setState(() {
          _formAddressController.text = address;
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
    if (_isCreating || _editingGeofence != null) {
      setState(() {
        _newGeofencePoint = point;
        _formLatController.text = point.latitude.toStringAsFixed(6);
        _formLngController.text = point.longitude.toStringAsFixed(6);
      });
      _showSnack('Đã chọn điểm mới trên bản đồ.');
      await _reverseFormAddress();
    } else {
      final token = _token;
      if (token == null || token.isEmpty) return;
      setState(() {
        _reversingAddress = true;
      });
      try {
        final address = await _api.reverseGeocodeAddress(
          token: token,
          latitude: point.latitude,
          longitude: point.longitude,
        );
        if (!mounted) return;
        if (address != null && address.isNotEmpty) {
          setState(() {
            _geofenceSearchController.text = address;
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
  }

  // ---------------------------------------------------------------------------
  // UI utilities
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build delegation
  // ---------------------------------------------------------------------------

  Widget _buildGeofencesPage() {
    return _buildGeofencesPageExtracted();
  }

  Widget _buildGeofenceMapCard() {
    return _buildGeofenceMapCardExtracted();
  }

  Widget _buildGeofenceSidePanel() {
    return _buildGeofenceSidePanelExtracted();
  }

  Widget _buildGeofenceConfigForm() {
    return _buildGeofenceConfigFormExtracted();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGeofencesPage();
  }
}
