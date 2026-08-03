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
const {onDocumentWritten, onDocumentCreated} =
  require("firebase-functions/v2/firestore");
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

      // ── Autorisation : admin (tous droits) ou membre délégué
      // (canManageTeam=true) restreint aux rôles listés dans
      // manageableRoles. Un délégué ne peut jamais créer d'admin, ni
      // provisionner en dehors de son propre workspace.
      const callerDoc = await db.collection("users").doc(caller).get();
      if (!callerDoc.exists) throw new Error("Utilisateur inconnu");
      const callerData = callerDoc.data();
      const callerIsAdmin = callerData.role === "admin";
      const callerCanManageTeam = callerData.canManageTeam === true;
      const callerManageableRoles = Array.isArray(callerData.manageableRoles) ?
        callerData.manageableRoles : [];
      const callerWorkspaceId = callerData.workspaceId || callerData.companyId;

      if (!callerIsAdmin && !callerCanManageTeam) {
        throw new Error(
            "Non autorisé : vous n'avez pas les droits pour ajouter des " +
            "membres à l'équipe.",
        );
      }

      const results = [];
      const successes = [];
      const errors = [];

      // Récupérer le nom de l'entreprise si possible pour l'email
      let companyName = "WorkIt";
      try {
        if (callerWorkspaceId) {
          const snap = await db.collection("workspaces")
              .doc(callerWorkspaceId).get();
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
        // Le companyId ne vient jamais du client : toujours celui du
        // workspace de l'appelant, pour empêcher toute injection
        // cross-workspace.
        const companyId = callerWorkspaceId;
        if (!email || !role || !companyId) continue;

        if (role === "admin" && !callerIsAdmin) {
          errors.push({email, error: "Non autorisé à créer un admin"});
          continue;
        }
        if (!callerIsAdmin && !callerManageableRoles.includes(role)) {
          errors.push({
            email,
            error: `Non autorisé à ajouter un compte "${role}"`,
          });
          continue;
        }

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

        // Droits de gestion d'équipe ("chef d'orchestre") : seul un vrai
        // admin peut les accorder au compte créé — un délégué ne peut pas
        // propager ses propres droits à quelqu'un d'autre.
        if (callerIsAdmin && acc.canManageTeam === true) {
          const requested = Array.isArray(acc.manageableRoles) ?
            acc.manageableRoles : [];
          userDoc.canManageTeam = true;
          userDoc.manageableRoles = requested.filter(
              (r) => ["commercial", "metreur", "poseur"].includes(r),
          );
        } else {
          userDoc.canManageTeam = false;
          userDoc.manageableRoles = [];
        }

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

// ─── Cloud Function : onDevisStatusChange ───────────────────────────────────

/**
 * Se déclenche à chaque écriture sur un document devis.
 * Envoie des notifications FCM selon le changement de statut et selon
 * certains champs (note du métreur) qui ne passent pas par le statut.
 */
exports.onDevisStatusChange = onDocumentWritten(
    "workspaces/{workspaceId}/devis/{devisId}",
    async (event) => {
      const workspaceId = event.params.workspaceId;
      const devisId = event.params.devisId;

      const before = event.data.before.exists ?
        event.data.before.data() : null;
      const after = event.data.after.exists ?
        event.data.after.data() : null;

      if (!after) return null; // Document supprimé, rien à faire.

      const client = after.clientName || after.client || "client inconnu";
      const userId = after.userId || after.commercialId || null;
      const baseData = {workspaceId, devisId};

      try {
        // ── Note du métreur ('metreurNote') — indépendant du statut ──
        const noteBefore = before ? (before.metreurNote || null) : null;
        const noteAfter = after.metreurNote || null;
        if (noteAfter && noteAfter !== noteBefore) {
          const tokens = userId ? await getTokenByUid(userId) : [];
          await sendNotification(
              tokens,
              "📋 Message du métreur",
              `${client} : ${noteAfter}`,
              {...baseData, type: "metreurNote"},
          );
        }

        // ── Statut de paiement ('paiementEffectue') — indépendant du
        // statut, renseigné par le poseur en fin de chantier ──
        const paiementBefore = before ?
          (before.paiementEffectue !== undefined ?
            before.paiementEffectue : null) : null;
        const paiementAfter = after.paiementEffectue !== undefined ?
          after.paiementEffectue : null;
        if (paiementAfter !== null && paiementAfter !== paiementBefore) {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const metreurTokens = after.metreurId ?
            await getTokenByUid(after.metreurId) : [];
          const tokens = [...commercialTokens, ...metreurTokens];
          await sendNotification(
              tokens,
              paiementAfter ? "💰 Chantier payé" : "💰 Chantier non payé",
              paiementAfter ?
                `Chantier ${client} payé par le client` :
                `Chantier ${client} pas payé par le client`,
              {...baseData, type: "paiement"},
          );
        }

        // 'status' est le champ actif ; 'metreurStatus' est l'ancien nom
        const statusBefore = before ?
          (before.status || before.metreurStatus || null) : null;
        const statusAfter = after.status || after.metreurStatus || null;

        // Ignorer la suite si le statut n'a pas changé
        if (statusBefore === statusAfter) return null;

        // ── Création du devis (before = null) ──
        // after.metreurStatus = 'Nouvelle demande'
        if (before === null && statusAfter === "Nouvelle demande") {
          // Si un métreur précis a été choisi par le commercial, ne notifier
          // que lui — les autres métreurs ne le verront pas dans leur liste
          // de toute façon. Sinon ("Peu importe"), notifier toute l'équipe
          // de métreurs. L'admin reçoit un message dédié (l'un des 2 seuls
          // événements qui l'intéressent : nouveau chantier + fin de pose).
          const assignedMetreurId = after.metreurId || after.assignedMetreurId;
          const metreurTokens = assignedMetreurId ?
            await getTokenByUid(assignedMetreurId) :
            await getTokensByRole(workspaceId, "metreur");
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          await Promise.all([
            sendNotification(
                metreurTokens,
                "🔔 Nouveau métré à réaliser",
                `Un nouveau métré est à réaliser pour le chantier ${client}`,
                {...baseData, type: "status"},
            ),
            sendNotification(
                adminTokens,
                "🔔 Nouveau chantier",
                `Nouveau chantier ajouté : ${client}`,
                {...baseData, type: "status"},
            ),
          ]);
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
              {...baseData, type: "status"},
          );
          return null;
        }

        // ── Status → 'En cours' (RDV de métré programmé) ──
        if (statusAfter === "En cours") {
          const tokens = userId ? await getTokenByUid(userId) : [];
          const {dateStr, timeStr} = formatFrDateTime(after.meetingAt);
          const when = timeStr ? `le ${dateStr} à ${timeStr}` : `le ${dateStr}`;
          await sendNotification(
              tokens,
              "📅 Rendez-vous de métré confirmé",
              `Le métré du chantier de ${client} est programmé ${when}`,
              {...baseData, type: "status"},
          );
          return null;
        }

        // ── Status → 'À commander' ──
        // Ne concerne pas l'admin (qui ne veut que "nouveau chantier" +
        // "fin de pose").
        if (statusAfter === "À commander") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          await sendNotification(
              commercialTokens,
              "✅ Métré terminé",
              `Le métré de ${client} est terminé. ` +
              `La commande peut être passée.`,
              {...baseData, type: "status"},
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
              {...baseData, type: "status"},
          );
          return null;
        }

        // ── Status → 'En pose' ──
        if (statusAfter === "En pose") {
          const poseurIds =
            Array.isArray(after.poseurIds) ? after.poseurIds : [];
          const poseurNames = after.poseurNames || "l'équipe de pose";
          const poseDate = after.poseDate || after.dateDebut || "";
          const {dateStr: poseDateStr, dateTimeStr: poseDateTimeStr} =
            formatFrDateTime(poseDate);

          // Tokens poseurs
          const poseurTokenPromises = poseurIds.map((id) => getTokenByUid(id));
          const poseurTokenArrays = await Promise.all(poseurTokenPromises);
          const poseurTokens = poseurTokenArrays.flat();

          // Commercial uniquement — l'admin ne veut pas de notif à cette
          // étape (seulement nouveau chantier + fin de pose).
          const commercialTokens = userId ? await getTokenByUid(userId) : [];

          await Promise.all([
            sendNotification(
                poseurTokens,
                "🏗️ Nouveau chantier assigné",
                `${client} le ${poseDateTimeStr}`,
                {...baseData, type: "status"},
            ),
            sendNotification(
                commercialTokens,
                "📋 Pose programmée",
                `${client} le ${poseDateStr} par ${poseurNames}`,
                {...baseData, type: "status"},
            ),
          ]);
          return null;
        }

        // ── Status → 'Terminé' ──
        if (statusAfter === "Terminé") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const metreurTokens = after.metreurId ?
            await getTokenByUid(after.metreurId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [
            ...commercialTokens, ...metreurTokens, ...adminTokens,
          ];
          await sendNotification(
              tokens,
              "🎉 Chantier terminé",
              `Chantier ${client} terminé`,
              {...baseData, type: "status"},
          );
          return null;
        }

        // ── Status → 'À clôturer' (chantier pas terminé) ──
        if (statusAfter === "À clôturer") {
          const commercialTokens = userId ? await getTokenByUid(userId) : [];
          const metreurTokens = after.metreurId ?
            await getTokenByUid(after.metreurId) : [];
          const adminTokens = await getTokensByRole(workspaceId, "admin");
          const tokens = [
            ...commercialTokens, ...metreurTokens, ...adminTokens,
          ];
          const raison = (after.rapportProbleme &&
            after.rapportProbleme.raison) || null;
          await sendNotification(
              tokens,
              "⚠️ Chantier pas terminé",
              raison ?
                `Chantier ${client} pas terminé car ${raison}` :
                `Chantier ${client} pas terminé`,
              {...baseData, type: "status"},
          );
          return null;
        }
      } catch (e) {
        logger.error("onDevisStatusChange error:", e);
      }

      return null;
    });

