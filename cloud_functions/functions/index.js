/**
 * Firebase Cloud Functions for HideAndCSeek50
 *
 * These functions handle sending push notifications for game chat messages
 * and updating player statistics when games are completed.
 */

/* eslint-disable */
const {onValueCreated, onValueDeleted, onValueWritten} = require('firebase-functions/v2/database');
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

/**
 * Update player statistics when a game is completed
 * Triggered when the game state changes to 'completed'
 */
exports.updateGameStatistics = onValueWritten(
    '/games/{gameId}/info/state',
    async (event) => {
      try {
        const gameId = event.params.gameId;
        const newState = event.data.after.val();
        const oldState = event.data.before.val();

        // Only proceed if state changed to 'completed'
        if (newState !== 'completed' || oldState === 'completed') {
          console.log(`Game ${gameId}: State is ${newState}, skipping statistics update`);
          return null;
        }

        console.log(`Game ${gameId}: Updating statistics for completed game`);

        // Get the complete game data
        const gameSnapshot = await getDatabase()
            .ref(`/games/${gameId}`)
            .once('value');

        const gameData = gameSnapshot.val();
        if (!gameData || !gameData.info || !gameData.teams) {
          console.error(`Game ${gameId}: Missing game data`);
          return null;
        }

        const {info, teams} = gameData;

        // Calculate game metrics
        const gameDuration = calculateElapsedTime(info);
        const hidingTime = info.hidingElapsed || 0;
        const seekingTime = info.seekingElapsed || 0;
        const playerCount = (teams.hiders ? Object.keys(teams.hiders).length : 0) +
                           (teams.seekers ? Object.keys(teams.seekers).length : 0);

        // Update stats for hiders
        if (teams.hiders) {
          const hiderUIDs = Object.keys(teams.hiders);
          await Promise.all(hiderUIDs.map(async (uid) => {
            await updatePlayerStats(uid, {
              gameId,
              gameName: info.name,
              team: 'hiders',
              hidingTime,
              seekingTime,
              gameDuration,
              playerCount,
              city: info.settings?.city || 'boston',
              wasHost: info.hostUID === uid,
              endedAt: info.endedAt || Date.now() / 1000,
            });
          }));
        }

        // Update stats for seekers
        if (teams.seekers) {
          const seekerUIDs = Object.keys(teams.seekers);
          await Promise.all(seekerUIDs.map(async (uid) => {
            await updatePlayerStats(uid, {
              gameId,
              gameName: info.name,
              team: 'seekers',
              hidingTime,
              seekingTime,
              gameDuration,
              playerCount,
              city: info.settings?.city || 'boston',
              wasHost: info.hostUID === uid,
              endedAt: info.endedAt || Date.now() / 1000,
            });
          }));
        }

        console.log(`Game ${gameId}: Statistics updated for all players`);
        return null;
      } catch (error) {
        console.error('Error in updateGameStatistics:', error);
        return null;
      }
    });

/**
 * Helper function to update individual player statistics
 * @param {string} uid - Player's user ID
 * @param {Object} gameData - Data about the completed game
 */
async function updatePlayerStats(uid, gameData) {
  try {
    const db = getDatabase();
    const statsRef = db.ref(`/users/${uid}/stats`);

    // Get current stats or initialize new ones
    const statsSnapshot = await statsRef.once('value');
    let stats = statsSnapshot.val() || {
      totalGamesPlayed: 0,
      hiderStats: {
        gamesPlayed: 0,
        averageHidingTime: 0,
        bestHidingTime: 0,
      },
      seekerStats: {
        gamesPlayed: 0,
        averageFindTime: 0,
        bestFindTime: 0,
      },
      achievements: {
        quickSeeker: false,
        masterHider: false,
        teamPlayer: false,
        veteran: false,
      },
    };

    // Update total games
    stats.totalGamesPlayed += 1;

    // Update team-specific stats
    if (gameData.team === 'hiders') {
      stats.hiderStats.gamesPlayed += 1;

      // Update average hiding time
      stats.hiderStats.averageHidingTime =
        (stats.hiderStats.averageHidingTime * (stats.hiderStats.gamesPlayed - 1) +
         gameData.hidingTime) / stats.hiderStats.gamesPlayed;

      // Update best hiding time
      if (gameData.hidingTime > stats.hiderStats.bestHidingTime) {
        stats.hiderStats.bestHidingTime = gameData.hidingTime;
      }

      // Check for master hider achievement (hidden for over 30 minutes)
      if (gameData.hidingTime >= 1800) {
        stats.achievements.masterHider = true;
      }
    } else if (gameData.team === 'seekers') {
      stats.seekerStats.gamesPlayed += 1;

      // Update average find time
      if (gameData.seekingTime > 0) {
        stats.seekerStats.averageFindTime =
          (stats.seekerStats.averageFindTime * (stats.seekerStats.gamesPlayed - 1) +
           gameData.seekingTime) / stats.seekerStats.gamesPlayed;

        // Update best find time
        if (gameData.seekingTime < stats.seekerStats.bestFindTime ||
            stats.seekerStats.bestFindTime === 0) {
          stats.seekerStats.bestFindTime = gameData.seekingTime;
        }

        // Check for quick seeker achievement (found hider in under 5 minutes)
        if (gameData.seekingTime <= 300) {
          stats.achievements.quickSeeker = true;
        }
      }
    }

    // Check for veteran achievement (100+ games)
    if (stats.totalGamesPlayed >= 100) {
      stats.achievements.veteran = true;
    }

    // Save updated stats
    await statsRef.set(stats);

    // Save game history entry
    const historyEntry = {
      id: gameData.gameId,
      gameId: gameData.gameId,
      gameName: gameData.gameName,
      team: gameData.team,
      hidingTime: gameData.hidingTime,
      seekingTime: gameData.seekingTime,
      duration: gameData.gameDuration,
      datePlayed: gameData.endedAt,
      city: gameData.city,
      playerCount: gameData.playerCount,
      wasHost: gameData.wasHost,
    };

    await db.ref(`/users/${uid}/gameHistory/${gameData.gameId}`).set(historyEntry);

    console.log(`Updated stats for player ${uid}`);
  } catch (error) {
    console.error(`Error updating stats for player ${uid}:`, error);
  }
}

/**
 * Helper function to calculate elapsed time from game info
 * @param {Object} info - Game info object
 * @return {number} Elapsed time in seconds
 */
function calculateElapsedTime(info) {
  const hidingElapsed = info.hidingElapsed || 0;
  const seekingElapsed = info.seekingElapsed || 0;
  return hidingElapsed + seekingElapsed;
}
