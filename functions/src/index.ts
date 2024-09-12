const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cryptor = require('crypto');

admin.initializeApp();

exports.sendInvitationNotification = functions.firestore
    .document('events/{eventId}')
    .onWrite(async (change: any, context: any) => {
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

// Make sure to set these environment variables in your Firebase project
const accountId = functions.config().cloudflare.account_id;
const accessKeyId = functions.config().cloudflare.access_key_id;
const secretAccessKey = functions.config().cloudflare.secret_access_key;
const bucketName = functions.config().cloudflare.bucket_name;

function hmacSha256(key: any, message: any) {
    return cryptor.createHmac('sha256', key).update(message).digest();
}

function getSignatureKey(key: any, dateStamp: any, regionName: any, serviceName: any) {
    const kDate = hmacSha256(`AWS4${key}`, dateStamp);
    const kRegion = hmacSha256(kDate, regionName);
    const kService = hmacSha256(kRegion, serviceName);
    return hmacSha256(kService, 'aws4_request');
}

exports.getR2UploadUrl = functions.https.onCall(async (data: any, context: any) => {
    // Ensure the user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to request upload URL.');
    }

    const fileName = data.fileName;
    if (!fileName) {
        throw new functions.https.HttpsError('invalid-argument', 'fileName is required.');
    }

    const method = 'PUT';
    const service = 's3';
    const region = 'auto';
    const host = `${bucketName}.${accountId}.r2.cloudflarestorage.com`;
    const endpoint = `https://${host}`;

    const dateTimeStamp = new Date().toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = dateTimeStamp.slice(0, 8);

    const canonicalUri = `/${fileName}`;
    const canonicalQueryString = '';
    const payloadHash = 'UNSIGNED-PAYLOAD';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    const canonicalHeaders = `content-type:application/octet-stream\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${dateTimeStamp}\n`;
    
    const canonicalRequest = `${method}\n${canonicalUri}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;

    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
    const stringToSign = `AWS4-HMAC-SHA256\n${dateTimeStamp}\n${credentialScope}\n${cryptor.createHash('sha256').update(canonicalRequest).digest('hex')}`;

    const signingKey = getSignatureKey(secretAccessKey, dateStamp, region, service);
    const signature = cryptor.createHmac('sha256', signingKey).update(stringToSign).digest('hex');

    const authorizationHeader = `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const url = `${endpoint}${canonicalUri}`;
    const headers = {
        'Host': host,
        'X-Amz-Date': dateTimeStamp,
        'X-Amz-Content-Sha256': payloadHash,
        'Authorization': authorizationHeader,
        'Content-Type': 'application/octet-stream',
      };

    console.log('Generated URL:', url);
    console.log('Generated Headers:', headers);

    return { url, headers };
});