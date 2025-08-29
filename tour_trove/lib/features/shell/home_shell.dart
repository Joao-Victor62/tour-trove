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
    Text("Museus", style: TextStyle(fontSize: 15)), // opcional: texto menor
    Text("Home", style: TextStyle(fontSize: 15)),
    Text("Usuário", style: TextStyle(fontSize: 15)),
  ],
  color: Colors.white,
  height: 50,           // antes 60
  circleWidth: 50,      // antes 60
  activeIndex: tabIndex,
  onTap: (index) {
    tabIndex = index;
    _pageController.jumpToPage(tabIndex);
  },
  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 14), // ajusta espaçamento
  cornerRadius: const BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
  ),
  shadowColor: Colors.deepPurple,
  elevation: 6, // reduz a sombra também, se quiser
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
