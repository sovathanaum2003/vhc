import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
import '../MQTT/MqttService.dart';
import '../Services/DeviceDetailService.dart';
import 'MeterListScreen.dart';

// ==========================================
// DATA MODEL
// ==========================================
class MeterData {
  final int index;
  String? sn;
  int? mType;
  int? status;
  int? reserve;

  MeterData({
    required this.index,
    this.sn,
    this.mType,
    this.status,
    this.reserve,
  });
}

// ==========================================
// SCREEN WIDGET
// ==========================================
class DeviceDetailScreen extends StatefulWidget {
  final String devEui;
  final String applicationId;

  const DeviceDetailScreen({
    super.key,
    required this.devEui,
    required this.applicationId,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // --- REST API STATE ---
  Map<String, dynamic>? _deviceData;
  String? _lastSeenAt;

  Map<String, dynamic> _variables = {};
  Map<String, dynamic> _variablesBackup = {};

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // --- MQTT STATE ---
  final MqttService _mqttService = MqttService();
  final String _broker = "96.9.77.67";
  final int _port = 1883;

  bool _isMqttConnected = false;

  // Section visibility states
  bool _showMqttSection = false;
  bool _hasRequestedDeviceInfo = false;
  bool _hasRequestedMeterInfo = false;

  // Data Arrays
  final Map<int, String> _mqttInfoData = {};
  final List<MeterData> _meterList = [];

  // --- TIMEOUT TIMERS ---
  Timer? _deviceInfoTimer;
  Timer? _meterInfoTimer;

  String get _subTopic => "application/${widget.applicationId}/device/${widget.devEui}/event/up";
  String get _pubTopic => "application/${widget.applicationId}/device/${widget.devEui}/command/down";

  // --- DERIVED LOADING STATES (Waits for data to actually arrive) ---
  bool get _isFetchingDeviceInfo => _hasRequestedDeviceInfo && _mqttInfoData.length < 6;
  bool get _isFetchingMetersInfo => _hasRequestedMeterInfo && (_meterList.isEmpty || _meterList.any((m) => m.sn == null));

  @override
  void initState() {
    super.initState();
    _fetchDeviceDetails();
    _mqttService.messageStream.listen(_handleMqttMessage);
  }

  @override
  void dispose() {
    _deviceInfoTimer?.cancel();
    _meterInfoTimer?.cancel();
    if (_isMqttConnected) {
      _mqttService.disconnect();
    }
    super.dispose();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return num.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  // ==========================================
  // REST API LOGIC
  // ==========================================

  Future<void> _fetchDeviceDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await DeviceDetailService.fetchDevice(widget.devEui);
      if (mounted) {
        setState(() {
          _deviceData = data["device"];
          _lastSeenAt = data["lastSeenAt"];
          _variables = Map<String, dynamic>.from(_deviceData?["variables"] ?? {});
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Failed to load device info.");
      }
    }
  }

  Future<void> _saveDevice() async {
    if (_deviceData == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await DeviceDetailService.updateDevice(
        widget.devEui,
        _deviceData!,
        _variables,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          if (success) _isEditing = false;
        });
        _showSnackBar(
            success ? "Device updated successfully" : "Failed to update device",
            isError: !success
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar("There are errors.");
      }
    }
  }

  // ==========================================
  // MQTT LOGIC
  // ==========================================

  Future<bool> _connectMqtt() async {
    if (_isMqttConnected) return true;

    final ok = await _mqttService.connect(
      _broker,
      _port,
      "flutter_client_${widget.devEui}_${DateTime.now().millisecondsSinceEpoch}",
    );

    if (ok) {
      _mqttService.subscribe(_subTopic);
      _isMqttConnected = true;
    }
    return ok;
  }

  // --- DEVICE INFO LOGIC WITH SLIDING TIMEOUT ---

  void _startDeviceInfoTimeout() {
    _deviceInfoTimer?.cancel();
    _deviceInfoTimer = Timer(const Duration(seconds: 100), () {
      if (mounted && _isFetchingDeviceInfo) {
        setState(() {
          _hasRequestedDeviceInfo = false;
          if (!_hasRequestedMeterInfo) _showMqttSection = false;
        });
        _showSnackBar("Can't Get Device Info", isError: true);
      }
    });
  }

  Future<void> _fetchMqttDeviceInfo() async {
    setState(() {
      _mqttInfoData.clear();
      _showMqttSection = true;
      _hasRequestedDeviceInfo = true;
    });

    bool connected = await _connectMqtt();
    if (!connected) {
      if (mounted) {
        setState(() => _hasRequestedDeviceInfo = false);
        _showSnackBar("Failed to connect to MQTT Broker", isError: true);
      }
      return;
    }

    // Start the first 100s timeout window
    _startDeviceInfoTimeout();

    final ports = [14, 15, 17, 18, 19, 20];
    for (int p in ports) {
      _mqttService.publish(_pubTopic, jsonEncode({
        "devEui": widget.devEui,
        "confirmed": false,
        "data": "",
        "fPort": p
      }));
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // --- METER INFO LOGIC WITH SLIDING TIMEOUT ---

  void _startMeterInfoTimeout() {
    _meterInfoTimer?.cancel();
    _meterInfoTimer = Timer(const Duration(seconds: 100), () {
      if (mounted && _isFetchingMetersInfo) {
        setState(() {
          _hasRequestedMeterInfo = false;
          if (!_hasRequestedDeviceInfo) _showMqttSection = false;
          _meterList.clear();
        });
        _showSnackBar("Can't Get Meter Info", isError: true);
      }
    });
  }

  Future<void> _syncMeterList() async {
    setState(() {
      _meterList.clear();
      _showMqttSection = true;
      _hasRequestedMeterInfo = true;
    });

    bool connected = await _connectMqtt();
    if (!connected) {
      if (mounted) {
        setState(() => _hasRequestedMeterInfo = false);
        _showSnackBar("Failed to connect to MQTT Broker", isError: true);
      }
      return;
    }

    // Start the first 100s timeout window for fetching the total count
    _startMeterInfoTimeout();

    _mqttService.publish(_pubTopic, jsonEncode({
      "devEui": widget.devEui,
      "confirmed": false,
      "fPort": 30,
      "object": {"sn": "", "m_type": 0, "no_index": 0, "status": 1, "reserve": 0}
    }));
  }

  void _requestMeterDetails(int count) async {
    for (int i = 1; i <= count; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mqttService.publish(_pubTopic, jsonEncode({
        "devEui": widget.devEui,
        "confirmed": false,
        "fPort": 10,
        "object": {"sn": "", "m_type": 0, "no_index": i, "status": 1, "reserve": 0}
      }));
    }
  }

  void _uploadMqttToVariables() {
    setState(() {
      if (_hasRequestedDeviceInfo) {
        final ports = [14, 15, 17, 18, 19, 20];
        for (int p in ports) {
          if (_mqttInfoData.containsKey(p)) {
            _variables[_labelForPort(p)] = _mqttInfoData[p];
          }
        }
      }

      if (_hasRequestedMeterInfo && _meterList.isNotEmpty) {
        for (var m in _meterList) {
          String info = "Waiting for Sync...";
          if (m.sn != null && m.sn!.isNotEmpty) {
            info = "${m.sn},${m.mType},${m.status},${m.reserve}";
          } else if (m.sn != null && m.sn!.isEmpty) {
            info = "Empty Slot";
          }
          _variables["Meter_${m.index}"] = info;
        }
      }

      _isEditing = true;
      _showMqttSection = false;
      _hasRequestedDeviceInfo = false;
      _hasRequestedMeterInfo = false;
    });

    _showSnackBar("Data moved to variables. Press 'Save' to upload to server.");
  }

  void _handleMqttMessage(String jsonString) {
    if (!mounted) return;
    try {
      final json = jsonDecode(jsonString);
      if (!json.containsKey('fPort')) return;

      final port = json['fPort'] is String ? int.tryParse(json['fPort']) : json['fPort'];

      if (port == null) return;

      if ([14, 15, 17, 18, 19, 20].contains(port)) {
        final val = json['object']?['value']?.toString();
        if (val != null) {
          setState(() {
            _mqttInfoData[port] = val;

            // RESET the sliding window timer because we just received a piece of data
            if (_isFetchingDeviceInfo) {
              _startDeviceInfoTimeout();
            } else {
              _deviceInfoTimer?.cancel(); // Cancel entirely if everything is done
            }
          });
        }
      } else if (port == 30) {
        final count = _toInt(json['object']?['value']);
        setState(() {
          _meterList.clear();
          _meterList.addAll(List.generate(count, (i) => MeterData(index: i + 1, sn: null)));
        });

        // RESET the sliding window timer because we received the count successfully
        _startMeterInfoTimeout();

        _requestMeterDetails(count);
      } else if (port == 10 || port == 11) {
        final obj = json['object'];
        if (obj == null) return;

        final rxIndex = _toInt(obj['no_index']);
        final rxSn = obj['sn']?.toString() ?? "";
        final rxStatus = _toInt(obj['status']);
        final rxType = _toInt(obj['m_type']);
        final rxReserve = _toInt(obj['reserve']);

        setState(() {
          final idx = _meterList.indexWhere((m) => m.index == rxIndex);
          if (idx != -1) {
            final m = _meterList[idx];
            m.sn = rxSn;
            m.mType = rxType;
            m.status = rxStatus;
            m.reserve = rxReserve;
          } else {
            _meterList.add(MeterData(index: rxIndex, sn: rxSn, mType: rxType, status: rxStatus, reserve: rxReserve));
            _meterList.sort((a, b) => a.index.compareTo(b.index));
          }

          // RESET the sliding window timer because we received a meter detail
          if (_isFetchingMetersInfo) {
            _startMeterInfoTimeout();
          } else {
            _meterInfoTimer?.cancel(); // Cancel entirely if everything is done
          }
        });
      }
    } catch (e) {
      // debugPrint("MQTT Parse Error: $e");
      debugPrint("MQTT Parse Error");
    }
  }

  // ==========================================
  // UI HELPERS
  // ==========================================

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 16,
          right: 16,
        ),
        dismissDirection: DismissDirection.up,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _calculateStatus(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "Never seen";
    try {
      DateTime seen = DateTime.parse(isoDate);
      Duration diff = DateTime.now().toUtc().difference(seen);
      return diff.inMinutes <= 60 ? "Active" : "Inactive";
    } catch (e) {
      return "Never seen";
    }
  }

  String _formatPhnomPenhTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "___________";
    try {
      DateTime utcTime = DateTime.parse(isoString);
      DateTime phnomPenhTime = utcTime.add(const Duration(hours: 7));
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      return "${phnomPenhTime.year}-${twoDigits(phnomPenhTime.month)}-${twoDigits(phnomPenhTime.day)} "
          "${twoDigits(phnomPenhTime.hour)}:${twoDigits(phnomPenhTime.minute)}:${twoDigits(phnomPenhTime.second)}";
    } catch (e) {
      return isoString;
    }
  }

  String _labelForPort(int port) {
    switch (port) {
      case 14: return "Firmware Version";
      case 15: return "Hardware Version";
      case 17: return "Install Date";
      case 18: return "Latitude";
      case 19: return "Longitude";
      case 20: return "Pole Name";
      default: return "Port $port";
    }
  }

  void _showAddVariableDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBtnColor = isDark ? AppColors.accentColor(context) : const Color(0xFF001439);

    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground(context),
        title: Text("Add Variable", style: TextStyle(color: AppColors.primaryText(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: keyController,
                style: TextStyle(color: AppColors.primaryText(context)),
                decoration: InputDecoration(
                    labelText: "Key",
                    labelStyle: TextStyle(color: AppColors.secondaryText(context)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondaryText(context)))
                )
            ),
            TextField(
                controller: valueController,
                style: TextStyle(color: AppColors.primaryText(context)),
                decoration: InputDecoration(
                    labelText: "Value",
                    labelStyle: TextStyle(color: AppColors.secondaryText(context)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondaryText(context)))
                )
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: AppColors.secondaryText(context)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBtnColor),
            onPressed: () {
              if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                setState(() => _variables[keyController.text.trim()] = valueController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD METHOD & UI COMPONENTS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);

    const Color specificBrightBlue = Color(0xFF9FCCFF);
    final headerColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue;
    final cardColor = isDark ? AppColors.cardBackground(context) : specificBrightBlue.withOpacity(0.3);
    final headerTextColor = isDark ? Colors.white : Colors.black;

    final primaryBtnColor = isDark ? AppColors.accentColor(context) : const Color(0xFF001439);
    final meterListBtnColor = isDark ? AppColors.cardBackground(context) : const Color(0xFF001439);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: headerTextColor),
        title: Text("Device Detail", style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBtnColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceOverviewCard(textColor, cardColor),
            const SizedBox(height: 24),
            _buildVariablesSectionHeader(textColor),
            const SizedBox(height: 12),
            _buildVariablesCard(textColor, cardColor, primaryBtnColor),
            if (_showMqttSection) ...[
              const SizedBox(height: 24),
              _buildMqttSection(textColor, cardColor, primaryBtnColor),
            ],
            const SizedBox(height: 20),
            _buildMeterListButton(meterListBtnColor),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceOverviewCard(Color textColor, Color cardColor) {
    String statusText = _calculateStatus(_lastSeenAt);
    Color statusColor = statusText == "Active" ? AppColors.green : (statusText == "Inactive" ? AppColors.red : AppColors.orange);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: textColor, fontSize: 16),
                    children: [
                      const TextSpan(text: "Device Name: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _deviceData?["name"] ?? "Unknown"),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          RichText(
              text: TextSpan(style: TextStyle(color: textColor, fontSize: 15), children: [
                const TextSpan(text: "EUI: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: widget.devEui)
              ])
          ),
          const SizedBox(height: 16),
          RichText(
              text: TextSpan(style: TextStyle(color: textColor, fontSize: 15), children: [
                const TextSpan(text: "Last seen: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: _formatPhnomPenhTime(_lastSeenAt))
              ])
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesSectionHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Device information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: textColor, size: 24),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardBackground(context)
              : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (value) {
            if (value == 'edit') {
              setState(() {
                _isEditing = true;
                _variablesBackup = Map.from(_variables);
              });
            } else if (value == 'get_device_info') {
              _fetchMqttDeviceInfo();
            } else if (value == 'get_meter_info') {
              _syncMeterList();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: textColor))),
            PopupMenuItem(value: 'get_device_info', child: Text('Get Device Info', style: TextStyle(color: textColor))),
            PopupMenuItem(value: 'get_meter_info', child: Text('Get Meter Info', style: TextStyle(color: textColor))),
          ],
        ),
      ],
    );
  }

