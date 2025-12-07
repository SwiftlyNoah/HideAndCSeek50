/**
 * Firebase Cloud Functions for HideAndCSeek50
 *
 * These functions handle sending push notifications for game chat messages.
 */

/* eslint-disable */
const {onValueCreated, onValueDeleted} = require('firebase-functions/v2/database');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getDatabase} = require('firebase-admin/database');
const {getMessaging} = require('firebase-admin/messaging');

// Initialize Firebase Admin
initializeApp();

/**
 * Triggered when a new message is added to a game's chat
 * Sends a push notification to all players in the game except the sender
 */
exports.sendChatNotification = onValueCreated(
    '/games/{gameId}/messages/{messageId}',
    async (event) => {
      try {
        const messageData = event.data.val();
        const gameId = event.params.gameId;
        const messageId = event.params.messageId;

        console.log(`New message in game ${gameId}:`, messageData);

        // Don't send notifications for system messages or events
        if (messageData.senderUID === 'system' || messageData.type === 'event') {
          console.log('Skipping notification for system message');
          return null;
        }

        // Get game data to find all players
        const gameSnapshot = await getDatabase()
            .ref(`/games/${gameId}/teams`)
            .once('value');

        const teams = gameSnapshot.val();
        if (!teams) {
          console.log('No teams found for game');
          return null;
        }

        // Collect all player UIDs except the sender
        const playerUIDs = [];

        // Get hiders
        if (teams.hiders) {
          Object.keys(teams.hiders).forEach((uid) => {
            if (uid !== messageData.senderUID) {
              playerUIDs.push(uid);
            }
          });
        }

        // Get seekers
        if (teams.seekers) {
          Object.keys(teams.seekers).forEach((uid) => {
            if (uid !== messageData.senderUID) {
              playerUIDs.push(uid);
            }
          });
        }

        if (playerUIDs.length === 0) {
          console.log('No other players to notify');
          return null;
        }

        // Determine message preview based on type
        let messagePreview = '';
        const notificationTitle = `${messageData.senderName}`;

        switch (messageData.type) {
          case 'text':
            messagePreview = messageData.content;
            break;
          case 'photo':
            messagePreview = '📷 Sent a photo';
            break;
          case 'question':
            messagePreview = `❓ ${messageData.content}`;
            break;
          default:
            messagePreview = 'Sent a message';
        }

        // Truncate long messages
        if (messagePreview.length > 100) {
          messagePreview = messagePreview.substring(0, 97) + '...';
        }

        // Create notification payload
        const payload = {
          notification: {
            title: notificationTitle,
            body: messagePreview,
          },
          data: {
            gameId: gameId,
            messageId: messageId,
            type: 'chat_message',
            senderUID: messageData.senderUID,
            senderName: messageData.senderName,
            timestamp: String(messageData.timestamp || Date.now()),
          },
        };

        // Send to individual tokens (excludes sender)
        return sendToIndividualTokens(playerUIDs, payload);
      } catch (error) {
        console.error('Error in sendChatNotification:', error);
        return null;
      }
    });

/**
 * Helper function to send notifications to individual FCM tokens
 * Used as fallback if topic messaging fails
 * @param {Array<string>} playerUIDs - Array of player UIDs
 * @param {Object} payload - Notification payload
 * @return {Promise}
 */
async function sendToIndividualTokens(playerUIDs, payload) {
  try {
    // Fetch FCM tokens for each player
    const tokenPromises = playerUIDs.map(async (uid) => {
      const snapshot = await getDatabase()
          .ref(`/users/${uid}/fcmToken`)
          .once('value');
      return snapshot.val();
    });

    const tokens = (await Promise.all(tokenPromises))
        .filter((token) => token != null);

    if (tokens.length === 0) {
      console.log('No FCM tokens found for players');
      return null;
    }

    console.log(`Sending to ${tokens.length} individual tokens`);

    // Send multicast message
    const response = await getMessaging().sendEachForMulticast({
      tokens: tokens,
      notification: payload.notification,
      data: payload.data,
      apns: {
        payload: {
          aps: {
            alert: {
              title: payload.notification.title,
              body: payload.notification.body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`Successfully sent ${response.successCount} notifications`);
    if (response.failureCount > 0) {
      console.log(`Failed to send ${response.failureCount} notifications`);
    }

    return response;
  } catch (error) {
    console.error('Error sending to individual tokens:', error);
    return null;
  }
}

/**
 * Clean up old FCM tokens when they become invalid
 * This runs daily to remove expired tokens
 */
exports.cleanupInvalidTokens = onSchedule('every 24 hours', async (event) => {
  console.log('Running token cleanup...');

  try {
    const usersSnapshot = await getDatabase()
        .ref('/users')
        .once('value');

    const users = usersSnapshot.val();
    if (!users) {
      console.log('No users found');
      return null;
    }

    let cleanedCount = 0;
    const updatePromises = [];

    for (const [uid, userData] of Object.entries(users)) {
      if (userData.fcmToken && userData.fcmTokenUpdatedAt) {
        const tokenAge = Date.now() - (userData.fcmTokenUpdatedAt * 1000);
        const sixtyDaysInMs = 60 * 24 * 60 * 60 * 1000;

        // Remove tokens older than 60 days
        if (tokenAge > sixtyDaysInMs) {
          updatePromises.push(
              getDatabase()
                  .ref(`/users/${uid}/fcmToken`)
                  .remove(),
          );
          cleanedCount++;
        }
      }
    }

    await Promise.all(updatePromises);
    console.log(`Cleaned up ${cleanedCount} old FCM tokens`);

    return null;
  } catch (error) {
    console.error('Error in token cleanup:', error);
    return null;
  }
});

/**
 * Handle when a player joins a game
 * Automatically subscribe them to game notifications
 */
exports.onPlayerJoinGame = onValueCreated(
    '/games/{gameId}/teams/{team}/{playerUID}',
    async (event) => {
      const gameId = event.params.gameId;
      const playerUID = event.params.playerUID;

      try {
        // Get player's FCM token
        const tokenSnapshot = await getDatabase()
            .ref(`/users/${playerUID}/fcmToken`)
            .once('value');

        const fcmToken = tokenSnapshot.val();
        if (!fcmToken) {
          console.log(`No FCM token found for player ${playerUID}`);
          return null;
        }

        // Subscribe to game topic
        const topic = `game_${gameId}`;
        await getMessaging().subscribeToTopic([fcmToken], topic);

        console.log(`Subscribed player ${playerUID} to topic ${topic}`);
        return null;
      } catch (error) {
        console.error('Error subscribing player to topic:', error);
        return null;
      }
    });

/**
 * Handle when a player leaves a game
 * Automatically unsubscribe them from game notifications
 */
exports.onPlayerLeaveGame = onValueDeleted(
    '/games/{gameId}/teams/{team}/{playerUID}',
    async (event) => {
      const gameId = event.params.gameId;
      const playerUID = event.params.playerUID;

      try {
        // Get player's FCM token
        const tokenSnapshot = await getDatabase()
            .ref(`/users/${playerUID}/fcmToken`)
            .once('value');

        const fcmToken = tokenSnapshot.val();
        if (!fcmToken) {
          console.log(`No FCM token found for player ${playerUID}`);
          return null;
        }

        // Unsubscribe from game topic
        const topic = `game_${gameId}`;
        await getMessaging().unsubscribeFromTopic([fcmToken], topic);

        console.log(`Unsubscribed player ${playerUID} from topic ${topic}`);
        return null;
      } catch (error) {
        console.error('Error unsubscribing player from topic:', error);
        return null;
      }
    });
