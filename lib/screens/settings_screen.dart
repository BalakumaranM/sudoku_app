import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/sound_manager.dart';
import '../utils/settings_controller.dart';
import '../utils/stats_repository.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _soundEffects = true;
  bool _backgroundMusic = true;
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
      _backgroundMusic = prefs.getBool('background_music') ?? true;
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
                          },
                        ),
                        _buildToggle(
                          'Background Music',
                          'Ambient space music',
                          Icons.music_note,
                          _backgroundMusic,
                          (val) {
                            setState(() => _backgroundMusic = val);
                            _saveSetting('background_music', val);
                            SoundManager().setAmbientEnabled(val);
                            if (!val) {
                              SoundManager().stopAmbientMusic();
                            } else {
                              SoundManager().playAmbientMusic();
                            }
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSection('Gameplay', [
                        _buildToggle(
                          'Haptic Feedback',
                          'Vibration on interactions',
                          Icons.vibration,
                          _hapticFeedback,
                          (val) {
                            setState(() => _hapticFeedback = val);
                            _saveSetting('haptic_feedback', val);
                          },
                        ),
                        _buildToggle(
                          'Show Timer',
                          'Display game timer',
                          Icons.timer,
                          _timerDisplay,
                          (val) {
                            setState(() => _timerDisplay = val);
                            _saveSetting('timer_display', val);
                          },
                        ),
                        _buildToggle(
                          'Auto-check Errors',
                          'Highlight mistakes automatically',
                          Icons.error_outline,
                          _autoCheckErrors,
                          (val) {
                            setState(() => _autoCheckErrors = val);
                            _saveSetting('auto_check_errors', val);
                          },
                        ),
                        _buildToggle(
                          'Highlight Related Cells',
                          'Show row/column/block highlights',
                          Icons.highlight,
                          _highlightCells,
                          (val) {
                            setState(() => _highlightCells = val);
                            _saveSetting('highlight_cells', val);
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSection('Appearance', [
                        _buildDropdown(
                          'Animation Speed',
                          Icons.speed,
                          _animationSpeed,
                          ['Slow', 'Normal', 'Fast'],
                          (val) {
                            setState(() => _animationSpeed = val!);
                            SettingsController().setAnimationSpeed(val!);
                          },
                        ),
                        _buildDropdown(
                          'Color Scheme',
                          Icons.palette,
                          _colorScheme,
                          ['Default', 'High Contrast', 'Colorblind'],
                          (val) {
                            setState(() => _colorScheme = val!);
                            SettingsController().setColorScheme(val!);
                          },
                        ),
                      ]),
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
                      _buildSection('About', [
                        _buildInfoTile('Version', '1.0.0', Icons.info),
                        _buildInfoTile('Developer', 'Bala', Icons.code),
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
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text(
          'Reset Progress?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all your game progress. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await StatsRepository.clearAllProgress();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All progress has been reset!')),
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}


