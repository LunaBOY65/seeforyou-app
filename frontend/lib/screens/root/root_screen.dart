import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seeforyou_app/screens/intro/intro_screen.dart';
import '../camera/camera_screen.dart';
import '../result/result_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // ควบคุมหน้าจอ 0 = หน้าแนะนำ, 1 = หน้ากล้อง, 2 = หน้าผลลัพธ์
  int _index = 0;

  int _lastTappedIndex = -1;
  DateTime? _lastTapTime;
  final AudioPlayer _navPlayer = AudioPlayer();
  String? _imagePath;

  @override
  void dispose() {
    _navPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // หน้า 0
      IntroScreen(
        onNext: () {
          setState(() => _index = 1);
        },
      ),

      // หน้า 1
      CameraScreen(
        onImageSelected: (path) {
          setState(() {
            _imagePath = path;
            _index = 2;
          });
        },
      ),

      // หน้า 2
      ResultScreen(
        imagePath: _imagePath,
        onRetake: () {
          setState(() {
            _imagePath = null;
            _index = 1;
          });
        },
      ),
    ];

    return Scaffold(
      body: screens[_index],

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _handleNavTap,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 17,
          unselectedFontSize: 17,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: [
            _buildNavItem(
              index: 0,
              label: 'วิธีใช้',
              assetPath: 'assets/icons/information.svg',
            ),
            _buildNavItem(
              index: 1,
              label: 'กล้อง',
              assetPath: 'assets/icons/camera_icon.svg',
            ),
            _buildNavItem(
              index: 2,
              label: 'ผลลัพธ์',
              assetPath: 'assets/icons/robotics_icon.svg',
            ),
          ],
        ),
      ),
    );
  }

  /// ฟังก์ชันสำหรับจัดการปุ่มเมนูด้านล่างแบบ 2 จังหวะ
  void _handleNavTap(int index) async {
    final now = DateTime.now();

    bool isDoubleTap =
        _lastTappedIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 1500;
    HapticFeedback.heavyImpact();

    if (isDoubleTap) {
      setState(() {
        _index = index;

        if (index != 2) {
          _imagePath = null;
        }
      });

      _lastTappedIndex = -1;
    } else {
      _lastTappedIndex = index;
      _lastTapTime = now;

      await _navPlayer.stop();

      String soundFile = '';

      if (index == 1) soundFile = 'audio/camera_page.mp3';
      if (index == 2) soundFile = 'audio/results_page.mp3';
      if (soundFile.isNotEmpty) {
        await _navPlayer.play(AssetSource(soundFile));
      }
    }
  }

  /// ปุ่มเมนูแต่ละปุ่ม
  BottomNavigationBarItem _buildNavItem({
    required int index,
    required String label,
    required String assetPath,
  }) {
    final isSelected = _index == index;
    const double circleSize = 48;
    const double iconSize = 27;

    Widget iconWidget = SvgPicture.asset(
      assetPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        isSelected ? Colors.black : Colors.grey,
        BlendMode.srcIn,
      ),
    );

    return BottomNavigationBarItem(
      icon: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        child: iconWidget,
      ),
      activeIcon: Container(
        margin: const EdgeInsets.only(bottom: 6),
        width: circleSize,
        height: circleSize,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
        ),
        child: Center(child: iconWidget),
      ),
      label: label,
    );
  }
}
