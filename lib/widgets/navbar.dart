import 'package:flutter/material.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';

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
          Icon(Icons.home, color: Color.fromARGB(255, 0, 0, 0)),
          Icon(Icons.history, color: Color.fromARGB(255, 0, 0, 0)),
          Icon(Icons.person, color: Color.fromARGB(255, 0, 0, 0)),
        ],
        inactiveIcons: const [
          Text("Home"),
          Text("Monitoring"),
          Text("Account"),
        ],
        color: const Color.fromARGB(255, 159, 208, 122),
        height: 60,
        circleWidth: 60,
        activeIndex: _tabIndex,
        onTap: (index) {
          setState(() {
            _tabIndex = index;
          });
          _pageController.jumpToPage(_tabIndex);
        },
        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 6),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        shadowColor: const Color.fromRGBO(68, 208, 140, 1),
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
