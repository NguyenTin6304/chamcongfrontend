// ignore_for_file: invalid_use_of_protected_member

part of '../geofences_tab.dart';

extension _GeofenceMapX on _GeofencesTabState {
  Widget _buildGeofencesPageExtracted() {
    final total = _geofences.length;
    final active = _geofences.where((e) => e.active).length;
    final inactive = _geofences.where((e) => !e.active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Tổng vùng',
                value: _loadingGeofences ? '--' : _formatThousands(total),
                icon: Icons.map_outlined,
                iconColor: AppColors.primary,
                valueColor: AppColors.primary,
                loading: _loadingGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Đang hoạt động',
                value: _loadingGeofences ? '--' : _formatThousands(active),
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Không hoạt động',
                value: _loadingGeofences ? '--' : _formatThousands(inactive),
                icon: Icons.wifi_off_outlined,
                iconColor: AppColors.warning,
                valueColor: AppColors.warning,
                loading: _loadingGeofences,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1200) {
              return Column(
                children: [
                  _buildGeofenceMapCard(),
                  const SizedBox(height: 16),
                  _buildGeofenceSidePanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 65, child: _buildGeofenceMapCard()),
                const SizedBox(width: 16),
                Expanded(flex: 35, child: _buildGeofenceSidePanel()),
              ],
            );
          },
        ),
      ],
    );
  }

  void _ensureGeofenceLayers() {
    if (_cachedGeofenceCircles != null &&
        identical(_cachedGeofenceListRef, _geofences) &&
        _cachedGeofenceSelectedId == _editingGeofence?.id) {
      return;
    }
    _cachedGeofenceCircles = _geofences.asMap().entries.map((entry) {
      final color = _colorForGeofenceIndex(entry.key);
      final geo = entry.value;
      return CircleMarker(
        point: LatLng(geo.latitude, geo.longitude),
        radius: geo.radiusM.toDouble(),
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.12),
        borderStrokeWidth: 2,
        borderColor: color,
      );
    }).toList(growable: false);
    _cachedGeofenceMarkers = _geofences.asMap().entries.map((entry) {
      final color = _colorForGeofenceIndex(entry.key);
      final geo = entry.value;
      final isSelected = _editingGeofence?.id == geo.id;
      return Marker(
        point: LatLng(geo.latitude, geo.longitude),
        width: 36,
        height: 36,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _startEdit(geo),
          child: Icon(
            Icons.location_on,
            size: isSelected ? 34 : 30,
            color: isSelected ? AppColors.earlyTeal : color,
          ),
        ),
      );
    }).toList(growable: false);
    _cachedGeofenceListRef = _geofences;
    _cachedGeofenceSelectedId = _editingGeofence?.id;
  }

  List<CircleMarker> get _geofenceCirclesCache {
    _ensureGeofenceLayers();
    return _cachedGeofenceCircles!;
  }

  List<Marker> get _geofenceMarkersCache {
    _ensureGeofenceLayers();
    return _cachedGeofenceMarkers!;
  }

  Widget _buildGeofenceMapCardExtracted() {
    const tileUrl =
        'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}';
    final editing = _editingGeofence;
    final center = editing != null
        ? LatLng(editing.latitude, editing.longitude)
        : LatLng(AppConfig.defaultMapCenterLat, AppConfig.defaultMapCenterLng);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _geofenceSearchController,
                  onSubmitted: _searchGeofencePlaces,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Tìm địa điểm...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          _searchGeofencePlaces(_geofenceSearchController.text),
                      icon: _searchingPlaces
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore_outlined),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Chạm bản đồ để chọn địa điểm',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  final next = (_geofenceZoomNotifier.value + 1).clamp(3.0, 19.0);
                  _geofenceMapController.move(center, next);
                  _geofenceZoomNotifier.value = next;
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: () {
                  final next = (_geofenceZoomNotifier.value - 1).clamp(3.0, 19.0);
                  _geofenceMapController.move(center, next);
                  _geofenceZoomNotifier.value = next;
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          if (_placeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _placeSuggestions.length,
                itemBuilder: (context, index) {
                  final item = _placeSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      item.formatted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        _placeSuggestions = const [];
                        _formLatController.text =
                            item.latitude.toStringAsFixed(6);
                        _formLngController.text =
                            item.longitude.toStringAsFixed(6);
                        _formAddressController.text = item.formatted;
                        _newGeofencePoint = LatLng(
                          item.latitude,
                          item.longitude,
                        );
                      });
                      _geofenceMapController.move(
                        LatLng(item.latitude, item.longitude),
                        _geofenceZoomNotifier.value,
                      );
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 560,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: FlutterMap(
                      mapController: _geofenceMapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: _geofenceZoomNotifier.value,
                        onTap: (_, point) => _onGeofenceMapTap(point),
                        onPositionChanged: (position, _) {
                          final zoom = position.zoom;
                          if ((zoom - _geofenceZoomNotifier.value).abs() >=
                              0.05) {
                            _geofenceZoomNotifier.value = zoom;
                          }
                        },
                      ),
                      children: [
                        TileLayer(urlTemplate: tileUrl),
                        CircleLayer(circles: _geofenceCirclesCache),
                        MarkerLayer(markers: _geofenceMarkersCache),
                        if (_newGeofencePoint != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _newGeofencePoint!,
                                width: 34,
                                height: 34,
                                child: const Icon(
                                  Icons.add_location_alt,
                                  size: 30,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (editing != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editing.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bán kính: ${editing.radiusM}m',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              editing.active
                                  ? 'Đang hoạt động'
                                  : 'Không hoạt động',
                              style: TextStyle(
                                fontSize: 12,
                                color: editing.active
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
