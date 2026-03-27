import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../location/data/geoapify_client.dart';

class LocationPickerValue {
  const LocationPickerValue({
    required this.latitude,
    required this.longitude,
    this.displayName,
    this.country,
    this.city,
  });

  final double? latitude;
  final double? longitude;
  final String? displayName;
  final String? country;
  final String? city;

  bool get hasValidCoordinates {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}

class AdminLocationPicker extends StatefulWidget {
  const AdminLocationPicker({
    required this.onChanged,
    this.initialLatitude,
    this.initialLongitude,
    this.initialDisplayName,
    this.geoapifyClient,
    super.key,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialDisplayName;
  final GeoapifyClient? geoapifyClient;
  final ValueChanged<LocationPickerValue> onChanged;

  @override
  State<AdminLocationPicker> createState() => _AdminLocationPickerState();
}

class _AdminLocationPickerState extends State<AdminLocationPicker> {
  final _searchController = TextEditingController();
  final _manualLatController = TextEditingController();
  final _manualLngController = TextEditingController();
  late final GeoapifyClient _geoapifyClient;
  late final bool _ownsGeoapifyClient;

  List<GeoapifyPlace> _suggestions = const [];
  GeoapifyPlace? _selectedPlace;
  LatLng? _marker;
  late LatLng _mapCenter;

  bool _loadingSuggestions = false;
  bool _loadingReverse = false;
  bool _advancedMode = false;
  bool _searchAttempted = false;

  int _mapRenderSeed = 0;

  String? _searchError;
  String? _reverseError;

  @override
  void initState() {
    super.initState();
    _geoapifyClient = widget.geoapifyClient ?? GeoapifyClient();
    _ownsGeoapifyClient = widget.geoapifyClient == null;
    _mapCenter = LatLng(
      AppConfig.defaultMapCenterLat,
      AppConfig.defaultMapCenterLng,
    );
    _syncFromInitial();
  }

  @override
  void didUpdateWidget(covariant AdminLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latChanged = oldWidget.initialLatitude != widget.initialLatitude;
    final lngChanged = oldWidget.initialLongitude != widget.initialLongitude;
    final nameChanged = oldWidget.initialDisplayName != widget.initialDisplayName;
    if (latChanged || lngChanged || nameChanged) {
      _syncFromInitial();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualLatController.dispose();
    _manualLngController.dispose();
    if (_ownsGeoapifyClient) {
      _geoapifyClient.dispose();
    }
    super.dispose();
  }

  bool get _canUseGeoapifyApi {
    return widget.geoapifyClient != null || AppConfig.geoapifyApiKey.trim().isNotEmpty;
  }

  bool get _hasGeoapifyTileKey => AppConfig.geoapifyApiKey.trim().isNotEmpty;

  String get _tileUrlTemplate {
    if (!_hasGeoapifyTileKey) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
    final style = AppConfig.geoapifyMapStyle.trim().isEmpty
        ? 'osm-carto'
        : AppConfig.geoapifyMapStyle.trim();
    return 'https://maps.geoapify.com/v1/tile/$style/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey.trim()}';
  }

  void _syncFromInitial() {
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    final name = widget.initialDisplayName?.trim();

    if (lat != null && lng != null && _isLatLngValid(lat, lng)) {
      final latLng = LatLng(lat, lng);
      _marker = latLng;
      _mapCenter = latLng;
      _manualLatController.text = lat.toStringAsFixed(6);
      _manualLngController.text = lng.toStringAsFixed(6);
      if (name != null && name.isNotEmpty) {
        _searchController.text = name;
        _selectedPlace = GeoapifyPlace(
          displayName: name,
          lat: lat,
          lng: lng,
          country: '',
          city: '',
        );
      }
      _emitSelectionDeferred();
      return;
    }

    _marker = null;
    _selectedPlace = null;
    _manualLatController.clear();
    _manualLngController.clear();
    _searchController.clear();
    _emitSelectionDeferred();
  }

  bool _isLatLngValid(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  void _emitSelection() {
    widget.onChanged(
      LocationPickerValue(
        latitude: _marker?.latitude,
        longitude: _marker?.longitude,
        displayName: _selectedPlace?.displayName,
        country: _selectedPlace?.country,
        city: _selectedPlace?.city,
      ),
    );
  }

  void _emitSelectionDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _emitSelection();
    });
  }

  Future<void> _onSearchChanged(String text) async {
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _searchError = null;
        _loadingSuggestions = false;
        _searchAttempted = false;
      });
      return;
    }

