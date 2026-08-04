/**
 * Helpers partagés pour l'envoi de notifications (push FCM + in-app),
 * utilisés par le trigger onDevisStatusChange et par le moteur de
 * transitions de statut (devisWorkflow.js).
 */

const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

/**
 * Récupère les tokens FCM des utilisateurs d'un workspace par rôle.
 * @param {string} workspaceId
 * @param {string} role
 * @return {Promise<string[]>}
 */
async function getTokensByRole(workspaceId, role) {
  const snap = await admin.firestore()
      .collection("users")
      .where("companyId", "==", workspaceId)
      .where("role", "==", role)
      .get();
  return snap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => token && token.length > 0);
}

/**
 * Récupère le token FCM d'un utilisateur par son uid.
 * @param {string} uid
 * @return {Promise<string[]>}
 */
async function getTokenByUid(uid) {
  const doc = await admin.firestore().collection("users").doc(uid).get();
  const token = doc.data() && doc.data().fcmToken;
  return token ? [token] : [];
}

/**
 * Envoie une notification FCM à une liste de tokens.
 * @param {string[]} tokens
 * @param {string} title
 * @param {string} body
 * @param {Object<string, string>} [data] Payload additionnel pour le deep-link.
 */
async function sendNotification(tokens, title, body, data) {
  if (!tokens || tokens.length === 0) return;
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  if (uniqueTokens.length === 0) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: {title, body},
      data: data || {},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (e) {
    logger.error("FCM error:", e);
  }
}

/**
 * Formate une Timestamp Firestore (ou date-like) en chaînes FR.
 * @param {*} ts Timestamp Firestore, Date, ou string.
 * @return {{dateStr: string, timeStr: string, dateTimeStr: string}}
 */
function formatFrDateTime(ts) {
  if (!ts) return {dateStr: "", timeStr: "", dateTimeStr: ""};
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    const dateStr = d.toLocaleDateString("fr-FR", {
      day: "2-digit",
      month: "long",
      year: "numeric",
    });
    const timeStr = d.toLocaleTimeString("fr-FR", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const dateTimeStr = d.toLocaleDateString("fr-FR", {
      day: "2-digit",
      month: "long",
    }) + " à " + timeStr;
    return {dateStr, timeStr, dateTimeStr};
  } catch (_) {
    const s = String(ts);
    return {dateStr: s, timeStr: "", dateTimeStr: s};
  }
}

/**
 * Écrit une notification in-app dans workspaces/{workspaceId}/notifications,
 * lue par les écrans clients (badge non-lu filtré par targetRole).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} params {workspaceId, devisId, targetRole, type, title, body}
 */
async function writeInAppNotification(db, params) {
  const {workspaceId, devisId, targetRole, type, title, body} = params;
  try {
    await db.collection("workspaces").doc(workspaceId)
        .collection("notifications").add({
          devisId,
          targetRole,
          type,
          title,
          body,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
  } catch (e) {
    logger.error("Erreur écriture notification in-app", e);
  }
}

module.exports = {
  getTokensByRole,
  getTokenByUid,
  sendNotification,
  formatFrDateTime,
  writeInAppNotification,
};
