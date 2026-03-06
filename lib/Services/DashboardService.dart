import 'dart:async';
import '../RestAPI/RestAPIService.dart';
import '../Model/GatewayModel.dart';

class DeviceLocation {
  final String devEui;
  final String name;
  final double latitude;
  final double longitude;
  final String status;

  DeviceLocation({
    required this.devEui,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
  });
}

class DashboardSummary {
  final int activeDevices;
  final int inactiveDevices;
  final int neverSeenDevices;
  final int onlineGateways;
  final int offlineGateways;
  final int neverSeenGateways;
  final List<Gateway> gateways;
  final List<DeviceLocation> deviceLocations;

  DashboardSummary({
    required this.activeDevices,
    required this.inactiveDevices,
    required this.neverSeenDevices,
    required this.onlineGateways,
    required this.offlineGateways,
    required this.neverSeenGateways,
    required this.gateways,
    required this.deviceLocations,
  });
}

class DashboardService {
  static Future<DashboardSummary> getSummary(String tenantId) async {
    try {
      // timeout
      return await _fetchDashboardData(tenantId).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(' ,Please check your connection or server status.');
        },
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<DashboardSummary> _fetchDashboardData(String tenantId) async {
    // 1. Fetch Gateways and Applications concurrently
    final initialFetches = await Future.wait([
      RestAPIService.get('/gateways?limit=100&tenantId=$tenantId'),
      RestAPIService.get('/applications?limit=1000&tenantId=$tenantId'),
    ]);

    final gatewayData = initialFetches[0]['result'] as List? ?? [];
    final appData = initialFetches[1]['result'] as List? ?? [];

    // --- Process Gateways ---
    int onlineGateways = 0, offlineGateways = 0, neverSeenGateways = 0;
    List<Gateway> parsedGateways = gatewayData.map((gw) {
      final gatewayModel = Gateway.fromJson(gw);
      final state = gatewayModel.state.toUpperCase();

      if (state == 'ONLINE') onlineGateways++;
      else if (state == 'OFFLINE') offlineGateways++;
      else neverSeenGateways++;

      return gatewayModel;
    }).toList();

    // --- Process Applications to get Devices ---
    final nowUtc = DateTime.now().toUtc();
    int activeDevices = 0, inactiveDevices = 0, neverSeenDevices = 0;
    List<DeviceLocation> parsedDeviceLocations = [];

    // Fetch all devices for all applications concurrently
    final deviceFetches = await Future.wait(
        appData.map((app) => RestAPIService.get('/devices?limit=1000&applicationId=${app['id']}'))
    );

    // Flatten the list of all devices
    final allDevices = deviceFetches.expand((data) => data['result'] as List? ?? []).toList();

    // Prepare concurrent fetches for device specific details (Variables/Location)
    List<Future<void>> detailFutures = [];

    for (var dev in allDevices) {
      String devEui = dev['devEui'];
      String devName = dev['name'] ?? 'Unknown';
      String? lastSeenAt = dev['lastSeenAt'] ?? dev['deviceStatus']?['lastSeenAt'];
      String currentStatus = "Never seen";

      // Status Logic
      if (lastSeenAt == null || lastSeenAt.isEmpty) {
        neverSeenDevices++;
      } else {
        try {
          DateTime seen = DateTime.parse(lastSeenAt);
          if (nowUtc.difference(seen).inMinutes <= 60) {
            activeDevices++;
            currentStatus = "Active";
          } else {
            inactiveDevices++;
            currentStatus = "Inactive";
          }
        } catch (_) {
          neverSeenDevices++;
        }
      }

      // Add the detail fetch to our concurrent queue.
      // We catch errors individually so one broken device doesn't fail the whole dashboard.
      detailFutures.add(
          RestAPIService.get('/devices/$devEui').then((detailData) {
            final variables = detailData['device']?['variables'];
            if (variables != null && variables is Map) {
              double? lat = double.tryParse(variables['Latitude']?.toString() ?? '');
              double? lng = double.tryParse(variables['Longitude']?.toString() ?? '');

              if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                parsedDeviceLocations.add(DeviceLocation(
                  devEui: devEui,
                  name: devName,
                  latitude: lat,
                  longitude: lng,
                  status: currentStatus,
                ));
              }
            }
          }).catchError((e) {
            // Silently ignore individual device fetch failures to keep parsing the rest
            print("Failed to fetch variables for $devEui: $e");
          })
      );
    }

    // Execute all device detail fetches concurrently
    await Future.wait(detailFutures);

    return DashboardSummary(
      activeDevices: activeDevices,
      inactiveDevices: inactiveDevices,
      neverSeenDevices: neverSeenDevices,
      onlineGateways: onlineGateways,
      offlineGateways: offlineGateways,
      neverSeenGateways: neverSeenGateways,
      gateways: parsedGateways,
      deviceLocations: parsedDeviceLocations,
    );
  }
}