// ignore_for_file: invalid_use_of_protected_member

part of '../geofences_tab.dart';

extension _GeofenceMapX on _GeofencesTabState {
  Widget _buildGeofencesPageExtracted() {
    final total = _geofences.length;
    final active = _geofences.where((e) => e.active).length;
    final noSignal = _geofences.where((e) => !e.active).length;
    final totalMembers = _geofences.fold<int>(
      0,
      (sum, item) => sum + item.memberCount,
    );

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
                label: 'Tong vung',
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
                label: 'Dang hoat dong',
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
                label: 'Khong tin hieu',
                value: _loadingGeofences ? '--' : _formatThousands(noSignal),
                icon: Icons.wifi_off_outlined,
                iconColor: AppColors.warning,
                valueColor: AppColors.warning,
                loading: _loadingGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Tong nhan vien',
                value: _loadingGeofences
                    ? '--'
                    : _formatThousands(totalMembers),
                icon: Icons.people_outline,
                iconColor: AppColors.overtime,
                valueColor: AppColors.overtime,
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
        _cachedGeofenceSelectedId == _selectedGeofence?.id) {
      return;
    }
    final visible = _geofences
        .where((e) => e.latitude != null && e.longitude != null)
        .toList(growable: false);
    _cachedGeofenceCircles = visible.asMap().entries.map((entry) {
      final color = _colorForGeofenceIndex(entry.key);
      final zone = entry.value;
      return CircleMarker(
        point: LatLng(zone.latitude!, zone.longitude!),
        radius: (zone.radiusMeters ?? 100).toDouble(),
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.12),
        borderStrokeWidth: 2,
        borderColor: color,
      );
    }).toList(growable: false);
    _cachedGeofenceMarkers = visible.asMap().entries.map((entry) {
      final color = _colorForGeofenceIndex(entry.key);
      final zone = entry.value;
      final isSelected = _selectedGeofence?.id == zone.id;
      return Marker(
        point: LatLng(zone.latitude!, zone.longitude!),
        width: 36,
        height: 36,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _selectGeofenceForEdit(zone),
          child: Icon(
            Icons.location_on,
            size: isSelected ? 34 : 30,
            color: isSelected ? AppColors.earlyTeal : color,
          ),
        ),
      );
    }).toList(growable: false);
    _cachedGeofenceListRef = _geofences;
    _cachedGeofenceSelectedId = _selectedGeofence?.id;
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
    final tileUrl =
        'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}';
    final selected = _selectedGeofence;
    final center = selected?.latitude != null && selected?.longitude != null
        ? LatLng(selected!.latitude!, selected.longitude!)
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
                    hintText: 'Tim dia diem...',
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
                  'Cham ban do de dat diem moi',
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
                        _zoneLatController.text = item.latitude.toStringAsFixed(
                          6,
                        );
                        _zoneLngController.text =
                            item.longitude.toStringAsFixed(6);
                        _zoneAddressController.text = item.formatted;
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
                          if ((zoom - _geofenceZoomNotifier.value).abs() >= 0.05) {
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
                  if (selected != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        width: 270,
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
                              selected.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thanh vien: ${_formatThousands(selected.memberCount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'Dang hien dien: ${_formatThousands(selected.presentCount ?? 0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => widget.onNavigateTo('logs'),
                                  child: const Text('Nhat ky'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Chinh sua'),
                                ),
                              ],
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
