part of '../../admin_page.dart';

extension _GroupCardGridX on _AdminPageState {
  Widget _buildGroupsPageExtracted() {
    final totalGroups = _dashboardGroups.length;
    final totalEmployees = _employees.length;
    final unassigned = _unassignedGroupCount;

    return Column(
      key: _groupsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Tổng nhóm',
                value: _loadingDashboardGroups
                    ? '--'
                    : _formatThousands(totalGroups),
                icon: Icons.groups_2_outlined,
                iconColor: AppColors.primary,
                loading: _loadingDashboardGroups,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Tổng nhân viên',
                value: _loadingDashboardGroups
                    ? '--'
                    : _formatThousands(totalEmployees),
                icon: Icons.people_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingDashboardGroups,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Chưa phân công',
                value: _loadingDashboardGroups
                    ? '--'
                    : _formatThousands(unassigned),
                icon: Icons.warning_amber_outlined,
                iconColor: AppColors.warning,
                valueColor: AppColors.warning,
                loading: _loadingDashboardGroups,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupsToolbarCard(),
        const SizedBox(height: 16),
        _buildGroupsGridCard(),
        const SizedBox(height: 16),
        _buildUnassignedGroupPanel(),
      ],
    );
  }

  Widget _buildGroupsToolbarCardExtracted() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _groupsSearchController,
              onSubmitted: (_) {
                setState(() {
                  _groupsSearch = _groupsSearchController.text.trim();
                });
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm nhóm...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _groupsSearch = _groupsSearchController.text.trim();
                    });
                  },
                  icon: const Icon(Icons.search),
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
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _groupsStatus,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Tất cả'),
                ),
                DropdownMenuItem<String>(
                  value: 'active',
                  child: Text('Hoạt động'),
                ),
                DropdownMenuItem<String>(
                  value: 'inactive',
                  child: Text('Không hoạt động'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _groupsStatus = value;
                });
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showGroupEditorPanel(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Tạo nhóm mới'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsGridCardExtracted() {
    final groups = _groupsView;
    if (_loadingDashboardGroups) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          padding: const EdgeInsets.all(20),
          child: const _SkeletonCell(width: 180),
        ),
      );
    }
    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Center(
          child: Text(
            'Không có nhóm theo bộ lọc hiện tại.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 980;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: groups
              .asMap()
              .entries
              .map((entry) {
                final index = entry.key;
                final group = entry.value;
                final width = twoCols
                    ? ((constraints.maxWidth - 16) / 2).clamp(320.0, 9000.0)
                    : constraints.maxWidth;
                return SizedBox(
                  width: width,
                  child: _buildGroupCard(group, index),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
