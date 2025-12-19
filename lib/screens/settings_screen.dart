import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/sound_manager.dart';
import '../utils/settings_controller.dart';
import '../utils/stats_repository.dart';
import '../widgets/glass_modal.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/cosmic_snackbar.dart';
import 'premium_screen.dart';
import 'legal_screen.dart';
import '../utils/legal_text.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  bool _timerDisplay = true;
  bool _autoCheckErrors = true;
  bool _highlightCells = true;
  String _animationSpeed = 'Normal';
  String _colorScheme = 'Default';
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEffects = prefs.getBool('sound_effects') ?? true;
      _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
      _timerDisplay = prefs.getBool('timer_display') ?? true;
      _autoCheckErrors = prefs.getBool('auto_check_errors') ?? true;
      _highlightCells = prefs.getBool('highlight_cells') ?? true;
      _animationSpeed = SettingsController().animationSpeed;
      _colorScheme = SettingsController().colorScheme;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0E27),
                const Color(0xFF1A1F3A),
                const Color(0xFF0A0E27),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSection('Audio', [
                        _buildToggle(
                          'Sound Effects',
                          'Button clicks and game sounds',
                          Icons.volume_up,
                          _soundEffects,
                          (val) {
                            setState(() => _soundEffects = val);
                            _saveSetting('sound_effects', val);
                            SoundManager().setEnabled(val);
                          },
                        ),
                      ]),
                      _buildSection('Premium', [
                        _buildActionButton(
                          'Get Premium',
                          'Remove ads & Unlimited hints',
                          Icons.star,
                          Colors.amberAccent,
                          () {
                            SoundManager().playClick();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      /* Haptic Feedback removed as per user request */
                      const SizedBox(height: 20),
                      _buildSection('Data', [
                        _buildActionButton(
                          'Reset Progress',
                          'Clear all game progress',
                          Icons.delete_forever,
                          Colors.redAccent,
                          () => _showResetDialog(),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSection('Legal', [
                        _buildActionButton(
                          'Privacy Policy',
                          'Read our privacy policy',
                          Icons.privacy_tip,
                          Colors.blueAccent,
                          () => _showLegalScreen('Privacy Policy', LegalText.privacyPolicy),
                        ),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        _buildActionButton(
                          'Terms & Conditions',
                          'Read our terms of service',
                          Icons.description,
                          Colors.blueAccent,
                          () => _showLegalScreen('Terms & Conditions', LegalText.termsAndConditions),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSection('About', [
                        _buildInfoTile('Version', '1.0.0', Icons.info),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Title
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
              fontFamily: 'Orbitron',
            ),
          ),
          // Back Button (Right, pointing Right)
          Align(
             alignment: Alignment.centerRight,
             child: Directionality(
               textDirection: TextDirection.rtl, // To make arrow point right if using standard back icon, or use typical forward icon
               child: IconButton(
                 icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24), // arrow_back_ios_new points left. In RTL it points Right.
                 onPressed: () {
                    SoundManager().playClick();
                    widget.onBack?.call();
                 },
                 tooltip: 'Back to Home',
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF4DD0E1).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF4DD0E1), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF64FFDA),
        activeTrackColor: const Color(0xFF64FFDA).withOpacity(0.5),
      ),
    );
  }

  Widget _buildDropdown(
    String title,
    IconData icon,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9D84FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF9D84FF), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1A1F3A),
          underline: const SizedBox(),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  void _showResetDialog() {
    GlassModal.show(
      context: context,
      title: 'RESET PROGRESS?',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will delete all your game progress. This action cannot be undone.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CosmicButton(
              text: 'RESET EVERYTHING',
              icon: Icons.delete_forever,
              type: CosmicButtonType.destructive,
              onPressed: () async {
                await StatsRepository.clearAllProgress();
                if (context.mounted) {
                  Navigator.pop(context);
                  showCosmicSnackbar(context, 'All progress has been reset!');
                }
              },
            ),
            const SizedBox(height: 16),
            CosmicButton(
              text: 'CANCEL',
              type: CosmicButtonType.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalScreen(String title, String content) {
    SoundManager().playClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalScreen(title: title, content: content),
      ),
    );
  }
}


