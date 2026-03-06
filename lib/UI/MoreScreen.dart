import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
import 'LoginScreen.dart';

class MoreScreen extends StatefulWidget {
  final String tenantName;
  final String tenantId;

  const MoreScreen({
    super.key,
    required this.tenantName,
    required this.tenantId
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Theme & Color Logic (Matched to the rest of the app)
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = AppColors.scaffoldBackground(context);
    final textColor = AppColors.primaryText(context);
    final subTextColor = AppColors.secondaryText(context);
    final iconColor = AppColors.iconColor(context);

    // Specific Design Colors
    const Color specificBrightBlue = Color(0xFF9FCCFF);
    final headerColor = isDarkMode ? AppColors.cardBackground(context) : specificBrightBlue;
    final cardColor = isDarkMode ? AppColors.cardBackground(context) : specificBrightBlue.withOpacity(0.3);
    final headerTextColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "More",
          style: TextStyle(
            color: headerTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: headerColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        // Exactly 16px margin on all outer edges
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // --- Profile Section ---
          Container(
            // Exactly 16px internal padding
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDarkMode ? Colors.black12 : Colors.white,
                  radius: 25,
                  child: Icon(Icons.person, color: AppColors.accentColor(context), size: 28),
                ),
                const SizedBox(width: 16), // 16px gap between avatar and text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tenantName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID: ${widget.tenantId}",
                        style: TextStyle(color: subTextColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 16), // Exactly 16px margin between cards

          // --- Menu Group ---
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  secondary: Icon(Icons.dark_mode, color: iconColor),
                  title: Text("Dark Mode", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  activeColor: AppColors.accentColor(context),
                  value: isDarkMode,
                  onChanged: (bool value) {
                    AppColors.toggleTheme(value);
                  },
                ),
                Divider(height: 1, color: textColor.withOpacity(0.1), indent: 16, endIndent: 16),
                _buildMenuItem(Icons.help_outline, "Help", iconColor, textColor, () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const MqttPage()),
                  // );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16), // Exactly 16px margin between cards

          // --- Logout ---
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              leading: Icon(Icons.logout, color: AppColors.red),
              title: Text("Log Out",
                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
              onTap: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color iconColor, Color textColor, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: iconColor.withOpacity(0.5)),
      onTap: onTap,
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Log Out", style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: AppColors.secondaryText(context))),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: AppColors.secondaryText(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}