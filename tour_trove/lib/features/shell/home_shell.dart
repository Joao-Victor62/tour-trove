import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import '../pages/museums_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

// Centraliza cores da aplicação
class AppColors {
  static const Color textInactive = Color(0xFFF4F5FC);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 1;
  late final PageController _pageController;

  int get tabIndex => _tabIndex;
  set tabIndex(int v) {
    if (v == _tabIndex) return;
    setState(() => _tabIndex = v);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: CircleNavBar(
        activeIcons: const [
          Icon(Icons.museum, color: Color(0xFFF4F5FC)),
          Icon(Icons.home, color: Color(0xFFF4F5FC)),
          Icon(Icons.person, color: Color(0xFFF4F5FC)),
        ],
        inactiveIcons: const [
          Text(
            "Museus",
            style: TextStyle(fontSize: 15, color: AppColors.textInactive),
          ),
          Text(
            "Home",
            style: TextStyle(fontSize: 15, color: AppColors.textInactive),
          ),
          Text(
            "Usuário",
            style: TextStyle(fontSize: 15, color: AppColors.textInactive),
          ),
        ],
        color: const Color(0xFF8EBBFF),
        height: 50,           
        circleWidth: 50,     
        activeIndex: tabIndex,
        onTap: (index) {
          tabIndex = index;
          _pageController.jumpToPage(tabIndex);
        },
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 14),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
        ),
        shadowColor: Colors.deepPurple,
        elevation: 6,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (v) => tabIndex = v,
        children: const [
          MuseumsPage(),
          HomePage(),
          ProfilePage(),
        ],
      ),
    );
  }
}
