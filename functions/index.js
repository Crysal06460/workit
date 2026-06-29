/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const admin = require("firebase-admin");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const OpenAI = require("openai");
const Mailjet = require("node-mailjet");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

initializeApp();
const db = getFirestore();

/**
 * Analyse un devis via OpenAI Vision.
 */
exports.analyzeDevis = onCall(
    {region: "europe-west1", secrets: ["OPENAI_API_KEY"]},
    async (request) => {
      const fileUrl = request.data && request.data.fileUrl;
      if (!fileUrl) {
        throw new Error("fileUrl manquant");
      }
      const openai = getOpenAIClient();

      const systemPrompt =
      `Tu es une IA WorkIt, experte des devis menuiserie/pose
(fenêtres, portes, volets, stores, pergolas).
Objectif: extraire un résumé structuré du devis en français.
Retourne du texte clair (pas de Markdown) avec :
- Client (nom complet)
- Adresse chantier
- Références (modèle/produit), Quantité, Dimensions,
  Couleur/RAL, Matière, Options
- Totaux (HT/TTC si présents)
Si une info manque, ignore-la.`;

      try {
        const response = await openai.responses.create({
          model: "gpt-4o-mini",
          input: [
            {
              role: "system",
              content: systemPrompt,
            },
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: "Analyse ce devis et fournis le résumé structuré.",
                },
                {type: "input_image", image_url: fileUrl, detail: "high"},
              ],
            },
          ],
          response_format: {type: "text"},
        });

        const text = (response && response.output_text) ?
        response.output_text : "";
        logger.info("Analyse terminée", {length: text.length});
        return {text};
      } catch (error) {
        logger.error("Erreur OpenAI", error);
        throw new Error(`Analyse échouée: ${error.message}`);
      }
    },
);

/**
 * Retourne un client OpenAI initialisé.
 * @return {OpenAI} client
 */
function getOpenAIClient() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY non configurée");
  }
  return new OpenAI({apiKey});
}

/**
 * Génère un token d'invitation.
 * @return {string}
 */
function generateToken() {
  return crypto.randomBytes(16).toString("hex");
}

/**
 * Crée une invitation (admin uniquement).
 */
exports.createInvitation = onCall(
    {region: "europe-west1"},
    async (request) => {
      const {email, role, companyId, expiresInDays = 14} =
      request.data || {};
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new Error("Non autorisé");
      if (!email || !role || !companyId) {
        throw new Error("email, role, companyId requis");
      }

      const token = generateToken();
      const invitationId = token; // simple mapping
      const now = Timestamp.now();
      const expiresAt = Timestamp.fromMillis(
          now.toMillis() + expiresInDays * 24 * 60 * 60 * 1000,
      );

      await db.collection("invitations").doc(invitationId).set({
        email: email.toLowerCase(),
        role,
        companyId,
        token,
        status: "pending",
        createdAt: now,
        createdBy: uid,
        expiresAt,
      });

      const inviteUrl = `https://workit.app/invite?token=${token}`;
      return {token, inviteUrl, invitationId};
    },
);

/**
 * Helper: Envoie un email via Mailjet ou SMTP.
 */
async function sendEmail({to, subject, html, text, fromName = "WorkIt"}) {
  const mjApi = process.env.MAILJET_API_KEY;
  const mjSecret = process.env.MAILJET_API_SECRET;
  const useMailjet = mjApi && mjSecret;

  if (useMailjet) {
    try {
      logger.info("Mailjet send start", {to});
      const mailjet = Mailjet.apiConnect(mjApi, mjSecret);
      await mailjet.post("send", {version: "v3.1"}).request({
        Messages: [
          {
            From: {
              Email: process.env.MAILJET_FROM || "noreply@workit.app",
              Name: fromName,
            },
            To: [{Email: to}],
            Subject: subject,
            TextPart: text,
            HTMLPart: html,
          },
        ],
      });
      logger.info("Mailjet send success", {to});
      return true;
    } catch (err) {
      logger.error("Mailjet send failed", {error: err});
      throw new Error("Envoi Mailjet impossible");
    }
  } else {
    try {
      logger.info("SMTP send start", {to, fromName});
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: false,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
      await transporter.sendMail({
        from: `"${fromName}" <${process.env.SMTP_FROM}>`,
        to: to,
        subject: subject,
        html,
        text,
      });
      logger.info("SMTP send success", {to});
      return true;
    } catch (err) {
      logger.error("SMTP send failed", {error: err});
      throw new Error("Envoi SMTP impossible");
    }
  }
}

/**
 * Envoie l'email d'invitation.
 */
