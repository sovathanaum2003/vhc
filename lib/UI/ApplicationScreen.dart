import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
import '../Model/ApplicationModel.dart';
import '../Services/ApplicationService.dart';
import '../Services/DeviceService.dart'; // Required for pre-fetching
import 'DeviceScreen.dart';

class ApplicationScreen extends StatefulWidget {
  final String tenantId;

  const ApplicationScreen({super.key, required this.tenantId});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  // --- State Variables ---
  List<ApplicationModel> _applications = [];
  List<ApplicationModel> _filteredApplications = [];
  Map<String, int> _deviceCounts = {}; // Caches the counts for instant rendering

  bool _isInitialLoading = true; // Prevents UI from wiping on pull-to-refresh
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---
  Future<void> _fetchApplications() async {
    // Keep _isInitialLoading false if already loaded to prevent UI flashing
    setState(() {
      _errorMessage = null;
    });

    try {
      // 1. Fetch the list of applications
      final apps = await ApplicationService.getApplications(widget.tenantId);

      // 2. Concurrently fetch device counts for ALL applications at once
      final counts = await Future.wait(
          apps.map((app) => ApplicationService.getDeviceCount(app.id))
      );

      // 3. Map the counts to their respective application IDs
      final newCounts = <String, int>{};
      for (int i = 0; i < apps.length; i++) {
        newCounts[apps[i].id] = counts[i];
      }

      if (mounted) {
        setState(() {
          _applications = apps;
          _filteredApplications = apps;
          _deviceCounts = newCounts;
          _isInitialLoading = false;
        });
        // Re-apply filter in case user was searching during a background refresh
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
      _filteredApplications = _applications.where((app) {
        return app.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Theme & Color Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);
    final labelColor = AppColors.secondaryText(context);

    // Specific Design Colors
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
          "Application",
          style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(textColor, labelColor),
          Expanded(child: _buildListContent(textColor, cardColor)),
        ],
      ),
    );
  }

  // --- UI Components ---
  Widget _buildSearchBar(Color textColor, Color labelColor) {
    return Padding(
      // Exactly 16px margin on all sides
      padding: const EdgeInsets.all(16.0),
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
              borderSide: BorderSide(
                color: AppColors.accentColor(context),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(Color textColor, Color cardColor) {
    // Show blocking loading indicator only on initial load
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show Error State
    if (_errorMessage != null && _applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: AppColors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchApplications, child: const Text("Retry")),
          ],
        ),
      );
    }

    // Empty State
    if (_filteredApplications.isEmpty) {
      return Center(
        child: Text("No applications found", style: TextStyle(color: textColor)),
      );
    }

    // Main List
    return RefreshIndicator(
      onRefresh: _fetchApplications,
      child: ListView.builder(
        // Top padding is 0 because the search bar provides exactly 16px of bottom padding
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _filteredApplications.length,
        itemBuilder: (context, index) {
          return _buildApplicationCard(_filteredApplications[index], index + 1, textColor, cardColor);
        },
      ),
    );
  }

  Widget _buildApplicationCard(ApplicationModel app, int index, Color textColor, Color cardColor) {
    // Retrieve the cached count for instant UI rendering
    final int deviceCount = _deviceCounts[app.id] ?? 0;

    return Container(
      // Exactly 16px bottom margin between cards
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // --- FAST RESPONSE MAGIC ---
            // Trigger the network call immediately on tap, before the animation starts
            final preloadedFuture = DeviceService.getDevices(app.id);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceScreen(
                  applicationId: app.id,
                  preloadedFuture: preloadedFuture, // Pass the in-progress task
                ),
              ),
            );
          },
          child: Padding(
            // Uniform 16px padding inside the card for a clean look
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: textColor, fontSize: 16),
                      children: [
                        TextSpan(text: "$index. Name: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: app.name, style: const TextStyle(fontWeight: FontWeight.normal)),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "$deviceCount Device",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[700]),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}