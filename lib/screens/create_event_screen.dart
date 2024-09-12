import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/screens/profile_screen.dart';

class CreateEventScreen extends StatefulWidget {
  final LatLng location;

  const CreateEventScreen({Key? key, required this.location}) : super(key: key);

  @override
  _CreateEventScreenState createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final UserService _userService = UserService();
  final InvitationService _invitationService = InvitationService();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  List<String> _invitedFollowers = [];
  bool _isLoading = true;
  bool _isCreatingEvent = false;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> followers = await _userService.getUserFollowers();
      setState(() {
        _followers = followers;
        _filteredFollowers = followers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading followers: ${e.toString()}')),
      );
    }
  }

  void _filterFollowers(String query) {
    setState(() {
      _filteredFollowers = _followers
          .where((follower) =>
              follower['username'].toLowerCase().contains(query.toLowerCase()) ||
              follower['email'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            _buildDateTimePicker(),
            const SizedBox(height: 24),
            _buildFollowersList(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isCreatingEvent ? null : _createEvent,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCreatingEvent
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Event', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event Date & Time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPickerButton(
                label: _selectedDate == null ? 'Select Date' : DateFormat('MMM d, y').format(_selectedDate!),
                icon: Icons.calendar_today,
                onPressed: _selectDate,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPickerButton(
                label: _selectedTime == null ? 'Select Time' : _selectedTime!.format(context),
                icon: Icons.access_time,
                onPressed: _selectTime,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPickerButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildFollowersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite Followers', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search followers',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: _filterFollowers,
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredFollowers.length,
                itemBuilder: (context, index) {
                  final follower = _filteredFollowers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          follower['profileImageUrl'] != null ? NetworkImage(follower['profileImageUrl']) : null,
                      child:
                          follower['profileImageUrl'] == null ? Text(follower['username'][0].toUpperCase()) : null,
                    ),
                    title: Text(follower['username']),
                    trailing: ElevatedButton(
                      onPressed: () => _toggleInvite(follower['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _invitedFollowers.contains(follower['id'])
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _invitedFollowers.contains(follower['id']) ? 'Invited' : 'Invite',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            isCurrentUser: false,
                            userId: follower['id'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  void _toggleInvite(String followerId) {
    setState(() {
      if (_invitedFollowers.contains(followerId)) {
        _invitedFollowers.remove(followerId);
      } else {
        _invitedFollowers.add(followerId);
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createEvent() async {
    if (_formKey.currentState!.validate() && _selectedDate != null && _selectedTime != null) {
      setState(() {
        _isCreatingEvent = true;
      });

      try {
        final DateTime eventDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        final Map<String, dynamic> customPlace = {
          'name': _nameController.text,
          'vicinity': 'Custom Location',
          'location': widget.location,
          'place_id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        };

        await _invitationService.createOrUpdateEvent(
          customPlace['place_id'],
          customPlace,
          eventDateTime,
          _invitedFollowers,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );

        Navigator.of(context).pop(); // Return to the previous screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      } finally {
        setState(() {
          _isCreatingEvent = false;
        });
      }
    }
  }
}