exports.sendInvitationEmail = onCall(
    {
      region: "europe-west1",
      secrets: [
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_USER",
        "SMTP_PASS",
        "SMTP_FROM",
        "MAILJET_API_KEY",
        "MAILJET_API_SECRET",
        "MAILJET_FROM",
      ],
    },
    async (request) => {
      const {email, token, companyName = "WorkIt", role = ""} =
      request.data || {};
      if (!email || !token) throw new Error("email et token requis");
      const inviteUrl = `https://workit.app/invite?token=${token}`;

      const html =
      `<div style="font-family:Arial,sans-serif;color:#0B1426">
  <p>Bonjour,</p>
  <p>Vous êtes invité(e) à rejoindre <b>${companyName}</b> en tant que
  <b>${role || "membre"}</b> sur WorkIt.</p>
  <p><a href="${inviteUrl}"
  style="background:#00F795;color:#000;padding:12px 18px;border-radius:10px;
  text-decoration:none;font-weight:bold;">Rejoindre WorkIt</a></p>
  <p>Ce lien expire bientôt. Si vous ne reconnaissez pas cette invitation,
  ignorez ce message.</p>
</div>`;

      const text =
      `Bonjour,

Vous êtes invité(e) à rejoindre ${companyName} (${role}).
Lien: ${inviteUrl}
`;

      await sendEmail({
        to: email,
        subject: `Invitation WorkIt – ${companyName}`,
        html,
        text,
        fromName: "WorkIt",
      });

      return {sent: true};
    },
);

/**
 * Provisionne des comptes avec mot de passe temporaire
 * et envoie les identifiants par email.
 */
exports.provisionAccounts = onCall(
    {
      region: "europe-west1",
      secrets: [
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_USER",
        "SMTP_PASS",
        "SMTP_FROM",
        "MAILJET_API_KEY",
        "MAILJET_API_SECRET",
        "MAILJET_FROM",
      ],
    },
    async (request) => {
      const caller = request.auth && request.auth.uid;
      if (!caller) throw new Error("Non autorisé");
      const accounts = request.data && request.data.accounts;
      if (!Array.isArray(accounts) || accounts.length === 0) {
        throw new Error("accounts requis");
      }

      const results = [];
      const successes = [];
      const errors = [];

      // Récupérer le nom de l'entreprise si possible pour l'email
      let companyName = "WorkIt";
      try {
        if (accounts[0].companyId) {
          const snap = await db.collection("workspaces")
              .doc(accounts[0].companyId).get();
          if (snap.exists) {
            companyName = snap.data().companyName || "WorkIt";
          }
        }
      } catch (_) {
        logger.warn("Could not fetch company name", _);
      }

      for (const acc of accounts) {
        const email = (acc.email || "").toString().trim().toLowerCase();
        const role = (acc.role || "").toString();
        const companyId = (acc.companyId || "").toString();
        if (!email || !role || !companyId) continue;

        const tempPassword = generateTempPassword();
        let userRecord;
        try {
          userRecord = await getAuth().getUserByEmail(email);
          userRecord = await getAuth().updateUser(userRecord.uid, {
            password: tempPassword,
          });
        } catch (_) {
          userRecord = await getAuth().createUser({
            email,
            password: tempPassword,
            displayName: "",
          });
        }

        await getAuth().setCustomUserClaims(userRecord.uid, {
          role,
          companyId,
        });

        const userDoc = {
          email,
          firstName: acc.firstName || "",
          lastName: acc.lastName || "",
          role,
          companyId,
          workspaceId: companyId, // requis par les règles Firestore
          tradeKey: acc.tradeKey || null,
          mustChangePassword: true,
          tempPassword, // On garde trace au cas où, mais l'email part.
          status: "provisioned",
          updatedAt: Timestamp.now(),
          createdBy: caller,
        };

        await db.collection("users").doc(userRecord.uid).set(
            userDoc,
            {merge: true},
        );

        await db.collection("provisioned_accounts").add({
          ...userDoc,
          uid: userRecord.uid,
          createdAt: Timestamp.now(),
        });

        // ENVOI EMAIL CREDENTIALS
        const html = `
<div style="font-family:Arial,sans-serif;color:#0B1426">
  <h2>Bienvenue chez ${companyName} !</h2>
  <p>Votre compte WorkIt a été créé pour le rôle : <b>${role}</b>.</p>
  <p>Voici vos identifiants temporaires :</p>
  <ul>
    <li><b>Email :</b> ${email}</li>
    <li><b>Mot de passe :</b> ${tempPassword}</li>
  </ul>
  <p>Merci de vous connecter dès que possible et de modifier
  ce mot de passe.</p>
  <p><a href="https://workit.app/login"
     style="background:#00F795;color:#000;padding:12px 18px;
     border-radius:10px;text-decoration:none;font-weight:bold;">
     Accéder à WorkIt
  </a></p>
</div>`;

        const text = `Bienvenue chez ${companyName} !\n\n` +
        `Votre compte a été créé (${role}).\n` +
        `Email: ${email}\n` +
        `Mot de passe: ${tempPassword}\n\n` +
        `Merci de vous connecter et de changer votre mot de passe.`;

        try {
          await sendEmail({
            to: email,
            subject: `Vos accès WorkIt – ${companyName}`,
            html,
            text,
            fromName: "WorkIt",
          });
          successes.push(email);
        } catch (err) {
          logger.error(`Erreur envoi email pour ${email}`, err);
          errors.push({email, error: err.message});
        }

        results.push({
          email,
          role,
          companyId,
          tradeKey: acc.tradeKey || null,
          tempPassword,
        });
      }
      return {accounts: results, sent: successes, errors};
    },
);

