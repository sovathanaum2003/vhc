import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../Color/AppColor.dart';

class NoInternetWrapper extends StatefulWidget {
  final Widget? child;

  const NoInternetWrapper({super.key, required this.child});

  @override
  State<NoInternetWrapper> createState() => _NoInternetWrapperState();
}

class _NoInternetWrapperState extends State<NoInternetWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _startMonitoring();
  }

  Future<void> _checkInitialStatus() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _startMonitoring() {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // STRICTER CHECK: We are offline if the list is empty, OR if 'none' is the ONLY result.
    bool isNowOffline = results.isEmpty ||
        (results.length == 1 && results.contains(ConnectivityResult.none));

    if (isNowOffline != _isOffline) {
      if (mounted) {
        setState(() {
          _isOffline = isNowOffline;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: widget.child ?? const SizedBox()),

          // FIXED: SafeArea ensures the banner is pushed ABOVE the phone's navigation bar
          SafeArea(
            top: false, // We only care about the bottom of the phone
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              // Increased height slightly to make it more readable on real devices
              height: _isOffline ? 45 : 0,
              color: AppColors.red,
              child: _isOffline
                  ? const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "No Internet Connection",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}