    if (!_canUseGeoapifyApi) {
      setState(() {
        _suggestions = const [];
        _searchError = 'Thiếu GEOAPIFY_API_KEY. Bạn vẫn có thể chọn vị trí trực tiếp trên map.';
        _loadingSuggestions = false;
        _searchAttempted = true;
      });
      return;
    }

    setState(() {
      _loadingSuggestions = true;
      _searchError = null;
      _searchAttempted = true;
    });

    try {
      final suggestions = await _geoapifyClient.searchPlacesDebounced(query);
      if (!mounted) {
        return;
      }
      if (_searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = suggestions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _searchError = error.toString();
      });
    } finally {
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _loadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(GeoapifyPlace place) {
    final point = LatLng(place.lat, place.lng);
    setState(() {
      _selectedPlace = place;
      _marker = point;
      _mapCenter = point;
      _mapRenderSeed++;
      _searchController.text = place.displayName;
      _manualLatController.text = place.lat.toStringAsFixed(6);
      _manualLngController.text = place.lng.toStringAsFixed(6);
      _suggestions = const [];
      _searchAttempted = false;
      _searchError = null;
      _reverseError = null;
    });
    _emitSelection();
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _marker = point;
      _mapCenter = point;
      _mapRenderSeed++;
      _manualLatController.text = point.latitude.toStringAsFixed(6);
      _manualLngController.text = point.longitude.toStringAsFixed(6);
      _suggestions = const [];
      _searchAttempted = false;
      _searchError = null;
      _reverseError = null;
    });
    _emitSelection();

    if (!_canUseGeoapifyApi) {
      return;
    }

    setState(() {
      _loadingReverse = true;
    });

    try {
      final place = await _geoapifyClient.reverseGeocode(
        lat: point.latitude,
        lng: point.longitude,
      );
      if (!mounted) {
        return;
      }

      if (place != null) {
        setState(() {
          _selectedPlace = place;
          _searchController.text = place.displayName;
        });
        _emitSelection();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reverseError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingReverse = false;
        });
      }
    }
  }

  void _applyManualCoordinates() {
    final lat = double.tryParse(_manualLatController.text.trim());
    final lng = double.tryParse(_manualLngController.text.trim());
    if (lat == null || lng == null || !_isLatLngValid(lat, lng)) {
      setState(() {
        _reverseError = 'Tọa độ thủ công không hợp lệ. Lat [-90,90], Lng [-180,180].';
      });
      return;
    }
    _onMapTap(LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    final noResult =
        _searchAttempted &&
        !_loadingSuggestions &&
        _searchController.text.trim().isNotEmpty &&
        _suggestions.isEmpty &&
        _searchError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Tìm địa điểm (Geoapify)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchController.text.trim().isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _suggestions = const [];
                              _searchError = null;
                              _searchAttempted = false;
                            });
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null),
          ),
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _searchError!,
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        if (noResult)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Không có kết quả phù hợp.',
              style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (_, index) {
                final item = _suggestions[index];
                final subtitle = [item.city, item.country]
                    .where((part) => part.trim().isNotEmpty)
                    .join(' â€¢ ');
                return ListTile(
                  dense: true,
                  title: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  onTap: () => _selectSuggestion(item),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              key: ValueKey(_mapRenderSeed),
              options: MapOptions(
                initialCenter: _marker ?? _mapCenter,
                initialZoom: _marker == null ? 13 : 16,
                onTap: (_, point) => _onMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrlTemplate,
                  userAgentPackageName: 'com.gpit.birdle',
                ),
                MarkerLayer(
                  markers: [
                    if (_marker != null)
                      Marker(
                        point: _marker!,
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.location_pin,
                          size: 38,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingReverse)
          const LinearProgressIndicator(minHeight: 2),
        if (_reverseError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _reverseError!,
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          _selectedPlace?.displayName ??
              (_marker == null
                  ? 'Chưa chọn vị trí.'
                  : 'Đã chọn: ${_marker!.latitude.toStringAsFixed(6)}, ${_marker!.longitude.toStringAsFixed(6)}'),
          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _advancedMode = !_advancedMode;
              });
            },
            icon: Icon(_advancedMode ? Icons.expand_less : Icons.tune),
            label: Text(_advancedMode ? 'Ẩn Advanced' : 'Advanced: nhập lat/lng thủ công'),
          ),
        ),
        if (_advancedMode)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Vĩ độ',
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _manualLngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Kinh độ',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyManualCoordinates,
                child: const Text('Áp dụng'),
              ),
            ],
          ),
      ],
    );
  }
}


