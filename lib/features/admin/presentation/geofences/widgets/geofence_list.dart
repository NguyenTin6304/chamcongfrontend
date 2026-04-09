part of '../geofences_tab.dart';

extension _GeofenceListX on _GeofencesTabState {
  Widget _buildGeofenceSidePanelExtracted() {
    final showForm = _isCreating || _editingGeofence != null;

    return SizedBox(
      height: 656,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            // ── Header: group selector + add button ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khu vực địa lý',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Phòng ban',
                            prefixIcon: const Icon(Icons.groups_outlined, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedGroupId,
                              isExpanded: true,
                              isDense: true,
                              items: _groups.map((g) {
                                return DropdownMenuItem<int>(
                                  value: g.id,
                                  child: Text(
                                    g.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  _onGroupSelected(value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectedGroupId == null ? null : _startCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm vùng'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Content: list or empty state ──
            Expanded(
              child: _selectedGroupId == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chọn phòng ban để xem vùng địa lý',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : _loadingGeofences
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _geofences.isEmpty && !showForm
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.map_outlined,
                                      size: 48,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Chưa có vùng địa lý nào',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: _startCreate,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Thêm vùng mới'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  ..._geofences.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final geo = entry.value;
                                    final selected =
                                        _editingGeofence?.id == geo.id;
                                    final color = _colorForGeofenceIndex(idx);
                                    return InkWell(
                                      onTap: () => _startEdit(geo),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.bgPage
                                              : Colors.transparent,
                                          border: Border(
                                            left: BorderSide(
                                              color: selected
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.location_on_outlined,
                                                color: color,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    geo.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${geo.radiusM}m',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: geo.active
                                                  ? AppColors.success
                                                  : AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  if (showForm) ...[
                                    const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                    _buildGeofenceConfigForm(),
                                  ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
