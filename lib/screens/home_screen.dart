import 'package:aiviser/screens/invitations_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'invitations_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  final List<Widget> _screens = [
    TimelineScreen(),
    const SearchScreen(),
    const MapScreen(),
    const InvitationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTabItem(0, Icons.timeline, 'Timeline'),
                _buildTabItem(1, Icons.search, 'Search'),
                const SizedBox(width: 48),
                InvitationsBottomNavItem(
                  icon: Icons.mail_outline,
                  isSelected: _currentIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
                _buildTabItem(4, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        height: 65,
        width: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              _currentIndex = 2;
            });
          },
          backgroundColor: Theme.of(context).colorScheme.secondary,
          child: const Icon(Icons.map, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ],
      ),
      onPressed: () {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}
