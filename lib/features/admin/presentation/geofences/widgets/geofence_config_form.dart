// ignore_for_file: invalid_use_of_protected_member

part of '../geofences_tab.dart';

extension _GeofenceConfigFormX on _GeofencesTabState {
  Widget _buildGeofenceConfigFormExtracted(DashboardGeofenceItem selected) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cau hinh: ${selected.name}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _zoneNameController,
            decoration: _decoration('Ten *', Icons.place_outlined),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zoneLatController,
                  readOnly: true,
                  decoration: _decoration('Vi do', Icons.my_location_outlined),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _zoneLngController,
                  readOnly: true,
                  decoration: _decoration('Kinh do', Icons.explore_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _zoneRadiusController,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'Ban kinh (m)',
              Icons.radio_button_checked_outlined,
            ),
          ),
          Slider(
            min: 10,
            max: 2000,
            value: (double.tryParse(_zoneRadiusController.text.trim()) ?? 200)
                .clamp(10, 2000)
                .toDouble(),
            divisions: 199,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() {
                _zoneRadiusController.text = value.round().toString();
              });
            },
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _zoneAddressController,
            decoration: InputDecoration(
              labelText: 'Dia diem',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: IconButton(
                onPressed: _reversingAddress ? null : _reverseZoneAddress,
                icon: _reversingAddress
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickZoneTime(_zoneStartTimeController),
                  icon: const Icon(Icons.login_outlined, size: 16),
                  label: Text('Gio vao ${_zoneStartTimeController.text}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickZoneTime(_zoneEndTimeController),
                  icon: const Icon(Icons.logout_outlined, size: 16),
                  label: Text('Gio ra ${_zoneEndTimeController.text}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _zoneOvertimeEnabled,
            title: const Text('Tang ca'),
            onChanged: (value) {
              setState(() {
                _zoneOvertimeEnabled = value;
              });
            },
          ),
          if (_zoneOvertimeEnabled)
            OutlinedButton.icon(
              onPressed: () => _pickZoneTime(_zoneOvertimeStartController),
              icon: const Icon(Icons.nightlight_outlined, size: 16),
              label: Text('Bat dau OT ${_zoneOvertimeStartController.text}'),
            ),
          const SizedBox(height: 10),
          const Text(
            'Nhom duoc gan',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _groups
                .map((group) {
                  return FilterChip(
                    label: Text(group.name),
                    selected: _zoneAssignedGroupIds.contains(group.id),
                    selectedColor: AppColors.primary.withValues(alpha: 0.14),
                    checkmarkColor: AppColors.primary,
                    onSelected: (selectedChip) {
                      setState(() {
                        if (selectedChip) {
                          _zoneAssignedGroupIds.add(group.id);
                        } else {
                          _zoneAssignedGroupIds.remove(group.id);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _zoneActive,
            title: const Text('Trang thai hoat dong'),
            onChanged: (value) {
              setState(() {
                _zoneActive = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
