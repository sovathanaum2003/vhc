import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../Color/AppColor.dart';
import '../Model/GatewayModel.dart';

class GatewayDetailScreen extends StatelessWidget {
  final Gateway gateway;

  const GatewayDetailScreen({super.key, required this.gateway});

  @override
  Widget build(BuildContext context) {
    // --- 1. Theme & Color Logic ---
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);
    final labelColor = AppColors.secondaryText(context);

    const Color specificBrightBlue = Color(0xFF9FCCFF);
    final headerColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue;
    final cardColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue.withOpacity(0.3);
    final headerTextColor = isDark ? Colors.white : Colors.black;

    // --- MAP LOGIC ---
    final bool hasLocation = gateway.latitude != 0.0 || gateway.longitude != 0.0;
    final LatLng initialCenter = hasLocation
        ? LatLng(gateway.latitude, gateway.longitude)
        : const LatLng(11.5564, 104.9282);

    Color getIconColor() {
      switch (gateway.state.toUpperCase()) {
        case 'ONLINE': return AppColors.green;
        case 'OFFLINE': return AppColors.red;
        default: return AppColors.orange;
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headerTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Gateway Detail",
          style: TextStyle(
            color: headerTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. GENERAL INFO SECTION ---
                  Text(
                    "General Information",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    color: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildRichText("Gateway Name", gateway.name, textColor, labelColor),
                            ),
                            _buildStatusBadge(gateway.state, textColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRichText("Gateway ID", gateway.gatewayId, textColor, labelColor),
                        const SizedBox(height: 12),
                        _buildRichText("Last Seen", _formatDate(gateway.lastSeenAt), textColor, labelColor),
                        const SizedBox(height: 12),
                        _buildRichText("Created Date", _formatDate(gateway.createdAt), textColor, labelColor),
                        const SizedBox(height: 12),
                        _buildRichText("Updated Date", _formatDate(gateway.updatedAt), textColor, labelColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- 2. LOCATION SECTION ---
                  Text(
                    "Gateway Location",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    color: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRichText("Latitude", gateway.latitude.toString(), textColor, labelColor),
                        const SizedBox(height: 12),
                        _buildRichText("Longitude", gateway.longitude.toString(), textColor, labelColor),
                        const SizedBox(height: 12),
                        _buildRichText("Altitude", gateway.altitude.toString(), textColor, labelColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- 3. MAP TITLE ---
                  Text(
                    "Map View",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                ],
              ),
            ),

            // --- 4. MAP WIDGET REVERTED TO ORIGINAL CODE ---
            SizedBox(
              height: 300,
              width: double.infinity,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourcompany.gatewayapp',
                  ),
                  if (hasLocation)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(gateway.latitude, gateway.longitude),
                          width: 45,
                          height: 45,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: getIconColor(), width: 2),
                            ),
                            child: Icon(
                              Icons.router,
                              color: getIconColor(),
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER: CARD ---
  Widget _buildInfoCard({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  // --- HELPER: RICH TEXT ---
  Widget _buildRichText(String label, String value, Color textColor, Color labelColor) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 15, color: textColor),
        children: [
          TextSpan(
            text: "$label: ",
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.normal, color: labelColor),
          ),
        ],
      ),
    );
  }

  // --- HELPER: STATUS BADGE ---
  Widget _buildStatusBadge(String state, Color textColor) {
    Color statusColor;
    String statusText;

    switch (state.toUpperCase()) {
      case 'ONLINE':
        statusColor = AppColors.green;
        statusText = "Online";
        break;
      case 'OFFLINE':
        statusColor = AppColors.red;
        statusText = "Offline";
        break;
      default:
        statusColor = AppColors.orange;
        statusText = "Never Seen";
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // --- HELPER: DATE FORMATTER ---
  String _formatDate(String isoString) {
    if (isoString.isEmpty) return "N/A";
    try {
      DateTime utcTime = DateTime.parse(isoString);
      DateTime localTime = utcTime.add(const Duration(hours: 7));
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(localTime);
    } catch (e) {
      return isoString;
    }
  }
}