/**
 * Génère un mot de passe temporaire suffisamment robuste pour un premier accès.
 * @return {string} mot de passe temporaire
 */
function generateTempPassword() {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnpqrstuvwxyz";
  const digit = "0123456789";
  const pick = (pool) => pool[Math.floor(Math.random() * pool.length)];
  const pool = (upper + lower + digit).split("");

  // 8 caractères, au moins 1 lettre majuscule et 1 chiffre,
  // aucun caractère spécial.
  const required = [pick(upper), pick(digit)];
  while (required.length < 8) required.push(pick(pool));
  return required.join("");
}
// ─── FCM Helpers ────────────────────────────────────────────────────────────

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
 */
async function sendNotification(tokens, title, body) {
  if (!tokens || tokens.length === 0) return;
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  if (uniqueTokens.length === 0) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: {title, body},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (e) {
    logger.error("FCM error:", e);
  }
}

// ─── Cloud Function : onDevisStatusChange ───────────────────────────────────

/**
 * Se déclenche à chaque écriture sur un document devis.
 * Envoie des notifications FCM selon le changement de metreurStatus.
 */
exports.onDevisStatusChange = onDocumentWritten(
    "workspaces/{workspaceId}/devis/{devisId}",
    async (event) => {
      const workspaceId = event.params.workspaceId;

      const before = event.data.before.exists ?
        event.data.before.data() : null;
      const after = event.data.after.exists ?
        event.data.after.data() : null;

      if (!after) return null; // Document supprimé, rien à faire.

      // 'status' est le champ actif ; 'metreurStatus' est l'ancien nom
      const statusBefore = before ?
        (before.status || before.metreurStatus || null) : null;
      const statusAfter = after.status || after.metreurStatus || null;

      // Ignorer si le statut n'a pas changé
      if (statusBefore === statusAfter) return null;

      const client = after.clientName || after.client || "client inconnu";
      const address = after.address || after.adresse || "";
      const userId = after.userId || after.commercialId || null;

      try {
      // ── Création du devis (before = null) ──
      // after.metreurStatus = 'Nouvelle demande'
        if (before === null && statusAfter === "Nouvelle demande") {
          const metreurTokens = await getTokensByRole(workspaceId, "metreur");
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [...metreurTokens, ...adminTokens];
          await sendNotification(
              tokens,
              "🔔 Nouveau chantier à métrer",
              `${client} - ${address}`,
          );
          return null;
        }

        // ── Status → 'Acceptée' ──
        if (statusAfter === "Acceptée") {
          const metreurName = after.assignedMetreurName ||
            after.metreurName || "le métreur";
          const tokens = userId ? await getTokenByUid(userId) : [];
          await sendNotification(
              tokens,
              "📅 Métré planifié",
              `Le chantier de ${client} va être métré par ${metreurName}`,
          );
          return null;
        }

        // ── Status → 'À commander' ──
        if (statusAfter === "À commander") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [...commercialTokens, ...adminTokens];
          await sendNotification(
              tokens,
              "✅ Métré terminé",
              `Le métré de ${client} est terminé. ` +
              `La commande peut être passée.`,
          );
          return null;
        }

        // ── Status → 'À planifier' ──
        if (statusAfter === "À planifier") {
          const tokens = userId ? await getTokenByUid(userId) : [];
          await sendNotification(
              tokens,
              "📦 Commande passée",
              `Le chantier ${client} est commandé`,
          );
          return null;
        }

        // ── Status → 'En pose' ──
        if (statusAfter === "En pose") {
          const poseurIds =
            Array.isArray(after.poseurIds) ? after.poseurIds : [];
          const poseurNames = after.poseurNames || "l'équipe de pose";
          const poseDate = after.poseDate || after.dateDebut || "";
          let poseDateStr = "";
          let poseDateTimeStr = "";
          if (poseDate) {
            try {
              const d = poseDate.toDate ?
                poseDate.toDate() : new Date(poseDate);
              poseDateStr = d.toLocaleDateString("fr-FR", {
                day: "2-digit",
                month: "long",
                year: "numeric",
              });
              poseDateTimeStr = d.toLocaleDateString("fr-FR", {
                day: "2-digit",
                month: "long",
              }) + " à " + d.toLocaleTimeString("fr-FR", {
                hour: "2-digit",
                minute: "2-digit",
              });
            } catch (_) {
              poseDateStr = String(poseDate);
              poseDateTimeStr = poseDateStr;
            }
          }

          // Tokens poseurs
          const poseurTokenPromises = poseurIds.map((id) => getTokenByUid(id));
          const poseurTokenArrays = await Promise.all(poseurTokenPromises);
          const poseurTokens = poseurTokenArrays.flat();

          // Tokens commercial + admin
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const managerTokens = [...commercialTokens, ...adminTokens];

          await Promise.all([
            sendNotification(
                poseurTokens,
                "🏗️ Nouveau chantier assigné",
                `${client} le ${poseDateTimeStr}`,
            ),
            sendNotification(
                managerTokens,
                "📋 Pose programmée",
                `${client} le ${poseDateStr} par ${poseurNames}`,
            ),
          ]);
          return null;
        }

        // ── Status → 'Terminé' ──
        if (statusAfter === "Terminé") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [...commercialTokens, ...adminTokens];
          await sendNotification(
              tokens,
              "🎉 Chantier terminé",
              `Le chantier ${client} a été clôturé avec succès`,
          );
          return null;
        }

        // ── Status → 'À clôturer' ──
        if (statusAfter === "À clôturer") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [...commercialTokens, ...adminTokens];
          await sendNotification(
              tokens,
              "⚠️ Problème chantier",
              `Un problème a été signalé sur le chantier ${client}`,
          );
          return null;
        }
      } catch (e) {
        logger.error("onDevisStatusChange error:", e);
      }

      return null;
    });

