// ignore_for_file: invalid_use_of_protected_member

part of '../groups_tab.dart';

extension _GroupCreatePanelX on _GroupsTabState {
  Future<void> _showGroupEditorPanelExtracted({GroupLite? group}) async {
    final isEdit = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final codeController = TextEditingController(text: group?.code ?? '');
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
      text: (group?.checkoutGraceMinutes ?? 30).toString(),
    );
    bool active = group?.active ?? true;
    bool autoCheckout = group?.checkoutGraceMinutes != null;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'group-editor',
      barrierColor: Colors.black.withValues(alpha: 0.24),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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
                  checkoutMinutes = int.tryParse(
                    autoCheckoutController.text.trim(),
                  );
                  if (checkoutMinutes == null ||
                      checkoutMinutes < 0 ||
                      checkoutMinutes > 240) {
                    _showSnack('Grace checkout phải là số phút từ 0 đến 240.');
                    return;
                  }
                }
                setPanelState(() {
                  _savingGroup = true;
                });
                try {
                  if (isEdit) {
                    final updated = await _api.updateGroup(
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
                    AdminDataCache.instance.upsertGroup(updated);
                    if (mounted) {
                      setState(() {
                        _groups = _groups
                            .map((item) => item.id == updated.id ? updated : item)
                            .toList(growable: false);
                      });
                    }
                  } else {
                    final created = await _api.createGroup(
                      token: token,
                      code: code,
                      name: name,
                      active: active,
                      startTime: startController.text.trim(),
                      endTime: endController.text.trim(),
                      graceMinutes: grace,
                      checkoutGraceMinutes: checkoutMinutes,
                    );
                    AdminDataCache.instance.upsertGroup(created);
                    if (mounted) {
                      setState(() {
                        _groups = [created, ..._groups];
                      });
                    }
                  }
                  if (!mounted || !context.mounted) {
                    return;
                  }
                  await _loadGroupGeofenceCards();
                  _showSnack(isEdit ? 'Đã cập nhật nhóm.' : 'Đã tạo nhóm mới.');
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                } on Object catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showSnack('Không thể lưu nhóm.');
                  // dialog vẫn còn mở khi có lỗi — reset button state
                  if (context.mounted) {
                    setPanelState(() {
                      _savingGroup = false;
                    });
                  }
                } finally {
                  // reset outer state (dialog đã đóng khi thành công)
                  if (mounted) {
                    setState(() {
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
                                  'Tên nhóm',
                                  Icons.groups_2_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: codeController,
                                decoration: _decoration(
                                  'Mã nhóm',
                                  Icons.badge_outlined,
                                ),
                                readOnly: isEdit,
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
                                  keyboardType: TextInputType.number,
                                  decoration: _decoration(
                                    'Giới hạn tự động checkout (phút tối đa 240)',
                                    Icons.alarm_outlined,
                                  ),
                                ),
                              ],
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
                                  foregroundColor: AppColors.bgCard,
                                ),
                                child: _savingGroup
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.bgCard,
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
    startController.dispose();
    endController.dispose();
    graceController.dispose();
    autoCheckoutController.dispose();
  }
}
