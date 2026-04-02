part of '../../admin_page.dart';

extension _GeofenceMapX on _AdminPageState {
  Widget _buildGeofencesPageExtracted() {
    final total = _dashboardGeofences.length;
    final active = _dashboardGeofences.where((e) => e.active).length;
    final noSignal = _dashboardGeofences.where((e) => !e.active).length;
    final totalMembers = _dashboardGeofences.fold<int>(
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
                label: 'Tổng vùng',
                value: _loadingDashboardGeofences
                    ? '--'
                    : _formatThousands(total),
                icon: Icons.map_outlined,
                iconColor: AppColors.primary,
                valueColor: AppColors.primary,
                loading: _loadingDashboardGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Đang hoạt động',
                value: _loadingDashboardGeofences
                    ? '--'
                    : _formatThousands(active),
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingDashboardGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Không tín hiệu',
                value: _loadingDashboardGeofences
                    ? '--'
                    : _formatThousands(noSignal),
                icon: Icons.wifi_off_outlined,
                iconColor: AppColors.warning,
                valueColor: AppColors.warning,
                loading: _loadingDashboardGeofences,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Tổng nhân viên',
                value: _loadingDashboardGeofences
                    ? '--'
                    : _formatThousands(totalMembers),
                icon: Icons.people_outline,
                iconColor: AppColors.overtime,
                loading: _loadingDashboardGeofences,
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
                    hintText: 'Tìm địa điểm...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          _searchGeofencePlaces(_geofenceSearchController.text),
                      icon: _searchingGeofencePlaces
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
                  'Chạm bản đồ để đặt điểm mới',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  final next = (_geofenceMapZoom + 1).clamp(3.0, 19.0);
                  _geofenceMapController.move(center, next);
                  setState(() {
                    _geofenceMapZoom = next;
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: () {
                  final next = (_geofenceMapZoom - 1).clamp(3.0, 19.0);
                  _geofenceMapController.move(center, next);
                  setState(() {
                    _geofenceMapZoom = next;
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          if (_geofencePlaceSuggestions.isNotEmpty) ...[
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
                itemCount: _geofencePlaceSuggestions.length,
                itemBuilder: (context, index) {
                  final item = _geofencePlaceSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      item.formatted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        _geofencePlaceSuggestions = const [];
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
                        _geofenceMapZoom,
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
                        initialZoom: _geofenceMapZoom,
                        onTap: (_, point) => _onGeofenceMapTap(point),
                        onPositionChanged: (position, _) {
                          final zoom = position.zoom;
                          if (mounted) {
                            setState(() {
                              _geofenceMapZoom = zoom;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(urlTemplate: tileUrl),
                        CircleLayer(
                          circles: _dashboardGeofences
                              .where(
                                (e) => e.latitude != null && e.longitude != null,
                              )
                              .toList(growable: false)
                              .asMap()
                              .entries
                              .map((entry) {
                                final idx = entry.key;
                                final zone = entry.value;
                                final color = _colorForGeofenceIndex(idx);
                                return CircleMarker(
                                  point: LatLng(zone.latitude!, zone.longitude!),
                                  radius: (zone.radiusMeters ?? 100).toDouble(),
                                  useRadiusInMeter: true,
                                  color: color.withValues(alpha: 0.12),
                                  borderStrokeWidth: 2,
                                  borderColor: color,
                                );
                              })
                              .toList(growable: false),
                        ),
                        MarkerLayer(
                          markers: _dashboardGeofences
                              .where(
                                (e) => e.latitude != null && e.longitude != null,
                              )
                              .toList(growable: false)
                              .asMap()
                              .entries
                              .map((entry) {
                                final idx = entry.key;
                                final zone = entry.value;
                                final color = _colorForGeofenceIndex(idx);
                                final selectedZone =
                                    _selectedGeofence?.id == zone.id;
                                return Marker(
                                  point: LatLng(zone.latitude!, zone.longitude!),
                                  width: 36,
                                  height: 36,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => _selectGeofenceForEdit(zone),
                                    child: Icon(
                                      Icons.location_on,
                                      size: selectedZone ? 34 : 30,
                                      color: selectedZone
                                          ? AppColors.earlyTeal
                                          : color,
                                    ),
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
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
                              'Thành viên: ${_formatThousands(selected.memberCount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'Đang hiện diện: ${_formatThousands(selected.presentCount ?? 0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _onShellNavTap(_AdminShellNav.logs),
                                  child: const Text('Nhật ký'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Chỉnh sửa'),
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