/**
 * Récupère une invitation par token (preview).
 */
exports.getInvitationByToken = onCall(
    {region: "europe-west1"},
    async (request) => {
      const {token} = request.data || {};
      if (!token) throw new Error("token requis");
      const snap = await db.collection("invitations").doc(token).get();
      if (!snap.exists) throw new Error("Invitation introuvable");
      const data = snap.data();
      if (data.status === "used") {
        throw new Error("Invitation déjà utilisée");
      }
      if (data.expiresAt && data.expiresAt.toMillis() < Date.now()) {
        throw new Error("Invitation expirée");
      }
      return {...data, id: snap.id};
    },
);

/**
 * Consomme une invitation :
 * crée/associe l'utilisateur et marque l'invitation utilisée.
 */
exports.consumeInvitation = onCall(
    {region: "europe-west1"},
    async (request) => {
      const {token, password, firstName = "", lastName = ""} =
      request.data || {};
      if (!token || !password) throw new Error("token et password requis");
      const ref = db.collection("invitations").doc(token);
      const snap = await ref.get();
      if (!snap.exists) throw new Error("Invitation introuvable");
      const data = snap.data();
      if (data.status === "used") throw new Error("Invitation déjà utilisée");
      if (data.expiresAt && data.expiresAt.toMillis() < Date.now()) {
        throw new Error("Invitation expirée");
      }

      const email = data.email;
      const role = data.role;
      const companyId = data.companyId;

      let userRecord;
      try {
        userRecord = await getAuth().getUserByEmail(email);
      } catch (_) {
        userRecord = await getAuth().createUser({
          email,
          password,
          displayName: `${firstName} ${lastName}`.trim(),
        });
      }

      await getAuth().updateUser(userRecord.uid, {
        password,
        displayName:
        `${firstName} ${lastName}`.trim() || userRecord.displayName,
      });

      await getAuth().setCustomUserClaims(userRecord.uid, {
        role,
        companyId,
      });

      await db.collection("users").doc(userRecord.uid).set(
          {
            email,
            firstName,
            lastName,
            role,
            companyId,
            invitationId: token,
            status: "active",
            updatedAt: Timestamp.now(),
          },
          {merge: true},
      );

      await ref.set(
          {
            status: "used",
            usedAt: Timestamp.now(),
            usedBy: userRecord.uid,
          },
          {merge: true},
      );

      return {
        uid: userRecord.uid,
        email,
        role,
        companyId,
        invitationId: token,
      };
    },
);
