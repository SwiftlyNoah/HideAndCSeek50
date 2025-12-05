/**
 * Send a direct test notification
 * Run with: node test_direct_notification.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (will use the Firebase Functions environment)
if (!admin.apps.length) {
  admin.initializeApp();
}

const FCM_TOKEN = 'eOjUsIFhY0mapskmSPWCvc:APA91bFWqKqTlo-9VWitUFbxIpObyiFBm0VVkSPYnAetTBVARtbsErjCPb2k-5TYWvMUwAJIEiRrimc04QBGgV5IFi46WbJRGM_xnS9bPteMCUVZONIwoKo';

async function sendTest() {
  console.log('📱 Sending test notification to your iPhone 16 Pro...\n');

  const message = {
    token: FCM_TOKEN,
    notification: {
      title: '🎉 Test Notification',
      body: 'If you see this, your notifications are working!'
    },
    apns: {
      headers: {
        'apns-priority': '10'
      },
      payload: {
        aps: {
          alert: {
            title: '🎉 Test Notification',
            body: 'If you see this, your notifications are working!'
          },
          sound: 'default',
          badge: 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ SUCCESS! Notification sent');
    console.log('📬 Message ID:', response);
    console.log('\n👀 Check your iPhone 16 Pro now!');
    console.log('   The notification should appear on your lock screen');
    console.log('   (Make sure the app is not currently open)\n');
  } catch (error) {
    console.error('❌ ERROR:', error.message);
    console.error('\nFull error:', error);
  }
}

sendTest();
