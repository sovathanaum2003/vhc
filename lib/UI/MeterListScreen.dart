import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Color/AppColor.dart';
import '../MQTT/MqttService.dart';

/// ======================================================
/// DATA MODEL
/// ======================================================
class MeterData {
  final int index;
  String? sn;
  int? mType;
  int? status;
  int? reserve;

  double? voltage;
  double? current;
  double? energy;
  String? lastRead;

  MeterData({
    required this.index,
    this.sn,
    this.mType,
    this.status = 1,
    this.reserve = 0,
  });

  bool get isOnline => status == 1;
}

/// ======================================================
/// METER LIST SCREEN
/// ======================================================
class MeterListScreen extends StatefulWidget {
  final MqttService mqttService;
  final String devEui;
  final String appId;
  final Map<String, dynamic> variables;

  const MeterListScreen({
    super.key,
    required this.mqttService,
    required this.devEui,
    required this.appId,
    required this.variables,
  });

  @override
  State<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends State<MeterListScreen> {
  // --- STATE VARIABLES ---
  late StreamSubscription _messageSubscription;
  final TextEditingController _searchController = TextEditingController();

  List<MeterData> _meterList = [];
  List<MeterData> _filteredMeters = [];
  final Set<int> _expandedMeters = {};

  bool _isLoading = true;

  String get _pubTopic => "application/${widget.appId}/device/${widget.devEui}/command/down";

  @override
  void initState() {
    super.initState();
    _messageSubscription = widget.mqttService.messageStream.listen(_handleIncomingMessage);
    _searchController.addListener(_applyFilters);

    // Instantly parse local data for a fast-response UI
    _parseVariablesToMeterList();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOCAL DATA PARSER (FAST RESPONSE)
  // ==========================================
  void _parseVariablesToMeterList() {
    _meterList.clear();

    widget.variables.forEach((key, value) {
      if (key.startsWith('Meter_')) {
        int? index = int.tryParse(key.split('_')[1]);
        if (index != null) {
          String valStr = value.toString();

          if (valStr == 'Empty Slot' || valStr == 'Waiting for Sync...') {
            _meterList.add(MeterData(index: index, sn: null, mType: null));
          } else {
            // Expected format: sn,type,status,reserve
            List<String> parts = valStr.split(',');
            String sn = parts.isNotEmpty ? parts[0] : "";
            int mType = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
            int status = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
            int reserve = parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0;

            _meterList.add(MeterData(
              index: index,
              sn: sn,
              mType: mType,
              status: status,
              reserve: reserve,
            ));
          }
        }
      }
    });

    _meterList.sort((a, b) => a.index.compareTo(b.index));
    _applyFilters();

    setState(() {
      _isLoading = false;
    });
  }

  // ==========================================
  // HELPERS & FILTERING
  // ==========================================
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return num.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  // Helper to map Integer Type to String Name
  String _getMeterTypeName(int? type) {
    if (type == 1) return "SX4-A43E";
    if (type == 2) return "EDMI-Mk31";
    return type?.toString() ?? "Unknown";
  }

  void _publish(Map<String, dynamic> payload) {
    widget.mqttService.publish(_pubTopic, jsonEncode(payload));
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMeters = List.from(_meterList);
      } else {
        _filteredMeters = _meterList.where((m) {
          final snMatch = m.sn?.toLowerCase().contains(query) ?? false;
          final idMatch = m.index.toString().contains(query);
          return snMatch || idMatch;
        }).toList();
      }
    });
  }

  // ==========================================
  // DOWNLINK COMMANDS (MQTT)
  // ==========================================
  void _requestStep3_Data(MeterData m) {
    _publish({
      "devEui": widget.devEui,
      "confirmed": false,
      "fPort": 12,
      "object": {"sn": m.sn ?? "", "m_type": m.mType ?? 1, "no_index": m.index, "status": 1, "reserve": 0}
    });
  }

  // ==========================================
  // INCOMING MQTT DATA HANDLER
  // ==========================================
  void _handleIncomingMessage(String jsonString) {
    if (!mounted) return;

    try {
      final json = jsonDecode(jsonString);
      if (!json.containsKey('fPort')) return;

      final port = _toInt(json['fPort']);

      if (port == 12) {
        // Live Data (Voltage, Current, Energy)
        final meters = json['object']?['meters'];
        if (meters != null && meters.isNotEmpty) {
          final data = meters[0];
          final sn = data['sn'].toString();

          final idx = _meterList.indexWhere((m) => m.sn == sn);
          if (idx != -1) {
            setState(() {
              final m = _meterList[idx];
              m.voltage = _toDouble(data['voltage']);
              m.current = _toDouble(data['current']);
              m.energy = _toDouble(data['energy']);
              m.lastRead = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
            });
            _applyFilters();
          }
        }
      }
    } catch (e) {
      debugPrint("Parse error: $e");
    }
  }

  // ==========================================
  // UI LOGIC
  // ==========================================
  void _toggleExpand(MeterData m) {
    setState(() {
      if (_expandedMeters.contains(m.index)) {
        _expandedMeters.remove(m.index);
      } else {
        _expandedMeters.add(m.index);
        if (m.sn != null && m.sn!.isNotEmpty) {
          // Clear old data to trigger loading animations
          m.voltage = null;
          m.current = null;
          m.energy = null;
          m.lastRead = null;
          // Request fresh electrical data
          _requestStep3_Data(m);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot fetch data: No valid Serial Number yet")),
          );
        }
      }
    });
  }

  // ==========================================
  // BUILD METHOD & COMPONENTS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);
    final labelColor = AppColors.secondaryText(context);

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
        iconTheme: IconThemeData(color: headerTextColor),
        title: Text("Meter List", style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      // appBar: AppBar(
      //   backgroundColor: headerColor,
      //   elevation: 0,
      //   centerTitle: false,
      //   titleSpacing: 0,
      //   leading: IconButton(
      //     icon: Icon(Icons.arrow_back, color: headerTextColor),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      //   title: Text(
      //       "Meter List",
      //       style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w500, fontSize: 18)
      //   ),
      // ),
      body: Column(
        children: [
          _buildSearchBar(textColor, labelColor),
          Expanded(child: _buildListContent(textColor, cardColor)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color textColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "Search",
            hintStyle: TextStyle(color: labelColor),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: AppColors.cardBackground(context),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: AppColors.accentColor(context), width: 1.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(Color textColor, Color cardColor) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
        ],
      );
    }

    if (_filteredMeters.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
              height: 300,
              child: Center(
                  child: Text("No meters found.", textAlign: TextAlign.center, style: TextStyle(color: textColor, height: 1.5))
              )
          )
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredMeters.length,
      itemBuilder: (context, index) {
        return _buildMeterCard(_filteredMeters[index], textColor, cardColor);
      },
    );
  }

  Widget _buildMeterCard(MeterData m, Color textColor, Color cardColor) {
    bool isExpanded = _expandedMeters.contains(m.index);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isExpanded ? null : () => _toggleExpand(m),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isExpanded ? _buildExpandedContent(m, textColor) : _buildCollapsedContent(m, textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(MeterData m, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text("${m.index}. Meter SN: ", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (m.sn == null || m.sn!.isEmpty)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentColor(context)))
                  else
                    Text(m.sn!, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.normal)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text("    Type: ", style: TextStyle(color: textColor, fontSize: 14)),
                  if (m.mType == null)
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentColor(context)))
                  else
                    Text(_getMeterTypeName(m.mType), style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (m.status == 0)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("Disabled", style: TextStyle(fontSize: 10, color: AppColors.red, fontWeight: FontWeight.bold)),
              ),
            Icon(Icons.keyboard_arrow_down, color: textColor),
          ],
        )
      ],
    );
  }

  Widget _buildExpandedContent(MeterData m, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("${m.index}. Meter SN: ", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                if (m.sn == null || m.sn!.isEmpty)
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentColor(context)))
                else
                  Text(m.sn!, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.normal)),
              ],
            ),
            GestureDetector(
              onTap: () => _toggleExpand(m),
              child: Container(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Icon(Icons.keyboard_arrow_up, color: textColor, size: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDataRow("Last read:", m.lastRead, textColor),
        const SizedBox(height: 12),
        _buildDataRow("Voltage:", m.voltage, textColor, suffix: " V"),
        const SizedBox(height: 12),
        _buildDataRow("Current:", m.current, textColor, suffix: " A"),
        const SizedBox(height: 12),
        _buildDataRow("Energy:", m.energy, textColor, suffix: " kWh"),
      ],
    );
  }

  Widget _buildDataRow(String label, dynamic value, Color textColor, {String suffix = ""}) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
        if (value == null)
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentColor(context)))
        else
          Expanded(child: Text("$value$suffix", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}