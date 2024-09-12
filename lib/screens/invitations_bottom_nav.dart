import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/services/user_service.dart';

class InvitationsBottomNavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const InvitationsBottomNavItem({
    Key? key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: UserService().getFollowRequests(),
      builder: (context, followRequestsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: InvitationService().getPendingInvitations(),
          builder: (context, invitationsSnapshot) {
            int totalCount = 0;
            if (followRequestsSnapshot.hasData && followRequestsSnapshot.data!.exists) {
              final userData = followRequestsSnapshot.data!.data() as Map<String, dynamic>?;
              final followRequests = userData?['followRequests'] as Map<String, dynamic>? ?? {};
              totalCount += followRequests.values.where((v) => v['status'] == 'pending').length;
            }
            if (invitationsSnapshot.hasData) {
              totalCount += invitationsSnapshot.data!.docs.length;
            }
            return GestureDetector(
              onTap: onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                    ],
                  ),
                  if (totalCount > 0)
                    Positioned(
                      right: -5,
                      top: 15,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
