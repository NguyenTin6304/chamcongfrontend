// ignore_for_file: invalid_use_of_protected_member

part of '../geofences_tab.dart';

extension _GeofenceConfigFormX on _GeofencesTabState {
  void _onManualLatLngChanged() {
    final lat = double.tryParse(_formLatController.text.trim());
    final lng = double.tryParse(_formLngController.text.trim());
    if (lat != null && lng != null) {
      setState(() {
        _newGeofencePoint = LatLng(lat, lng);
      });
    }
  }

  Future<void> _onManualLatLngSubmitted() async {
    final lat = double.tryParse(_formLatController.text.trim());
    final lng = double.tryParse(_formLngController.text.trim());
    if (lat != null && lng != null) {
      await _reverseFormAddress();
    }
  }

  Widget _buildGeofenceConfigFormExtracted() {
    final isEditing = _editingGeofence != null;
    final title = _isCreating
        ? 'Thêm vùng mới'
        : isEditing
            ? 'Chỉnh sửa: ${_editingGeofence!.name}'
            : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _formNameController,
            decoration: _decoration('Tên', Icons.place_outlined),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _formLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: _decoration('Vĩ độ', Icons.my_location_outlined),
                  onChanged: (_) => _onManualLatLngChanged(),
                  onSubmitted: (_) => _onManualLatLngSubmitted(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _formLngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: _decoration('Kinh độ', Icons.explore_outlined),
                  onChanged: (_) => _onManualLatLngChanged(),
                  onSubmitted: (_) => _onManualLatLngSubmitted(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _formRadiusController,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'Bán kính (m)',
              Icons.radio_button_checked_outlined,
            ),
          ),
          Slider(
            min: 10,
            max: 2000,
            value: (double.tryParse(_formRadiusController.text.trim()) ?? 200)
                .clamp(10, 2000)
                .toDouble(),
            divisions: 199,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() {
                _formRadiusController.text = value.round().toString();
              });
            },
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _formAddressController,
            decoration: InputDecoration(
              labelText: 'Địa điểm',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: IconButton(
                onPressed: _reversingAddress ? null : _reverseFormAddress,
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _formActive,
            title: const Text('Trạng thái hoạt động'),
            onChanged: (value) {
              setState(() {
                _formActive = value;
              });
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Loại địa điểm:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              _LocationTypeChip(
                label: 'Văn phòng',
                value: 'VP',
                selected: _formLocationType == 'VP',
                color: AppColors.geofenceVpColor,
                onTap: () => setState(() => _formLocationType = 'VP'),
              ),
              const SizedBox(width: 8),
              _LocationTypeChip(
                label: 'Site',
                value: 'SITE',
                selected: _formLocationType == 'SITE',
                color: AppColors.geofenceSiteColor,
                onTap: () => setState(() => _formLocationType = 'SITE'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isEditing)
                TextButton(
                  onPressed: _deletingGeofence ? null : _deleteGeofence,
                  child: const Text(
                    'Xóa vùng',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: _savingGeofence ? null : _cancelForm,
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _savingGeofence
                    ? null
                    : (_isCreating ? _saveNew : _saveEdit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.bgCard,
                ),
                child: _savingGeofence
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bgCard,
                        ),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