  Widget _buildVariablesCard(Color textColor, Color cardColor, Color primaryBtnColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_variables.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No variables configured.", style: TextStyle(color: textColor))
            ),
          ..._variables.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(entry.key, style: TextStyle(color: textColor, fontSize: 15))),
                  Expanded(flex: 3, child: Text(entry.value.toString(), style: TextStyle(color: textColor, fontSize: 15))),
                  if (_isEditing)
                    InkWell(
                        onTap: () => setState(() => _variables.remove(entry.key)),
                        child: Icon(Icons.remove_circle_outline, color: primaryBtnColor, size: 20)
                    ),
                ],
              ),
            );
          }),

          if (_isEditing) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryBtnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: _showAddVariableDialog,
                        child: const Text("Add", style: TextStyle(color: Colors.white))
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryBtnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: _isSaving ? null : _saveDevice,
                        child: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Save", style: TextStyle(color: Colors.white))
                    ),
                  ],
                ),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground(context),
                        side: BorderSide(color: primaryBtnColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    onPressed: () {
                      setState(() {
                        _variables = Map.from(_variablesBackup);
                        _isEditing = false;
                      });
                    },
                    child: Text("Cancel", style: TextStyle(color: primaryBtnColor))
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMqttSection(Color textColor, Color cardColor, Color primaryBtnColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("The device Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                if (_isFetchingDeviceInfo || _isFetchingMetersInfo)
                  Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBtnColor))
                  )
              ],
            ),
            if ((!_isFetchingDeviceInfo && !_isFetchingMetersInfo) && (_hasRequestedDeviceInfo || _hasRequestedMeterInfo))
              ElevatedButton.icon(
                icon: const Icon(Icons.upload, size: 16, color: Colors.white),
                label: const Text("Upload", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBtnColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _uploadMqttToVariables,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasRequestedDeviceInfo) ...[
                ...[14, 15, 17, 18, 19, 20].map((port) {
                  final label = _labelForPort(port);

                  final hasValue = _mqttInfoData.containsKey(port);
                  final value = _mqttInfoData[port] ?? "";

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text("$label:", style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
                        Expanded(
                            flex: 3,
                            child: !hasValue
                                ? Align(alignment: Alignment.centerLeft, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBtnColor)))
                                : Text(value, style: TextStyle(color: primaryBtnColor, fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (_hasRequestedDeviceInfo && _hasRequestedMeterInfo)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: textColor.withOpacity(0.2), height: 1),
                ),

              if (_hasRequestedMeterInfo) ...[
                Text("Meter Registry Summary", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondaryText(context))),
                const SizedBox(height: 8),

                if (_meterList.isEmpty)
                  Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBtnColor)),
                      const SizedBox(width: 8),
                      Text("Fetching meter count...", style: TextStyle(color: textColor)),
                    ],
                  )
                else
                  ..._meterList.map((m) {
                    String info = "";

                    bool isLoadingMeter = m.sn == null;

                    if (!isLoadingMeter) {
                      if (m.sn!.isEmpty) {
                        info = "Empty Slot";
                      } else {
                        info = "${m.sn},${m.mType},${m.status},${m.reserve}";
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: Text("Meter_${m.index}:", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 3,
                              child: isLoadingMeter
                                  ? Align(alignment: Alignment.centerLeft, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBtnColor)))
                                  : Text(info, style: TextStyle(fontFamily: 'monospace', color: primaryBtnColor, fontWeight: FontWeight.w600))
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeterListButton(Color meterListBtnColor) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: meterListBtnColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: () async {
          bool connected = await _connectMqtt();
          if (connected && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeterListScreen(
                  mqttService: _mqttService,
                  devEui: widget.devEui,
                  appId: widget.applicationId,
                  variables: _variables,
                ),
              ),
            );
          } else if (!connected && mounted) {
            _showSnackBar("Failed to connect to MQTT Broker", isError: true);
          }
        },
        child: const Text("Meter List", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}