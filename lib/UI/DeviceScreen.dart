import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
import '../Model/DeviceModel.dart';
import '../Services/DeviceService.dart';
import 'DeviceDetailScreen.dart';

class DeviceScreen extends StatefulWidget {
  final String applicationId;
  // Accept the future triggered from the previous screen
  final Future<List<DeviceModel>>? preloadedFuture;

  const DeviceScreen({super.key, required this.applicationId, this.preloadedFuture});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  // --- State Variables ---
  List<DeviceModel> _devices = [];
  List<DeviceModel> _filteredDevices = [];

  bool _isInitialLoading = true; // Prevents UI wiping on pull-to-refresh
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);

    // If we have a pre-triggered future from the previous screen, use it
    if (widget.preloadedFuture != null) {
      _handlePreloadedFuture();
    } else {
      _fetchDevices();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---
  Future<void> _handlePreloadedFuture() async {
    try {
      final devices = await widget.preloadedFuture!;
      if (mounted) {
        setState(() {
          _devices = devices;
          _filteredDevices = devices;
          _isInitialLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      // If the early future fails, fall back to standard fetch to handle UI errors natively
      _fetchDevices();
    }
  }

  Future<void> _fetchDevices({bool forceRefresh = false}) async {
    // Only clear the error, keep _isInitialLoading untouched to maintain the UI during refresh
    setState(() {
      _errorMessage = null;
    });

    try {
      // Pass forceRefresh so pull-to-refresh gets fresh data instead of cache
      final devices = await DeviceService.getDevices(widget.applicationId, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _devices = devices;
          _filteredDevices = devices;
          _isInitialLoading = false;
        });
        // Re-apply filters in case the user searched while data was fetching
        _applyFilters();
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

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDevices = _devices.where((device) {
        final matchesSearch = device.name.toLowerCase().contains(query) ||
            device.devEui.toLowerCase().contains(query);

        String status = _calculateStatus(device.lastSeenAt);
        bool matchesFilter = true;

        if (_filterStatus != 'All') {
          if (_filterStatus == 'Active') matchesFilter = status == 'Active';
          else if (_filterStatus == 'Inactive') matchesFilter = status == 'Inactive';
          else if (_filterStatus == 'Never Seen') matchesFilter = status == 'Never seen';
        }
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  // --- Utility Methods ---
  String _calculateStatus(String isoDate) {
    if (isoDate.isEmpty) return "Never seen";
    try {
      DateTime seen = DateTime.parse(isoDate);
      Duration diff = DateTime.now().toUtc().difference(seen);
      // Active if seen within the last 60 minutes (1 hour)
      return diff.inMinutes <= 60 ? "Active" : "Inactive";
    } catch (e) {
      return "Never seen";
    }
  }

  String _formatPhnomPenhTime(String isoString) {
    if (isoString.isEmpty) return "___________";
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

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);
    final labelColor = AppColors.secondaryText(context);

    // Specific Design Colors matching the rest of the app
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
        title: Text(
          "Device",
          style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: Column(
        children: [
          _buildFilterAndSearchRow(textColor, labelColor),
          Expanded(child: _buildListContent(textColor, cardColor)),
        ],
      ),
    );
  }

  // --- UI Components ---
  Widget _buildFilterAndSearchRow(Color textColor, Color labelColor) {
    final bool isFilterActive = _filterStatus != 'All';
    final Color activeFilterColor = isFilterActive ? AppColors.accentColor(context) : AppColors.iconColor(context);

    Color getFilterTextColor(String status) {
      return _filterStatus == status ? AppColors.accentColor(context) : textColor;
    }

    return Padding(
      // Exactly 16px margin on all outer edges
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Filter Dropdown Button
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.filter_alt_outlined, color: activeFilterColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  onSelected: (String value) {
                    setState(() => _filterStatus = value);
                    _applyFilters();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'All', child: Text('All', style: TextStyle(color: getFilterTextColor('All')))),
                    PopupMenuItem(value: 'Active', child: Text('Active', style: TextStyle(color: getFilterTextColor('Active')))),
                    PopupMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(color: getFilterTextColor('Inactive')))),
                    PopupMenuItem(value: 'Never Seen', child: Text('Never Seen', style: TextStyle(color: getFilterTextColor('Never Seen')))),
                  ],
                ),
              ),
              const SizedBox(width: 16), // 16px margin between filter button and search field

              // Search Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                    ],
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: AppColors.accentColor(context), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Active Filter Chip Indicator
          if (_filterStatus != 'All')
            Padding(
              // 16px top margin to maintain clean spacing when active
              padding: const EdgeInsets.only(top: 16, left: 66),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentColor(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt, size: 14, color: AppColors.accentColor(context)),
                        const SizedBox(width: 6),
                        Text(
                          "Filter: $_filterStatus",
                          style: TextStyle(color: AppColors.accentColor(context), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterStatus = 'All';
                              _applyFilters();
                            });
                          },
                          child: Icon(Icons.close, size: 14, color: AppColors.accentColor(context)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListContent(Color textColor, Color cardColor) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.red, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isInitialLoading = true);
                  // Manually clear cache and fetch on user retry
                  _fetchDevices(forceRefresh: true);
                },
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    if (_filteredDevices.isEmpty) {
      return Center(
        child: Text("No devices found", style: TextStyle(color: textColor)),
      );
    }

    return RefreshIndicator(
      // Ensure pull-to-refresh ignores the cache and goes to the server
      onRefresh: () => _fetchDevices(forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        // 0 top padding, because the 16px bottom padding from the Search row creates the exact visual gap needed
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _filteredDevices.length,
        itemBuilder: (context, index) {
          return _buildDeviceCard(_filteredDevices[index], index + 1, textColor, cardColor);
        },
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device, int index, Color textColor, Color cardColor) {
    String statusText = _calculateStatus(device.lastSeenAt);
    Color statusColor;

    if (statusText == "Active") {
      statusColor = AppColors.green;
    } else if (statusText == "Inactive") {
      statusColor = AppColors.red;
    } else {
      statusColor = AppColors.orange;
    }

    return Container(
      // Exactly 16px margin between cards
      margin: const EdgeInsets.only(bottom: 16),
      // Exactly 16px internal padding inside the card
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "$index. ${device.name}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                  ),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: TextStyle(color: textColor, fontSize: 14),
              children: [
                const TextSpan(text: "EUI: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: device.devEui.isEmpty ? "___________" : device.devEui),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Last seen: ${_formatPhnomPenhTime(device.lastSeenAt)}",
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceDetailScreen(
                        devEui: device.devEui,
                        applicationId: widget.applicationId,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      "Detail",
                      style: TextStyle(color: Colors.grey[600], decoration: TextDecoration.underline, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey[600]),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}