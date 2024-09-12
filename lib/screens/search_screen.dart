import 'package:flutter/material.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:aiviser/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> results = await _userService.searchUsersByName(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    try {
      if (user['followStatus'] == 'following') {
        await _userService.unfollowUser(user['id']);
        setState(() {
          user['followStatus'] = 'not_following';
        });
      } else if (user['followStatus'] == 'not_following') {
        String followStatus = await _userService.followUser(user['id']);
        setState(() {
          user['followStatus'] = followStatus;
        });
      }
      // If status is 'requested', do nothing on button press
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  String _getFollowButtonText(Map<String, dynamic> user) {
    switch (user['followStatus']) {
      case 'following':
        return 'Following';
      case 'requested':
        return 'Requested';
      case 'not_following':
        return 'Follow';
      default:
        return 'Follow';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              user['profileImageUrl'] != null ? NetworkImage(user['profileImageUrl'] as String) : null,
                          child: user['profileImageUrl'] == null
                              ? Text((user['username'] as String? ?? '?')[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user['username'] as String? ?? 'Unknown User'),
                        trailing: ElevatedButton(
                          onPressed: user['followStatus'] != 'requested' ? () => _toggleFollow(user) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                user['followStatus'] == 'following' ? Colors.grey.withOpacity(0.5) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(_getFollowButtonText(user)),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                isCurrentUser: false,
                                userId: user['id'] as String,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
