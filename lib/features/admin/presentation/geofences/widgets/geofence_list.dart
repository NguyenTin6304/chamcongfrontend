part of '../../admin_page.dart';

extension _GeofenceListX on _AdminPageState {
  Widget _buildGeofenceSidePanelExtracted() {
    final selected = _selectedGeofence;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Khu vực địa lý',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openGroupAdmin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm vùng mới'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._dashboardGeofences.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final zone = entry.value;
                    final selectedZone = selected?.id == zone.id;
                    final color = _colorForGeofenceIndex(idx);
                    return InkWell(
                      onTap: () => _selectGeofenceForEdit(zone),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: selectedZone
                              ? AppColors.bgPage
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: selectedZone
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
                                color: color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    zone.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${_formatThousands(zone.memberCount)} nhân viên . ${zone.radiusMeters ?? '--'}m',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: zone.active
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selected != null) ...[
                    const Divider(height: 1, color: AppColors.border),
                    _buildGeofenceConfigForm(selected),
                  ],
                ],
              ),
            ),
          ),
          if (selected != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _deletingGeofenceConfig
                        ? null
                        : _deleteSelectedGeofence,
                    child: const Text(
                      'Xoá vùng',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _savingGeofenceConfig
                        ? null
                        : () {
                            if (_selectedGeofence != null) {
                              _selectGeofenceForEdit(_selectedGeofence!);
                            }
                          },
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _savingGeofenceConfig ? null : _saveGeofenceConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _savingGeofenceConfig
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
