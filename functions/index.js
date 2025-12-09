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
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, FieldValue} = require("firebase-admin/firestore");
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
 * Envoie l'email d'invitation.
 * Nécessite des secrets SMTP : SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS,
 * SMTP_FROM.
 * Optionnel : MAILJET_API_KEY, MAILJET_API_SECRET, MAILJET_FROM.
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

      const mjApi = process.env.MAILJET_API_KEY;
      const mjSecret = process.env.MAILJET_API_SECRET;
      const useMailjet = mjApi && mjSecret;

      if (useMailjet) {
        try {
          logger.info("Mailjet send start", {
            to: email,
            from: process.env.MAILJET_FROM,
            company: companyName,
            role,
          });
          const mailjet = Mailjet.apiConnect(mjApi, mjSecret);
          await mailjet.post("send", {version: "v3.1"}).request({
            Messages: [
              {
                From: {
                  Email: process.env.MAILJET_FROM || "noreply@workit.app",
                  Name: "WorkIt",
                },
                To: [{Email: email}],
                Subject: `Invitation WorkIt – ${companyName}`,
                TextPart: text,
                HTMLPart: html,
              },
            ],
          });
          logger.info("Mailjet send success", {to: email});
        } catch (err) {
          logger.error("Mailjet send failed", {error: err});
          throw new Error("Envoi Mailjet impossible");
        }
      } else {
        try {
          logger.info("SMTP send start", {
            to: email,
            from: process.env.SMTP_FROM,
            host: process.env.SMTP_HOST,
            company: companyName,
            role,
          });
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
            from: process.env.SMTP_FROM,
            to: email,
            subject: `Invitation WorkIt – ${companyName}`,
            html,
            text,
          });
          logger.info("SMTP send success", {to: email});
        } catch (err) {
          logger.error("SMTP send failed", {error: err});
          throw new Error("Envoi SMTP impossible");
        }
      }
      return {sent: true};
    },
);

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

/**
 * Provisionne des comptes avec mot de passe temporaire et flag
 * mustChangePassword. Ne fait pas d'envoi d'email.
 * data.accounts: [{email, role, companyId}]
 */
exports.provisionAccounts = onCall(
    {region: "europe-west1"},
    async (request) => {
      const caller = request.auth && request.auth.uid;
      if (!caller) throw new Error("Non autorisé");
      const accounts = request.data && request.data.accounts;
      if (!Array.isArray(accounts) || accounts.length === 0) {
        throw new Error("accounts requis");
      }
      const results = [];
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
          role,
          companyId,
          tradeKey: acc.tradeKey || null,
          mustChangePassword: true,
          tempPassword,
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

        results.push({
          email,
          role,
          companyId,
          tradeKey: acc.tradeKey || null,
          tempPassword,
        });
      }
      return {accounts: results};
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

  // 5 caractères, au moins 1 lettre majuscule et 1 chiffre, aucun caractère spécial.
  const required = [pick(upper), pick(digit)];
  while (required.length < 5) required.push(pick(pool));
  return required.join("");
}
/**
 * Consomme une invitation :
 * crée/associe l'utilisateur et marque l'invitation utilisée.
 */
