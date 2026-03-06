import 'package:flutter/material.dart';
import 'Color/AppColor.dart';
// import 'InternetCheck/InternetCheck.dart';
import 'UI/LoginScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppColors.themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'VHCMon',

          // --- THEME SETUP ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFEBF4FF),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF050A15),
          ),
          themeMode: currentMode,

          // // --- INTERNET CHECKER INJECTION ---
          // // Updated: Only wraps the child with NoInternetWrapper
          // builder: (context, child) {
          //   return NoInternetWrapper(
          //     child: child,
          //   );
          // },

          home: const LoginScreen(),
        );
      },
    );
  }
}