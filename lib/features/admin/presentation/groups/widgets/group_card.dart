part of '../../admin_page.dart';

extension _GroupCardX on _AdminPageState {
  Widget _buildGroupCardExtracted(GroupLite group, int index) {
    final members = _employees
        .where((employee) => employee.groupId == group.id)
        .toList(growable: false);
    final geofences =
        _groupGeofencesByGroupId[group.id] ?? const <GroupGeofenceLite>[];
    final zoneName = geofences.isNotEmpty ? geofences.first.name : '--';
    final radius = geofences.isNotEmpty ? '${geofences.first.radiusM}m' : '--';
    final shift = '${group.startTime ?? '--'} - ${group.endTime ?? '--'}';
    final color = <Color>[
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.overtime,
      AppColors.earlyTeal,
    ][index % 6];

    return Opacity(
      opacity: group.active ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.groups_2_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        zoneName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    return IconButton(
                      onPressed: () async {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) {
                          return;
                        }
                        final offset = box.localToGlobal(Offset.zero);
                        await _showGroupActionsMenu(
                          group,
                          offset + Offset(0, box.size.height),
                        );
                      },
                      icon: const Icon(Icons.more_vert, size: 18),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildGroupMiniStat(
                    'NV',
                    _formatThousands(members.length),
                  ),
                ),
                Expanded(child: _buildGroupMiniStat('Ca làm', shift)),
                Expanded(child: _buildGroupMiniStat('Bán kính', radius)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  height: 30,
                  child: Stack(
                    children: List.generate(
                      members.length > 5 ? 5 : members.length,
                      (idx) {
                        final employee = members[idx];
                        final left = idx * 18.0;
                        return Positioned(
                          left: left,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.bgPage,
                            child: Text(
                              employee.fullName.trim().isEmpty
                                  ? 'N'
                                  : employee.fullName.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (members.length > 5)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${members.length - 5}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _activeNav = _AdminShellNav.employees;
                      _employeesGroupId = group.id;
                      _employeesStatus = 'all';
                      _employeesPage = 1;
                    });
                  },
                  child: const Text('Xem tất cả →'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: group.active ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  group.active ? 'Đang hoạt động' : 'Không hoạt động',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openGroupAdmin,
                  child: const Text('Quản lý'),
                ),
                IconButton(
                  onPressed: () => _showGroupEditorPanel(group: group),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMiniStatExtracted(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
