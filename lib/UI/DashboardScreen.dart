import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../Color/AppColor.dart';
import '../Services/DashboardService.dart';
import '../Model/GatewayModel.dart';

class DashboardScreen extends StatefulWidget {
  final String tenantId;

  const DashboardScreen({super.key, required this.tenantId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? _summary;
  bool _isInitialLoading = true;
  String? _errorMessage;

  String _mapFilterType = 'All';
  String _mapFilterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final summary = await DashboardService.getSummary(widget.tenantId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isInitialLoading = false;
        });
      }
    }
  }

  List<Gateway> get _filteredGateways {
    if (_summary == null || _mapFilterType == 'Devices') return [];

    return _summary!.gateways.where((g) {
      if (g.latitude == 0.0 && g.longitude == 0.0) return false;
      if (_mapFilterStatus == 'All') return true;

      final state = g.state.toUpperCase();
      if (_mapFilterStatus == 'Active/Online' && state == 'ONLINE') return true;
      if (_mapFilterStatus == 'Inactive/Offline' && state == 'OFFLINE') return true;
      if (_mapFilterStatus == 'Never seen' && state != 'ONLINE' && state != 'OFFLINE') return true;
      return false;
    }).toList();
  }

  List<DeviceLocation> get _filteredDevices {
    if (_summary == null || _mapFilterType == 'Gateways') return [];

    return _summary!.deviceLocations.where((d) {
      if (d.latitude == 0.0 && d.longitude == 0.0) return false;
      if (_mapFilterStatus == 'All') return true;

      if (_mapFilterStatus == 'Active/Online' && d.status == 'Active') return true;
      if (_mapFilterStatus == 'Inactive/Offline' && d.status == 'Inactive') return true;
      if (_mapFilterStatus == 'Never seen' && d.status == 'Never seen') return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);

    const Color specificBrightBlue = Color(0xFF9FCCFF);
    final headerColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue;
    final cardColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue.withOpacity(0.3);
    final headerTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "Dashboard",
          style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: _buildBodyContent(cardColor, textColor, headerTextColor),
    );
  }

  Widget _buildBodyContent(Color cardColor, Color textColor, Color headerTextColor) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _summary == null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Active Devices", headerTextColor),
                  StatCardWidget(
                    cardColor: cardColor,
                    textColor: textColor,
                    labels: const ["Active", "Inactive", "Never seen"],
                    values: [
                      _summary!.activeDevices,
                      _summary!.inactiveDevices,
                      _summary!.neverSeenDevices,
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSectionHeader("Active Gateways", headerTextColor),
                  StatCardWidget(
                    cardColor: cardColor,
                    textColor: textColor,
                    labels: const ["Online", "Offline", "Never seen"],
                    values: [
                      _summary!.onlineGateways,
                      _summary!.offlineGateways,
                      _summary!.neverSeenGateways,
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSectionHeader("Map View", headerTextColor),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _mapFilterType,
                          items: ['All', 'Gateways', 'Devices'],
                          onChanged: (val) => setState(() => _mapFilterType = val!),
                          bgColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _mapFilterStatus,
                          items: ['All', 'Active/Online', 'Inactive/Offline', 'Never seen'],
                          onChanged: (val) => setState(() => _mapFilterStatus = val!),
                          bgColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildMapSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 16),
            Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.red, fontSize: 16)
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _isInitialLoading = true);
                _fetchDashboardData();
              },
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: textColor),
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardBackground(context)
              : Colors.white,
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(value: val, child: Text(val));
          }).toList(),
        ),
      ),
    );
  }

  // REVERTED TO ORIGINAL MAP CODE
  Widget _buildMapSection() {
    final filteredGateways = _filteredGateways;
    final filteredDevices = _filteredDevices;

    // Default to Phnom Penh if nothing is available
    LatLng initialCenter = const LatLng(11.5564, 104.9282);
    if (filteredDevices.isNotEmpty) {
      initialCenter = LatLng(filteredDevices.first.latitude, filteredDevices.first.longitude);
    } else if (filteredGateways.isNotEmpty) {
      initialCenter = LatLng(filteredGateways.first.latitude, filteredGateways.first.longitude);
    }

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 12.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vh.technology',
          ),
          MarkerLayer(
            markers: [
              ...filteredDevices.map((dev) {
                Color getDeviceColor() {
                  switch (dev.status) {
                    case 'Active': return AppColors.green;
                    case 'Inactive': return AppColors.red;
                    default: return AppColors.orange;
                  }
                }
                return Marker(
                  point: LatLng(dev.latitude, dev.longitude),
                  width: 20, height: 20,
                  child: Tooltip(
                    message: "Device: ${dev.name}\nStatus: ${dev.status}",
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: getDeviceColor(), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2)],
                      ),
                      child: Icon(Icons.sensors, color: getDeviceColor(), size: 12),
                    ),
                  ),
                );
              }),
              ...filteredGateways.map((gw) {
                Color getIconColor() {
                  switch (gw.state.toUpperCase()) {
                    case 'ONLINE': return AppColors.green;
                    case 'OFFLINE': return AppColors.red;
                    default: return AppColors.orange;
                  }
                }
                return Marker(
                  point: LatLng(gw.latitude, gw.longitude),
                  width: 30, height: 30,
                  child: Tooltip(
                    message: "Gateway: ${gw.name}\nStatus: ${gw.state}",
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: getIconColor(), width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                      ),
                      child: Icon(Icons.router, color: getIconColor(), size: 16),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// --- STATIC WIDGETS ---

class StatCardWidget extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final List<String> labels;
  final List<int> values;

  const StatCardWidget({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> sectionColors = [AppColors.green, AppColors.red, AppColors.orange];
    final int total = values.fold<int>(0, (sum, element) => sum + element);

    final List<int> displayValues = total == 0 ? [1, 0, 0] : values;
    final List<Color> displayColors = total == 0
        ? [Colors.grey.shade400, Colors.transparent, Colors.transparent]
        : sectionColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(labels.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(width: 12, height: 6, color: sectionColors[index]),
                      const SizedBox(width: 8),
                      Text(labels[index], style: TextStyle(color: textColor, fontSize: 14)),
                    ],
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: DonutChartPainter(
                values: displayValues,
                colors: displayColors,
                isZeroState: total == 0,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final bool isZeroState;

  DonutChartPainter({required this.values, required this.colors, this.isZeroState = false});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold<int>(0, (sum, element) => sum + element).toDouble();
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 35.0;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double startAngle = -pi / 2;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double textRadius = (size.width - strokeWidth) / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0 && !isZeroState) continue;

      final double sweepAngle = isZeroState ? 2 * pi : (values[i] / total) * 2 * pi;
      paint.color = colors[i];

      canvas.drawArc(rect.deflate(strokeWidth / 2), startAngle, sweepAngle, false, paint);

      if (!isZeroState && values[i] > 0) {
        final double midAngle = startAngle + sweepAngle / 2;
        final double textX = cx + textRadius * cos(midAngle);
        final double textY = cy + textRadius * sin(midAngle);

        final textSpan = TextSpan(
          text: '${values[i]}',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
        );
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}