// ─── Cloud Function : onChantierMessageCreated ──────────────────────────────

/**
 * Se déclenche à chaque nouveau message dans la messagerie d'un chantier.
 * Notifie tous les participants du dossier (commercial, métreur, poseurs,
 * admins) sauf l'auteur du message.
 */
exports.onChantierMessageCreated = onDocumentCreated(
    "workspaces/{workspaceId}/devis/{devisId}/messages/{messageId}",
    async (event) => {
      const workspaceId = event.params.workspaceId;
      const devisId = event.params.devisId;
      const messageSnap = event.data;
      if (!messageSnap) return null;

      const message = messageSnap.data();
      const senderId = message.senderId;
      const senderName = message.senderName || "Un membre de l'équipe";
      const text = (message.text || "").toString();

      try {
        const devisDoc = await db
            .doc(`workspaces/${workspaceId}/devis/${devisId}`)
            .get();
        if (!devisDoc.exists) return null;
        const devis = devisDoc.data();
        const client = devis.clientName || devis.client || "un chantier";

        const recipientIds = [
          devis.userId || devis.commercialId,
          devis.metreurId,
          ...(Array.isArray(devis.poseurIds) ? devis.poseurIds : []),
        ].filter((id) => id && id !== senderId);

        const recipientTokenArrays = await Promise.all(
            recipientIds.map((id) => getTokenByUid(id)),
        );
        const adminTokens = await getTokensByRole(workspaceId, "admin");

        // Exclure le token de l'auteur (au cas où il serait aussi admin).
        const senderTokens = new Set(await getTokenByUid(senderId));
        const tokens = [
          ...recipientTokenArrays.flat(),
          ...adminTokens,
        ].filter((t) => !senderTokens.has(t));

        const preview = text.length > 80 ? text.substring(0, 80) + "…" : text;
        const body = text ?
          `${senderName} : ${preview}` :
          `${senderName} a envoyé une pièce jointe`;

        await sendNotification(
            tokens,
            `💬 Nouveau message — ${client}`,
            body,
            {workspaceId, devisId, type: "chat"},
        );
      } catch (e) {
        logger.error("onChantierMessageCreated error:", e);
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
