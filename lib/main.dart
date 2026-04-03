import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => TasbihProvider()..loadData(),
      child: const TasbihApp(),
    ),
  );
}

class TasbihApp extends StatelessWidget {
  const TasbihApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TasbihProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tasbih by Fadi',
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0EEE9),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
        ),
      ),
      home: const TasbihHome(),
    );
  }
}

class TasbihProvider with ChangeNotifier {
  int _count = 0;
  int _reminderCount = 33;
  bool _isDarkMode = true;
  int _bodyColorIndex = 0;

  int get count => _count;
  int get reminderCount => _reminderCount;
  bool get isDarkMode => _isDarkMode;
  int get bodyColorIndex => _bodyColorIndex;

  final List<Color> bodyColors = [
    const Color(0xFF1A1A1A), // Deep Carbon
    const Color(0xFF064B35), // Royal Emerald
    const Color(0xFF0F2D4E), // Midnight Blue
  ];

  Color get currentBodyColor => bodyColors[_bodyColorIndex];

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _count = prefs.getInt('count') ?? 0;
    _reminderCount = prefs.getInt('reminderCount') ?? 33;
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _bodyColorIndex = prefs.getInt('bodyColorIndex') ?? 0;
    notifyListeners();
  }

  bool _reachedReminder = false;
  bool get reachedReminder => _reachedReminder;

  void clearReachedReminder() {
    _reachedReminder = false;
    notifyListeners();
  }

  Future<void> increment() async {
    _count++;
    if (_count == _reminderCount) {
      _reachedReminder = true;
    }
    await _saveData();
    notifyListeners();
    _triggerHaptic(count: 1);
  }

  Future<void> reset() async {
    _count = 0;
    _reachedReminder = false;
    await _saveData();
    notifyListeners();
    _triggerHaptic(count: 3);
  }

  Future<void> setReminder(int value) async {
    _reminderCount = value;
    await _saveData();
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveData();
    notifyListeners();
  }

  void cycleBodyColor() {
    _bodyColorIndex = (_bodyColorIndex + 1) % bodyColors.length;
    _saveData();
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('count', _count);
    await prefs.setInt('reminderCount', _reminderCount);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setInt('bodyColorIndex', _bodyColorIndex);
  }

  void _triggerHaptic({int count = 1}) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator ?? false) {
      if (count == 1) {
        Vibration.vibrate(duration: 40, amplitude: 100);
      } else {
        Vibration.vibrate(pattern: [0, 50, 50, 50], intensities: [0, 200, 0, 255]);
      }
    }
  }
}

class TasbihHome extends StatefulWidget {
  const TasbihHome({super.key});

  @override
  State<TasbihHome> createState() => _TasbihHomeState();
}

