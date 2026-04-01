part of '../../admin_page.dart';

extension _AttendanceDetailModalX on _AdminPageState {
  Future<void> _showAttendanceLogDetailModal(DashboardAttendanceLogItem item) async {
    final lat = item.latitude ?? AppConfig.defaultMapCenterLat;
    final lng = item.longitude ?? AppConfig.defaultMapCenterLng;
    final tileUrl =
        'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chi tiết chấm công'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.employeeName} (${item.employeeCode})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Phòng ban: ${item.departmentName}'),
                Text(
                  'Ngày: ${item.workDate == null ? '--' : DateFormat('dd/MM/yyyy').format(item.workDate!)}',
                ),
                Text('Giờ vào: ${item.checkInTime}'),
                Text('Giờ ra: ${item.checkOutTime}'),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(urlTemplate: tileUrl),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 34,
                              height: 34,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.earlyTeal,
                                size: 30,
                              ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
}
