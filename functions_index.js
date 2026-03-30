// functions/index.js
// Deploy with: firebase deploy --only functions
//
// Make sure to install: npm install firebase-admin firebase-functions

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Triggers whenever a document is added to /notification_queue.
 * Sends the appropriate FCM push notification to the right party.
 */
exports.processNotificationQueue = onDocumentCreated(
  "notification_queue/{docId}",
  async (event) => {
    const data = event.data.data();
    const { type, storeId, targetFcmToken, body, offerId, productName } = data;

    try {
      let token = targetFcmToken;

      // For owner-targeted notifications, look up the store owner's FCM token
      if (!token && storeId) {
        const storeSnap = await db.collection("stores").doc(storeId).get();
        if (storeSnap.exists) {
          const ownerUid = storeSnap.data().ownerUid;
          if (ownerUid) {
            const userSnap = await db.collection("users").doc(ownerUid).get();
            token = userSnap.data()?.fcmToken ?? null;
          }
        }
      }

      if (!token) {
        console.log(`No FCM token found for type=${type}, storeId=${storeId}`);
        await event.data.ref.update({ status: "no_token" });
        return;
      }

      // Build the notification title based on type
      const titleMap = {
        new_offer: "🛒 Yangi taklif keldi!",
        offer_accepted: "✅ Taklifingiz qabul qilindi!",
        offer_rejected: "❌ Taklif rad etildi",
        offer_countered: "🏷 Yangi narx taklifi",
        counter_accepted: "✅ Mijoz kelishdi!",
        counter_rejected: "❌ Mijoz rad etdi",
      };

      const title = titleMap[type] ?? "Yangi xabar";

      const message = {
        token,
        notification: { title, body },
        data: {
          type,
          offerId: offerId ?? "",
          productName: productName ?? "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "offers_channel",
            priority: "high",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      await messaging.send(message);
      console.log(`✅ Notification sent: type=${type}`);

      // Mark as sent so we don't retry
      await event.data.ref.update({
        status: "sent",
        sentAt: new Date(),
      });
    } catch (err) {
      console.error("❌ Failed to send notification:", err);
      await event.data.ref.update({ status: "error", error: err.message });
    }
  }
);

/**
 * When a store owner logs in, save their FCM token to their user doc.
 * Call this from Flutter after GoogleSignIn + getToken().
 *
 * Flutter side (add this to your owner login flow):
 *   final token = await FirebaseMessaging.instance.getToken();
 *   await FirebaseFirestore.instance.collection('users').doc(uid).update({
 *     'fcmToken': token,
 *   });
 */