import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:birdle/core/config/app_config.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';

class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.geofences,
    required this.isLocating,
    required this.onRefreshLocation,
    required this.mapHeight,
  });

  final MapController mapController;
  final Position? currentPosition;
  final List<GeofencePoint> geofences;
  final bool isLocating;
  final VoidCallback onRefreshLocation;
  final double mapHeight;

  bool get _isInsideGeofence {
    final pos = currentPosition;
    if (pos == null || geofences.isEmpty) return false;
    for (final g in geofences) {
      final dist = const Distance().as(
        LengthUnit.Meter,
        LatLng(pos.latitude, pos.longitude),
        LatLng(g.latitude, g.longitude),
      );
      if (dist <= g.radiusM) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final position = currentPosition;

    if (position == null) {
      return Container(
        height: mapHeight,
        decoration: const BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.cardAll,
        ),
        child: const Center(
          child: Icon(
            Icons.map_outlined,
            size: AppSpacing.xxxl + AppSpacing.lg,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final userPos = LatLng(position.latitude, position.longitude);
    final inside = _isInsideGeofence;
    final accuracy = position.accuracy;
    final latStr = position.latitude.toStringAsFixed(6);
    final lngStr = position.longitude.toStringAsFixed(6);

    final accuracyCircles = <CircleMarker>[
      if (accuracy > 0 && accuracy < 500)
        CircleMarker(
          point: userPos,
          radius: accuracy,
          useRadiusInMeter: true,
          color: AppColors.primary.withValues(alpha: 0.12),
          borderColor: AppColors.primary.withValues(alpha: 0.35),
          borderStrokeWidth: 1.0,
        ),
    ];

    return ClipRRect(
      borderRadius: AppRadius.cardAll,
      child: SizedBox(
        height: mapHeight,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: FlutterMap(
                key: const ValueKey('user-map'),
                mapController: mapController,
                options: MapOptions(
                  initialCenter: userPos,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://maps.geoapify.com/v1/tile/${AppConfig.geoapifyMapStyle}/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}',
                    userAgentPackageName: 'com.example.birdle',
                  ),
                  if (accuracyCircles.isNotEmpty)
                    CircleLayer(circles: accuracyCircles),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: userPos,
                        width: AppSizes.markerSize,
                        height: AppSizes.markerSize,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.40),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Top-left: inside/outside geofence status
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _MapOverlayChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AppSpacing.sm,
                      height: AppSpacing.sm,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: geofences.isEmpty
                            ? AppColors.primary
                            : (inside ? AppColors.success : AppColors.error),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      geofences.isEmpty
                          ? 'GPS hiện tại'
                          : (inside ? 'Trong phạm vi' : 'Ngoài phạm vi'),
                      style: AppTextStyles.sectionLabel.copyWith(
                        color: geofences.isEmpty
                            ? AppColors.textPrimary
                            : (inside ? AppColors.success : AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top-right: lat/lng + accuracy
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _MapOverlayChip(
                opacity: 0.92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lat: $latStr',
                      style: AppTextStyles.mapOverlay.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Lng: $lngStr',
                      style: AppTextStyles.mapOverlay.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (accuracy > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '±${accuracy < 10 ? accuracy.toStringAsFixed(1) : accuracy.toStringAsFixed(0)}m',
                        style: AppTextStyles.mapOverlay.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accuracy <= 20
                              ? AppColors.success
                              : accuracy <= 100
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom-left: geofence name
            if (geofences.isNotEmpty)
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _MapOverlayChip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pin_drop_outlined,
                        size: AppSpacing.md,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        geofences.length == 1
                            ? geofences.first.name
                            : '${geofences.length} khu vực',
                        style: AppTextStyles.sectionLabel.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom-right: locate / refresh GPS button
            Positioned(
              bottom: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _LocateButton(
                accuracy: accuracy,
                isLocating: isLocating,
                onTap: isLocating ? null : onRefreshLocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOverlayChip extends StatelessWidget {
  const _MapOverlayChip({required this.child, this.opacity = 1.0});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: opacity),
        borderRadius: AppRadius.smallAll,
        boxShadow: AppShadows.mapElement,
      ),
      child: child,
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({
    required this.accuracy,
    required this.isLocating,
    required this.onTap,
  });

  final double accuracy;
  final bool isLocating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: isLocating ? 'Đang lấy vị trí' : 'Làm mới vị trí GPS',
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
        width: AppSizes.locateButtonSize,
        height: AppSizes.locateButtonSize,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppShadows.mapElement,
        ),
        child: isLocating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                accuracy > 0 && accuracy <= 100
                    ? Icons.my_location
                    : Icons.location_searching,
                size: AppSpacing.xl,
                color: accuracy <= 0
                    ? AppColors.textSecondary
                    : accuracy <= 100
                        ? AppColors.primary
                        : AppColors.warning,
              ),
        ),
      ),
      ),
    );
  }
}
