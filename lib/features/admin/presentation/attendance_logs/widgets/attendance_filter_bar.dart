part of '../../admin_page.dart';

extension _AttendanceFilterBarX on _AdminPageState {
  Widget _buildAttendanceFilterBarCard() {
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
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _loadingDashboardLogs
                ? null
                : () => _pickLogsDate(isFrom: true),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              'Từ ${DateFormat('dd/MM/yyyy').format(_logsFromDate)}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loadingDashboardLogs
                ? null
                : () => _pickLogsDate(isFrom: false),
            icon: const Icon(Icons.event_available_outlined),
            label: Text(
              'Đến ${DateFormat('dd/MM/yyyy').format(_logsToDate)}',
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_dashboardGroupId),
              initialValue: _dashboardGroupId,
              decoration: _decoration('Nhóm', Icons.group_outlined),
              items: _dashboardGroupItems(),
              onChanged: _loadingDashboardLogs
                  ? null
                  : (value) {
                      setState(() {
                        _dashboardGroupId = value;
                        _logsPage = 1;
                      });
                      _refreshLogsOnly();
                    },
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(_dashboardStatus),
              initialValue: _dashboardStatus,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Tất cả'),
                ),
                DropdownMenuItem<String>(
                  value: 'on_time',
                  child: Text('Đúng giờ'),
                ),
                DropdownMenuItem<String>(
                  value: 'late',
                  child: Text('Vào muộn'),
                ),
                DropdownMenuItem<String>(
                  value: 'out_of_range',
                  child: Text('Ngoài vùng'),
                ),
              ],
              onChanged: _loadingDashboardLogs
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _dashboardStatus = value;
                        _logsPage = 1;
                      });
                      _refreshLogsOnly();
                    },
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _logsSearchController,
              onSubmitted: (_) {
                setState(() {
                  _logsSearch = _logsSearchController.text.trim();
                  _logsPage = 1;
                });
                _refreshLogsOnly();
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm nhân viên...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  onPressed: _loadingDashboardLogs
                      ? null
                      : () {
                          setState(() {
                            _logsSearch = _logsSearchController.text.trim();
                            _logsPage = 1;
                          });
                          _refreshLogsOnly();
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
          OutlinedButton.icon(
            onPressed: _loadingDashboardLogs
                ? null
                : () {
                    setState(() {
                      _logsPage = 1;
                    });
                    _refreshLogsOnly();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Làm mới'),
          ),
          ElevatedButton.icon(
            onPressed: _exportingDashboardCsv ? null : _exportAttendanceLogsCsv,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: _exportingDashboardCsv
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Xuất CSV'),
          ),
        ],
      ),
    );
  }
}
