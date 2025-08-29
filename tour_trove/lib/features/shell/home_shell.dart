import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import '../pages/museums_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

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
          Icon(Icons.museum, color: Colors.deepPurple),
          Icon(Icons.home, color: Colors.deepPurple),
          Icon(Icons.person, color: Colors.deepPurple),
        ],
        inactiveIcons: const [
          Text("Museus"),
          Text("Home"),
          Text("Usuário"),
        ],
        color: Colors.white,
        height: 60,
        circleWidth: 60,
        activeIndex: tabIndex,
        onTap: (index) {
          tabIndex = index;
          _pageController.jumpToPage(tabIndex);
        },
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        shadowColor: Colors.deepPurple,
        elevation: 10,
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