class _TasbihHomeState extends State<TasbihHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFriday();
    });
  }

  void _checkFriday() {
    if (DateTime.now().weekday == DateTime.friday) {
      _showPremiumDialog(
        title: "Salamalaykum, it's Fadi",
        content: "A gentle reminder to recite Surah al Kahf today and also give zakat.\n\n"
            "Include me in your duas. JazakAllahukhayr.",
        actionLabel: "JazakAllah",
      );
    }
  }

  void _showPremiumDialog({
    required String title,
    required String content,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        title: Text(title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(content, style: GoogleFonts.outfit(fontSize: 16, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(actionLabel,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TasbihProvider>(context);

    if (provider.reachedReminder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPremiumDialog(
          title: "Goal Reached! ✨",
          content: "Yo Salam, you reached your dhikr goal: ${provider.count}",
          actionLabel: "Alhamdulillah",
        );
        provider.clearReachedReminder();
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: provider.isDarkMode 
              ? [const Color(0xFF1E1E1E), const Color(0xFF0A0A0A)]
              : [const Color(0xFFFFFFFF), const Color(0xFFE5E5E5)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double maxWidth = constraints.maxWidth > 500 ? 500 : constraints.maxWidth;
              return Center(
                child: SizedBox(
                  width: maxWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Responsive Top Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            _TopCircleButton(
                              icon: Icons.palette_outlined,
                              onTap: provider.cycleBodyColor,
                            ),
                            const Spacer(),
                            _ReminderDisplay(count: provider.reminderCount, onTap: () async {
                              final res = await _showInput(context, provider.reminderCount);
                              if (res != null) provider.setReminder(res);
                            }),
                            const Spacer(),
                            _TopCircleButton(
                              icon: provider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                              onTap: provider.toggleTheme,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // The Real Device
                      const TasbihBody(),
                      const Spacer(),
                      // Footer
                      const FooterWidget(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<int?> _showInput(BuildContext context, int initial) async {
    final controller = TextEditingController(text: initial.toString());
    return showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Dhikr Goal", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Target Count",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text("Set"),
          ),
        ],
      ),
    );
  }
}

class TasbihBody extends StatelessWidget {
  const TasbihBody({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TasbihProvider>(context);
    final size = MediaQuery.of(context).size;
    final deviceWidth = size.width > 500 ? 340.0 : size.width * 0.85;

    return Container(
      width: deviceWidth,
      height: deviceWidth * 1.5, // Slightly taller for more elegance
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 35),
      decoration: BoxDecoration(
        color: provider.currentBodyColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(deviceWidth * 0.6), // Pronounced tapered top
          topRight: Radius.circular(deviceWidth * 0.6),
          bottomLeft: Radius.circular(deviceWidth * 0.4), // Wider bottom
          bottomRight: Radius.circular(deviceWidth * 0.4),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            provider.currentBodyColor.withLightness(0.06),
            provider.currentBodyColor,
            provider.currentBodyColor.darken(0.45),
          ],
        ),
        boxShadow: [
          // Stronger ambient depth
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            offset: const Offset(25, 35),
            blurRadius: 60,
            spreadRadius: -12,
          ),
          // Top light catch
          BoxShadow(
            color: Colors.white.withOpacity(0.12),
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Container(
        // Inner depth rim for a "molded" look
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(deviceWidth * 0.58),
            topRight: Radius.circular(deviceWidth * 0.58),
            bottomLeft: Radius.circular(deviceWidth * 0.38),
            bottomRight: Radius.circular(deviceWidth * 0.38),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 2),
        ),
        child: Column(
          children: [
            const SizedBox(height: 35),
            // LCD Bezel Section
            _LCDSection(provider: provider),
            const Spacer(),
            // Controls
            const _ControlsSection(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

class _LCDSection extends StatelessWidget {
  final TasbihProvider provider;
  const _LCDSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF859666), // Retro LCD Green
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.5), width: 2),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            // Glass reflection
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                ),
              ),
            ),
            Center(
              child: FittedBox(
                child: Text(
                  provider.count.toString().padLeft(4, '0'),
                  style: GoogleFonts.shareTechMono(
                    fontSize: 75,
                    color: Colors.black.withOpacity(0.75),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsSection extends StatelessWidget {
  const _ControlsSection();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TasbihProvider>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ResetButton(onTap: provider.reset),
        _MainButton(onTap: provider.increment),
      ],
    );
  }
}

class _MainButton extends StatefulWidget {
  final VoidCallback onTap;
  const _MainButton({required this.onTap});

  @override
  State<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<_MainButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDown 
              ? [const Color(0xFFDDDDDD), const Color(0xFFFFFFFF)]
              : [const Color(0xFFFFFFFF), const Color(0xFFBABABA)],
          ),
          boxShadow: _isDown 
            ? [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  offset: const Offset(12, 12),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(1.0),
                  offset: const Offset(-6, -6),
                  blurRadius: 15,
                ),
              ],
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withAlpha(20)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 8),
            BoxShadow(color: Colors.white.withOpacity(0.1), offset: const Offset(-2, -2), blurRadius: 4),
          ],
          border: Border.all(color: Colors.white10),
        ),
        child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 30),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }
}

class _ReminderDisplay extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ReminderDisplay({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_circle, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Text("Goal: $count", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "made with ❤️ by Fadi",
          style: GoogleFonts.outfit(
            fontSize: 14, 
            fontWeight: FontWeight.w500,
            color: Colors.grey.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 12),
        _WebsiteButton(),
      ],
    );
  }
}

class _WebsiteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        const url = 'https://www.fadimuhammed.com';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      },
      icon: const Icon(Icons.language, size: 20),
      label: Text("Visit Fadi's Portfolio", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color withLightness(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

// Custom Painter or BoxDecoration with Inset Shadow helper if needed
// For simplicity in single-file, we used basic BoxDecoration.
