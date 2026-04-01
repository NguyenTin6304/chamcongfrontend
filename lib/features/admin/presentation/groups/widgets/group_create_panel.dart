part of '../../admin_page.dart';

extension _GroupCreatePanelX on _AdminPageState {
  Future<void> _showGroupEditorPanelExtracted({GroupLite? group}) async {
    final isEdit = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final codeController = TextEditingController(text: group?.code ?? '');
    final descriptionController = TextEditingController();
    final startController = TextEditingController(
      text: group?.startTime ?? '08:00',
    );
    final endController = TextEditingController(
      text: group?.endTime ?? '17:30',
    );
    final graceController = TextEditingController(
      text: (group?.graceMinutes ?? 15).toString(),
    );
    final autoCheckoutController = TextEditingController(
      text: group?.checkoutGraceMinutes == null
          ? '18:00'
          : '${(group!.checkoutGraceMinutes! ~/ 60).toString().padLeft(2, '0')}:${(group.checkoutGraceMinutes! % 60).toString().padLeft(2, '0')}',
    );
    bool active = group?.active ?? true;
    bool autoCheckout = group?.checkoutGraceMinutes != null;
    int selectedColor = 0;
    int? selectedGeofenceId;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'group-editor',
      barrierColor: Colors.black.withValues(alpha: 0.24),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerRight,
          child: StatefulBuilder(
            builder: (context, setPanelState) {
              Future<void> onSave() async {
                final token = _token;
                if (token == null || token.isEmpty) {
                  _showSnack('Phiên đăng nhập đã hết hạn.');
                  return;
                }
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty) {
                  _showSnack('Vui lòng nhập tên nhóm.');
                  return;
                }
                if (!isEdit && code.isEmpty) {
                  _showSnack('Vui lòng nhập mã nhóm.');
                  return;
                }
                final grace = int.tryParse(graceController.text.trim());
                if (grace == null || grace < 0) {
                  _showSnack('Giới hạn trễ không hợp lệ.');
                  return;
                }
                int? checkoutMinutes;
                if (autoCheckout) {
                  final text = autoCheckoutController.text.trim();
                  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
                  if (match == null) {
                    _showSnack('Giờ tự động checkout không hợp lệ.');
                    return;
                  }
                  final hh = int.parse(match.group(1)!);
                  final mm = int.parse(match.group(2)!);
                  checkoutMinutes = hh * 60 + mm;
                }
                setPanelState(() {
                  _savingGroup = true;
                });
                try {
                  if (isEdit) {
                    await _adminApi.updateGroup(
                      token: token,
                      groupId: group.id,
                      name: name,
                      code: code.isEmpty ? null : code,
                      active: active,
                      startTime: startController.text.trim(),
                      endTime: endController.text.trim(),
                      graceMinutes: grace,
                      checkoutGraceMinutes: checkoutMinutes,
                      clearCheckoutGraceMinutes: !autoCheckout,
                    );
                  } else {
                    await _adminApi.createGroup(
                      token: token,
                      code: code,
                      name: name,
                      active: active,
                      startTime: startController.text.trim(),
                      endTime: endController.text.trim(),
                      graceMinutes: grace,
                      checkoutGraceMinutes: checkoutMinutes,
                    );
                  }
                  if (!mounted || !context.mounted) {
                    return;
                  }
                  await _refreshGroupsOnly();
                  _showSnack(isEdit ? 'Đã cập nhật nhóm.' : 'Đã tạo nhóm mới.');
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showSnack('Không thể lưu nhóm.');
                } finally {
                  if (mounted) {
                    setPanelState(() {
                      _savingGroup = false;
                    });
                  }
                }
              }

              return Material(
                color: Colors.transparent,
                child: Container(
                  width: 420,
                  height: double.infinity,
                  color: AppColors.bgCard,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEdit ? 'Chỉnh sửa nhóm' : 'Tạo nhóm mới',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _savingGroup
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextField(
                                controller: nameController,
                                decoration: _decoration(
                                  'Tên nhóm *',
                                  Icons.groups_2_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: descriptionController,
                                decoration: _decoration(
                                  'Mô tả',
                                  Icons.subject_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: codeController,
                                decoration: _decoration(
                                  'Mã nhóm *',
                                  Icons.badge_outlined,
                                ),
                                readOnly: isEdit,
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int?>(
                                initialValue: selectedGeofenceId,
                                decoration: _decoration(
                                  'Vùng địa lý',
                                  Icons.map_outlined,
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Chưa chọn vùng'),
                                  ),
                                  ..._dashboardGeofences.map(
                                    (item) => DropdownMenuItem<int?>(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setPanelState(() {
                                    selectedGeofenceId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: startController,
                                      decoration: _decoration(
                                        'Giờ vào',
                                        Icons.access_time_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: endController,
                                      decoration: _decoration(
                                        'Giờ ra',
                                        Icons.logout_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: graceController,
                                keyboardType: TextInputType.number,
                                decoration: _decoration(
                                  'Giới hạn trễ (phút)',
                                  Icons.timer_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: autoCheckout,
                                title: const Text('Tự động checkout'),
                                onChanged: (value) {
                                  setPanelState(() {
                                    autoCheckout = value;
                                  });
                                },
                              ),
                              if (autoCheckout) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: autoCheckoutController,
                                  decoration: _decoration(
                                    'Giờ tự động checkout',
                                    Icons.alarm_outlined,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Màu nhóm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(6, (index) {
                                  const colors = <Color>[
                                    Color(0xFF3B82F6),
                                    Color(0xFF10B981),
                                    Color(0xFFF59E0B),
                                    Color(0xFFEF4444),
                                    Color(0xFF8B5CF6),
                                    Color(0xFF14B8A6),
                                  ];
                                  final selected = selectedColor == index;
                                  return GestureDetector(
                                    onTap: () {
                                      setPanelState(() {
                                        selectedColor = index;
                                      });
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: colors[index],
                                        shape: BoxShape.circle,
                                        border: selected
                                            ? Border.all(
                                                color: AppColors.textPrimary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: active,
                                title: const Text('Trạng thái hoạt động'),
                                onChanged: (value) {
                                  setPanelState(() {
                                    active = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _savingGroup
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Huỷ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _savingGroup ? null : onSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: _savingGroup
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEdit ? 'Lưu thay đổi' : 'Tạo nhóm',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
    nameController.dispose();
    codeController.dispose();
    descriptionController.dispose();
    startController.dispose();
    endController.dispose();
    graceController.dispose();
    autoCheckoutController.dispose();
  }
}
