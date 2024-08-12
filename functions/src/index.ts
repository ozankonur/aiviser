const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendInvitationNotification = functions.firestore
    .document('events/{eventId}')
    .onWrite(async (change: any , context: any) => {
        const eventId = context.params.eventId;
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // If the document was deleted, we don't need to send notifications
        if (!newValue) {
            console.log('Event was deleted, no notifications needed');
            return null;
        }

        const invitationStatuses = newValue.invitationStatuses || {};
        const previousInvitationStatuses = previousValue ? (previousValue.invitationStatuses || {}) : {};

        const newInvitees = Object.keys(invitationStatuses).filter(userId =>
            invitationStatuses[userId] === 'pending' && (!previousInvitationStatuses[userId] || previousInvitationStatuses[userId] !== 'pending')
        );

        if (newInvitees.length === 0) {
            console.log('No new invitees, no notifications needed');
            return null;
        }

        const eventOwner = newValue.owner;
        const ownerSnapshot = await admin.firestore().collection('users').doc(eventOwner).get();
        const ownerName = ownerSnapshot.data().username || 'A user';

        const placeName = newValue.placeName || 'an event';
        const eventTime = newValue.scheduledTime.toDate();

        const notificationPromises = newInvitees.map(async (userId) => {
            const userSnapshot = await admin.firestore().collection('users').doc(userId).get();
            const fcmToken = userSnapshot.data().fcmToken;

            if (!fcmToken) {
                console.log(`User ${userId} doesn't have an FCM token`);
                return null;
            }

            const message = {
                notification: {
                    title: 'New Event Invitation',
                    body: `${ownerName} has invited you to ${placeName} on ${eventTime.toLocaleString()}`
                },
                data: {
                    eventId: eventId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                token: fcmToken
            };

            return admin.messaging().send(message);
        });

        try {
            await Promise.all(notificationPromises);
            console.log(`Successfully sent notifications to ${newInvitees.length} users`);
            return null;
        } catch (error) {
            console.error('Error sending notifications:', error);
            return null;
        }
    });