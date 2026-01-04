// process.env.TZ = "Asia/Kolkata";
// const { onCall, HttpsError } = require("firebase-functions/v2/https");
// const admin = require("firebase-admin");
// const { RtcTokenBuilder, RtcRole } = require("agora-access-token");
// const { defineSecret } = require("firebase-functions/params");

// // ✅ INIT ONCE
// admin.initializeApp();

// const db = admin.firestore();
// const messaging = admin.messaging();

// // ENV
// const AGORA_APP_ID = "8fc842bb18b545d2ab4453fe61cf6d83"; // Hardcoded as in Dart
// const agoraAppCert = defineSecret("AGORA_APP_CERT");
process.env.TZ = "Asia/Kolkata";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const AGORA_APP_ID = "8fc842bb18b545d2ab4453fe61cf6d83";
const AGORA_APP_CERT = defineSecret("AGORA_APP_CERT");

exports.getAgoraToken = onCall(
  { region: "asia-south1", secrets: [AGORA_APP_CERT] },
  async (req) => {
    const cert = AGORA_APP_CERT.value();

    if (!AGORA_APP_ID || !cert) {
      throw new HttpsError(
        "failed-precondition",
        "Agora App ID / Certificate missing"
      );
    }

    const { channelName, uid } = req.data || {};

    if (!channelName) {
      throw new HttpsError("invalid-argument", "channelName required");
    }

    const agoraUid = Number(uid ?? 0);
    const now = Math.floor(Date.now() / 1000);
    const expire = 3600;

    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      cert,
      channelName,
      agoraUid,
      RtcRole.PUBLISHER,
      now + expire
    );

    return { token };
  }
);

/* =========================================================
   🔔 SEND CHAT PUSH (MULTI DEVICE)
========================================================= */
exports.sendPush = onCall(
  { region: "asia-south1" },
  async (req) => {
    const { uid, title, body, payload } = req.data || {};
    if (!uid) {
      throw new HttpsError("invalid-argument", "uid missing");
    }

    // 🔥 FETCH ALL DEVICES
    const snap = await db
      .collection("deviceTokens")
      .doc(uid)
      .collection("devices")
      .get();

    if (snap.empty) {
      return { success: false, reason: "no devices" };
    }

    const tokens = [];
    snap.forEach((d) => {
      const t = d.data().token;
      if (t) tokens.push(t);
    });

    if (tokens.length === 0) {
      return { success: false, reason: "no tokens" };
    }

    await messaging.sendMulticast({
      tokens,
      notification: { title, body },
      data: payload || {},
      android: { priority: "high" },
    });
    console.log(data)


    return { success: true, sent: tokens.length };
  }
);

/* =========================================================
   📞 CALL PUSH (MULTI DEVICE)
========================================================= */
exports.sendCallNotification = onCall(
  { region: "asia-south1" },
  async (req) => {
    const { targetUid, callerName, channelName, callType } = req.data || {};
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid missing");
    }

    const snap = await db
      .collection("deviceTokens")
      .doc(targetUid)
      .collection("devices")
      .get();

    if (snap.empty) {
      return { success: false, reason: "no devices" };
    }

    const tokens = [];
    snap.forEach((d) => {
      const t = d.data().token;
      if (t) tokens.push(t);
    });

    if (tokens.length === 0) {
      return { success: false };
    }

    await messaging.sendMulticast({
      tokens,
      notification: {
        title: `${callerName} is calling`,
        body:
          callType === "video"
            ? "Incoming Video Call"
            : "Incoming Voice Call",
      },
      data: {
        type: "call",
        channelName,
        callType,
      },
      android: { priority: "high" },
    });

    return { success: true, sent: tokens.length };
  }
);

// /* =========================================================
//    🎥 AGORA TOKEN
// ========================================================= */
// exports.getAgoraToken = onCall(
//   { region: "asia-south1", secrets: ["AGORA_APP_CERT"] },
//   async (req) => {
//     const AGORA_APP_CERT = agoraAppCert.value;

//     if (!AGORA_APP_ID || !AGORA_APP_CERT) {
//       throw new HttpsError("failed-precondition", "Agora ENV missing");
//     }

//     const { channelName, uid } = req.data || {};
//     if (!channelName) {
//       throw new HttpsError("invalid-argument", "channelName required");
//     }

//     const agoraUid = Number(uid ?? 0);
//     const expire = 3600;
//     const now = Math.floor(Date.now() / 1000);

//     const token = RtcTokenBuilder.buildTokenWithUid(
//       AGORA_APP_ID,
//       AGORA_APP_CERT,
//       channelName,
//       agoraUid,
//       RtcRole.PUBLISHER,
//       now + expire
//     );

//     return { token };
//   }
// );
