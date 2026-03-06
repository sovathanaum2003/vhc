import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
import '../Services/LoginService.dart';
import 'HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _tenantController = TextEditingController();
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _tenantController.dispose();
    super.dispose();
  }

  // --- LOGIN LOGIC ---
  void _handleLogin() async {
    String inputName = _tenantController.text.trim();

    if (inputName.isEmpty) {
      _showTopError("Please enter a tenant name.");
      return;
    }

    String? tenantId = await TenantService.getTenantIdByName(inputName);

    if (!mounted) return;

    if (tenantId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // UPDATED: Passing both ID and Name to HomeScreen
          builder: (context) => HomeScreen(
            tenantId: tenantId,
            tenantName: inputName, // Pass the name user typed
          ),
        ),
      );
    } else {
      _showTopError("Can't find this tenant name.");
    }
  }

  // --- ERROR NOTIFICATION ---
  void _showTopError(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Use static red from AppColors
              color: AppColors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        _buildRippleLogo(),

                        const Spacer(flex: 2),

                        // --- Input Field ---
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : AppColors.accentColor(context).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _tenantController,
                            style: TextStyle(
                              color: AppColors.primaryText(context),
                            ),
                            decoration: InputDecoration(
                              hintText: "Tenant name",
                              hintStyle: TextStyle(
                                  color: AppColors.secondaryText(context)
                              ),
                              filled: true,
                              fillColor: AppColors.inputFillColor(context),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.accentColor(context),
                                    width: 1.5
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // --- Login Button ---
                        SizedBox(
                          width: 150,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryButton(context),
                              foregroundColor: AppColors.primaryButtonText(context),
                              elevation: 5,
                              shadowColor: AppColors.accentColor(context).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "LOGIN",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0),
                            ),
                          ),
                        ),

                        const Spacer(flex: 3),

                        Text(
                          "Log in with your tenant name.",
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRippleLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildRippleRing(delay: 0.0),
        _buildRippleRing(delay: 0.5),

        Container(
          width: 125,
          height: 125,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFCDE4FD),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.0),
          child: Image.asset(
            'lib/Assets/CompanyLogo.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildRippleRing({required double delay}) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        final double value = (_rippleController.value + delay) % 1.0;
        final double opacity = (1.0 - value) * 0.5;
        final double scale = 1.0 + (value * 0.5);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentColor(context).withOpacity(0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}