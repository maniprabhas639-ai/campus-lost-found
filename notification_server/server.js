const express = require('express');
const path = require('path');

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore } = require('firebase-admin/firestore');

function loadServiceAccount() {
  const serviceAccountJson =
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (serviceAccountJson) {
    try {
      const decodedJson = Buffer.from(
        serviceAccountJson.trim(),
        'base64',
      ).toString('utf8');

      return JSON.parse(decodedJson);
    } catch (error) {
      throw new Error(
        'FIREBASE_SERVICE_ACCOUNT_JSON is not valid Base64-encoded JSON.',
      );
    }
  }

  return require(
    path.join(__dirname, 'service-account.json'),
  );
}

const serviceAccount = loadServiceAccount();

const app = initializeApp({
  credential: cert(serviceAccount),
});

const auth = getAuth(app);
const db = getFirestore(app);
const messaging = getMessaging(app);

const server = express();

server.use(express.json());

server.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'CampusFind Notification Server',
  });
});

server.post('/send-message-notification', async (req, res) => {
  try {
    const authorization = req.headers.authorization;

    if (!authorization || !authorization.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Missing authentication token.',
      });
    }

    const idToken = authorization.substring('Bearer '.length).trim();

    if (idToken.length === 0) {
      return res.status(401).json({
        error: 'Missing authentication token.',
      });
    }

    const decodedToken = await auth.verifyIdToken(idToken);
    const senderUserId = decodedToken.uid;

    console.log(
      `Authenticated request from Firebase user: ${senderUserId}`,
    );

    const {
      itemId,
      conversationId,
      title,
      body,
    } = req.body;

    if (
      typeof itemId !== 'string' ||
      typeof conversationId !== 'string' ||
      typeof title !== 'string' ||
      typeof body !== 'string' ||
      itemId.trim().length === 0 ||
      conversationId.trim().length === 0 ||
      title.trim().length === 0 ||
      body.trim().length === 0
    ) {
      return res.status(400).json({
        error: 'Invalid notification data.',
      });
    }

    const trimmedItemId = itemId.trim();
    const trimmedConversationId = conversationId.trim();
    const trimmedTitle = title.trim();
    const trimmedBody = body.trim();

    const conversationReference = db
      .collection('conversations')
      .doc(trimmedConversationId);

    const conversationSnapshot =
      await conversationReference.get();

    if (!conversationSnapshot.exists) {
      return res.status(404).json({
        error: 'Conversation not found.',
      });
    }

    const conversation = conversationSnapshot.data();

    if (!conversation) {
      return res.status(404).json({
        error: 'Conversation data unavailable.',
      });
    }

    if (conversation.itemId !== trimmedItemId) {
      return res.status(400).json({
        error: 'Conversation does not belong to the specified item.',
      });
    }

    const participantIds = conversation.participantIds;

    if (
      !Array.isArray(participantIds) ||
      participantIds.length !== 2 ||
      !participantIds.every(
        (userId) => typeof userId === 'string',
      ) ||
      !participantIds.includes(senderUserId)
    ) {
      return res.status(403).json({
        error: 'You are not a participant in this conversation.',
      });
    }

    const recipientUserId = participantIds.find(
      (userId) => userId !== senderUserId,
    );

    if (!recipientUserId) {
      return res.status(400).json({
        error: 'Unable to determine notification recipient.',
      });
    }

    console.log(
      `Notification recipient Firebase user: ${recipientUserId}`,
    );

    const tokensSnapshot = await db
      .collection('users')
      .doc(recipientUserId)
      .collection('fcmTokens')
      .get();

    if (tokensSnapshot.empty) {
      console.log(
        'Recipient has no registered FCM tokens.',
      );

      return res.json({
        success: true,
        sent: 0,
        failed: 0,
        message: 'Recipient has no registered FCM tokens.',
      });
    }

    const tokenEntries = tokensSnapshot.docs
      .map((document) => {
        const token = document.data().token;

        if (
          typeof token !== 'string' ||
          token.trim().length === 0
        ) {
          return null;
        }

        return {
          token: token.trim(),
          document,
        };
      })
      .filter((entry) => entry !== null);

    if (tokenEntries.length === 0) {
      console.log(
        'Recipient FCM token documents contain no valid tokens.',
      );

      return res.json({
        success: true,
        sent: 0,
        failed: 0,
        message: 'Recipient has no valid FCM tokens.',
      });
    }

    const notificationMessage = {
      notification: {
        title: trimmedTitle,
        body: trimmedBody,
      },
      data: {
        type: 'message',
        itemId: trimmedItemId,
        conversationId: trimmedConversationId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'campusfind_notifications',
        },
      },
    };

    const response = await messaging.sendEachForMulticast({
      tokens: tokenEntries.map((entry) => entry.token),
      ...notificationMessage,
    });

    console.log(
      `FCM notification result: ${response.successCount} sent, ` +
      `${response.failureCount} failed.`,
    );

    for (
      let index = 0;
      index < response.responses.length;
      index++
    ) {
      const sendResponse = response.responses[index];

      if (sendResponse.success) {
        continue;
      }

      const errorCode = sendResponse.error?.code;

      if (
        errorCode ===
        'messaging/registration-token-not-registered'
      ) {
        const tokenDocument = tokenEntries[index].document;

        await tokenDocument.ref.delete();

        console.log(
          'Removed an invalid FCM token.',
        );
      }
    }

    return res.json({
      success: true,
      sent: response.successCount,
      failed: response.failureCount,
    });
  } catch (error) {
    console.error(
      'Notification request failed:',
      error,
    );

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        error: 'Firebase ID token expired.',
      });
    }

    if (
      error.code === 'auth/argument-error' ||
      error.code === 'auth/invalid-id-token'
    ) {
      return res.status(401).json({
        error: 'Invalid Firebase ID token.',
      });
    }

    return res.status(500).json({
      error: 'Notification server error.',
    });
  }
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

server.listen(PORT, HOST, () => {
  console.log(
    `CampusFind Notification Server running on ${HOST}:${PORT}`,
  );
});