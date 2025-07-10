import 'package:flutter/material.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';
import '../utils/colors.dart';

class CircleNavBarPage extends StatefulWidget {
  const CircleNavBarPage({super.key, required this.pages});

  final List<Widget> pages;

  @override
  // ignore: library_private_types_in_public_api
  _CircleNavBarPageState createState() => _CircleNavBarPageState();
}

class _CircleNavBarPageState extends State<CircleNavBarPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: CircleNavBar(
        activeIcons: const [
          Icon(Icons.home, color: AppColors.background),
          Icon(Icons.computer, color: AppColors.background),
          Icon(Icons.person, color: AppColors.background),
        ],
        inactiveIcons: const [
          Text("Home", style: TextStyle(color: Color.fromRGBO(245, 245, 245, 1.0), fontWeight: FontWeight.bold),),
          Text("Monitoring", style: TextStyle(color: Color.fromRGBO(245, 245, 245, 1.0), fontWeight: FontWeight.bold),),
          Text("Account", style: TextStyle(color: Color.fromRGBO(245, 245, 245, 1.0), fontWeight: FontWeight.bold),),
        ],
        color: AppColors.primary,
        circleColor: AppColors.primary,
        height: 60,
        circleWidth: 60,
        activeIndex: _tabIndex,
        onTap: (index) {
          setState(() {
            _tabIndex = index;
          });
          _pageController.jumpToPage(_tabIndex);
        },

        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        shadowColor: AppColors.secondary.withValues(alpha: 0.5),
        elevation: 10,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
        children: widget.pages,
      ),
    );
  }
}