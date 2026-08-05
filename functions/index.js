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
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const OpenAI = require("openai");
const Mailjet = require("node-mailjet");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");
const {
  getTokensByRole,
  getTokenByUid,
  sendNotification,
} = require("./notifyHelpers");
const {
  findTransition, notifyTransition,
  aggregateDevisStatus, aggregateUnion, aggregateEarliest,
  LOT_TERMINAL_STATUSES,
} = require("./devisWorkflow");

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

initializeApp();
const db = getFirestore();

// Quota mensuel par workspace sur les analyses IA (point d'ancrage —
// plafond ajustable facilement plus tard, ex. par plan tarifaire).
const MONTHLY_AI_QUOTA = 100;

/**
 * Vérifie et incrémente le quota mensuel d'analyses IA d'un workspace.
 * Lève une erreur si le quota est dépassé.
 * @param {string} workspaceId
 */
async function checkAndIncrementAiQuota(workspaceId) {
  const usageRef = db.collection("workspaces").doc(workspaceId)
      .collection("usage").doc("aiAnalysis");
  const monthKey = new Date().toISOString().slice(0, 7); // ex. "2026-08"

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(usageRef);
    const data = snap.exists ? snap.data() : {};
    const currentCount = data.monthKey === monthKey ? (data.count || 0) : 0;
    if (currentCount >= MONTHLY_AI_QUOTA) {
      throw new Error(
          `Quota mensuel d'analyses IA atteint (${MONTHLY_AI_QUOTA}/mois). ` +
          "Contactez le support pour l'augmenter.",
      );
    }
    tx.set(usageRef, {monthKey, count: currentCount + 1}, {merge: true});
  });
}

/**
 * Écrit une entrée dans le journal d'audit immuable d'un workspace.
 * @param {string} workspaceId
 * @param {Object} entry {action, targetUid, targetEmail, performedBy,
 *   performedByRole, details}
 */
async function logAuditEvent(workspaceId, entry) {
  try {
    await db.collection("workspaces").doc(workspaceId)
        .collection("auditLogs").add({
          ...entry,
          timestamp: Timestamp.now(),
        });
  } catch (e) {
    logger.error("Erreur écriture audit log", e);
  }
}

/**
 * Analyse un devis via OpenAI Vision.
 */
exports.analyzeDevis = onCall(
    {region: "europe-west1", secrets: ["OPENAI_API_KEY"]},
    async (request) => {
      const caller = request.auth && request.auth.uid;
      if (!caller) throw new Error("Non autorisé");
      const fileUrl = request.data && request.data.fileUrl;
      if (!fileUrl) {
        throw new Error("fileUrl manquant");
      }

      const callerDoc = await db.collection("users").doc(caller).get();
      const callerWorkspaceId = callerDoc.exists ?
        (callerDoc.data().workspaceId || callerDoc.data().companyId) : null;
      if (!callerWorkspaceId) throw new Error("Espace de travail introuvable");
      await checkAndIncrementAiQuota(callerWorkspaceId);

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

        let userRecord;
        try {
          userRecord = await getAuth().getUserByEmail(email);
          // Compte existant : son mot de passe actuel n'est pas modifié —
          // le lien d'activation (généré plus bas) lui permettra d'en
          // définir un nouveau s'il le souhaite.
        } catch (_) {
          // Nouveau compte : créé sans mot de passe connu de personne
          // (valeur jetable, jamais stockée ni renvoyée) — l'activation se
          // fait exclusivement via le lien de réinitialisation Firebase.
          userRecord = await getAuth().createUser({
            email,
            password: generateTempPassword(),
            displayName: "",
          });
        }

        await getAuth().setCustomUserClaims(userRecord.uid, {
          role,
          companyId,
        });

        const activationLink = await getAuth().generatePasswordResetLink(email);

        const userDoc = {
          email,
          firstName: acc.firstName || "",
          lastName: acc.lastName || "",
          role,
          companyId,
          workspaceId: companyId, // requis par les règles Firestore
          tradeKey: acc.tradeKey || null,
          mustChangePassword: true,
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

        await logAuditEvent(companyId, {
          action: "account_created",
          targetUid: userRecord.uid,
          targetEmail: email,
          performedBy: caller,
          performedByRole: callerIsAdmin ? "admin" : "delegate",
          details: {role, canManageTeam: userDoc.canManageTeam},
        });

        // ENVOI EMAIL — lien d'activation, jamais de mot de passe en clair
        const html = `
<div style="font-family:Arial,sans-serif;color:#0B1426">
  <h2>Bienvenue chez ${companyName} !</h2>
  <p>Votre compte WorkIt a été créé pour le rôle : <b>${role}</b>.</p>
  <p>Cliquez sur le lien ci-dessous pour activer votre compte et définir
  votre mot de passe :</p>
  <p><a href="${activationLink}"
     style="background:#00F795;color:#000;padding:12px 18px;
     border-radius:10px;text-decoration:none;font-weight:bold;">
     Activer mon compte
  </a></p>
  <p>Une fois votre mot de passe défini, connectez-vous depuis l'app
  WorkIt avec votre email.</p>
</div>`;

        const text = `Bienvenue chez ${companyName} !\n\n` +
        `Votre compte a été créé (${role}).\n` +
        `Email: ${email}\n` +
        `Activez votre compte : ${activationLink}\n\n` +
        `Une fois votre mot de passe défini, connectez-vous depuis l'app.`;

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
          activationLink,
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
// (getTokensByRole / getTokenByUid / sendNotification / formatFrDateTime sont
// désormais dans notifyHelpers.js, partagés avec devisWorkflow.js.)

// ─── Cloud Function : transitionDevisStatus ─────────────────────────────────

/**
 * Point d'entrée unique pour toute transition de statut d'un chantier
 * (workspaces/{workspaceId}/devis/{devisId}) OU, depuis la Phase 3
 * (multi-lots), d'un de ses lots (workspaces/{workspaceId}/devis/{devisId}/
 * lots/{lotId}) quand `lotId` est fourni. Vérifie les droits (rôle,
 * appartenance workspace, assignation poseur si requise, dépendances entre
 * lots si requises) et la liste des champs additionnels autorisés
 * (devisWorkflow.js), écrit le nouveau statut et une entrée d'historique
 * immuable de façon atomique (transaction), puis envoie les notifications.
 *
 * Phase 3 — cycle de vie des lots : un devis n'a pas de lots tant que son
 * métré n'est pas terminé. Les lots naissent, un par `metierKey` distinct
 * parmi les produits, au moment même du passage devis-level "À commander"
 * (voir plus bas dans cette fonction) — pas avant, pour éviter des lots
 * orphelins si le métreur supprime des produits pendant le métré (pas d'UI
 * d'ajout de produit après le métré). Une fois les lots créés, TOUTE
 * transition ultérieure de ce devis DOIT fournir `lotId` : appeler cette
 * fonction sans `lotId` sur un devis qui a des lots est refusé (garde-fou
 * ci-dessous) — Planner (glisser-déposer) et l'écran poseur (clôture)
 * n'ont pas encore la notion de lot et échoueront proprement sur ces
 * chantiers-là tant qu'ils n'auront pas été adaptés (session suivante).
 */
exports.transitionDevisStatus = onCall(
    {region: "europe-west1"},
    async (request) => {
      const callerUid = request.auth && request.auth.uid;
      if (!callerUid) throw new Error("Non autorisé");

      const data = request.data || {};
      const workspaceId = data.workspaceId;
      const devisId = data.devisId;
      const lotId = data.lotId || null;
      const newStatus = data.newStatus;
      const extraFields =
        (data.extraFields && typeof data.extraFields === "object") ?
          data.extraFields : {};
      const comment = data.comment || null;
      const origin = data.origin || "app";

      if (!workspaceId || !devisId || !newStatus) {
        throw new Error("workspaceId, devisId et newStatus sont requis");
      }

      const callerDoc = await db.collection("users").doc(callerUid).get();
      if (!callerDoc.exists) throw new Error("Utilisateur inconnu");
      const callerData = callerDoc.data();
      const callerRole = callerData.role;
      const callerWorkspaceId = callerData.workspaceId || callerData.companyId;

      const workspaceDoc =
        await db.collection("workspaces").doc(workspaceId).get();
      if (!workspaceDoc.exists) {
        throw new Error("Espace de travail introuvable");
      }
      const isWorkspaceAdmin = workspaceDoc.data().adminUid === callerUid;
      if (!isWorkspaceAdmin && callerWorkspaceId !== workspaceId) {
        throw new Error(
            "Non autorisé : ce chantier n'appartient pas à votre espace " +
            "de travail",
        );
      }

      const devisRef = db.collection("workspaces").doc(workspaceId)
          .collection("devis").doc(devisId);

      let fromStatus = null;
      let after = null;
      // Données fusionnées utilisées pour les notifications : toujours les
      // champs du devis (identité client, etc.), même quand la transition
      // porte sur un lot — voir devisWorkflow.js:notifyTransition.
      let notifyAfter = null;
      let lotContext = null;

      await db.runTransaction(async (tx) => {
        // ── Lectures (toutes avant la moindre écriture, exigé par
        // l'API transaction Firestore) ──────────────────────────────────
        const devisSnap = await tx.get(devisRef);
        if (!devisSnap.exists) throw new Error("Chantier introuvable");
        const devisData = devisSnap.data();
        const existingLotIds =
          Array.isArray(devisData.lotIds) ? devisData.lotIds : [];

        if (!lotId && existingLotIds.length > 0) {
          throw new Error(
              "Ce chantier a des lots : indiquez lotId pour cette " +
              "transition (Planner et clôture poseur pas encore adaptés " +
              "aux lots — utilisez l'écran métreur).",
          );
        }

        let current;
        let targetRef;
        let lotSnap = null;
        if (lotId) {
          lotSnap = await tx.get(devisRef.collection("lots").doc(lotId));
          if (!lotSnap.exists) throw new Error("Lot introuvable");
          current = lotSnap.data();
          fromStatus = current.status || null;
          targetRef = lotSnap.ref;
        } else {
          current = devisData;
          fromStatus = current.status || current.metreurStatus || null;
          targetRef = devisRef;
        }

        const transition = findTransition(fromStatus, newStatus);
        if (!transition) {
          throw new Error(
              `Transition non autorisée : ${fromStatus || "(aucun statut)"} ` +
              `→ ${newStatus}`,
          );
        }
        if (!transition.roles.includes(callerRole)) {
          throw new Error(
              `Non autorisé : le rôle ${callerRole} ne peut pas effectuer ` +
              "cette transition",
          );
        }
        if (transition.requirePoseurAssigned) {
          const poseurIds =
            Array.isArray(current.poseurIds) ? current.poseurIds : [];
          if (!poseurIds.includes(callerUid)) {
            throw new Error(
                "Non autorisé : vous n'êtes pas assigné à ce chantier",
            );
          }
        }

        // Dépendances entre lots (Phase 3) : lecture des lots amonts, encore
        // dans la phase "lecture" de la transaction.
        if (lotId && transition.requiresDependenciesValidated) {
          const dependsOn =
            Array.isArray(current.dependsOn) ? current.dependsOn : [];
          for (const depId of dependsOn) {
            const depSnap = await tx.get(devisRef.collection("lots")
                .doc(depId));
            const depData = depSnap.exists ? depSnap.data() : null;
            const depStatus = depData ? depData.status : null;
            if (!LOT_TERMINAL_STATUSES.has(depStatus)) {
              const depLabel = (depData && depData.label) || depId;
              throw new Error(
                  `Bloqué par le lot "${depLabel}" (pas encore terminé)`,
              );
            }
          }
        }

        const rejectedKeys = Object.keys(extraFields)
            .filter((k) => !transition.extraFields.includes(k));
        if (rejectedKeys.length > 0) {
          throw new Error(
              "Champ(s) non autorisé(s) pour cette transition : " +
              rejectedKeys.join(", "),
          );
        }

        // Lecture des lots frères, nécessaire pour recalculer l'agrégat sur
        // le devis parent après l'écriture d'un lot — toujours dans la phase
        // lecture (avant toute écriture).
        const siblingLotDataById = {};
        if (lotId) {
          const siblingIds = existingLotIds.filter((id) => id !== lotId);
          const siblingSnaps = await Promise.all(
              siblingIds.map((id) =>
                tx.get(devisRef.collection("lots").doc(id))),
          );
          siblingSnaps.forEach((s, i) => {
            if (s.exists) siblingLotDataById[siblingIds[i]] = s.data();
          });
        }

        // ── Calculs (aucune lecture au-delà de ce point) ────────────────
        const now = Timestamp.now();
        const updatePayload = {
          status: newStatus,
          updatedAt: now,
          ...extraFields,
        };
        // Les dates transitent en ISO string (le SDK cloud_functions ne
        // sait pas sérialiser un Timestamp Firestore) : reconverties ici en
        // Timestamp pour rester compatibles avec tous les écrans qui les
        // lisent déjà comme des Timestamp.
        for (const key of transition.dateFields || []) {
          if (extraFields[key]) {
            updatePayload[key] = Timestamp.fromDate(new Date(extraFields[key]));
          }
        }
        if (extraFields.rapportProbleme) {
          updatePayload.rapportProbleme = {
            ...extraFields.rapportProbleme,
            signaledAt: now,
          };
        }
        if (Object.prototype.hasOwnProperty
            .call(extraFields, "paiementEffectue")) {
          updatePayload.paiementSetAt = now;
        }
        if (newStatus === "Terminé") {
          updatePayload.clotureAt = now;
        }
        if (callerRole === "metreur" && !lotId) {
          updatePayload.metreurId = callerUid;
          updatePayload.metreurUpdatedAt = now;
        }

        // Phase 3 — naissance des lots : premier passage devis-level en
        // "À commander" sur un devis qui n'en a pas encore. Regroupe les
        // produits du draft final par metierKey distinct, un lot par
        // groupe, tous au statut "À commander".
        let seededLots = null;
        if (!lotId && newStatus === "À commander" &&
            existingLotIds.length === 0) {
          const draft = updatePayload.draft || current.draft || {};
          const products =
            Array.isArray(draft.products) ? draft.products : [];
          const metierLabels =
            (extraFields.metierLabels &&
              typeof extraFields.metierLabels === "object") ?
              extraFields.metierLabels : {};
          const seenKeys = [];
          for (const p of products) {
            const key = (p && p.metierKey) ? p.metierKey : "_non_classe";
            if (!seenKeys.includes(key)) seenKeys.push(key);
          }
          if (seenKeys.length > 0) {
            seededLots = seenKeys.map((key) => ({
              lotId: key,
              data: {
                metierKey: key,
                label: metierLabels[key] || key,
                status: "À commander",
                poseurIds: [],
                poseurNames: "",
                teamId: null,
                poseDate: null,
                estimatedDurationDays: null,
                poseurCountRequired: 1,
                materielRequis: "",
                dependsOn: [],
                createdAt: now,
                updatedAt: now,
              },
            }));
            updatePayload.lotIds = seenKeys;
            updatePayload.lotsSummary = seededLots.map((l) => ({
              lotId: l.lotId,
              metierKey: l.data.metierKey,
              label: l.data.label,
              status: l.data.status,
              poseurIds: l.data.poseurIds,
              poseurNames: l.data.poseurNames,
              poseDate: l.data.poseDate,
              teamId: l.data.teamId,
              dependsOn: l.data.dependsOn,
              estimatedDurationDays: l.data.estimatedDurationDays,
              poseurCountRequired: l.data.poseurCountRequired,
              materielRequis: l.data.materielRequis,
            }));
          }
        }

        // Phase 3 — agrégat sur le devis parent après écriture d'un lot :
        // fusionne le lot transitionné (nouveau statut) avec ses frères
        // (statut inchangé, lu ci-dessus) pour recalculer status/poseurIds/
        // poseDate/lotsSummary devis-level, pour que Planner/poseur/
        // commercial/dashboard (non modifiés cette session) continuent de
        // lire des champs devis-level cohérents.
        let devisUpdate = null;
        if (lotId) {
          const transitionedLotData = {...current, ...updatePayload};
          const allLotData = [
            transitionedLotData,
            ...Object.values(siblingLotDataById),
          ];
          const allLotSummaries = [
            {
              lotId,
              metierKey: transitionedLotData.metierKey,
              label: transitionedLotData.label,
              status: transitionedLotData.status,
              poseurIds: transitionedLotData.poseurIds || [],
              poseurNames: transitionedLotData.poseurNames || "",
              poseDate: transitionedLotData.poseDate || null,
              teamId: transitionedLotData.teamId || null,
              dependsOn: transitionedLotData.dependsOn || [],
              estimatedDurationDays:
                transitionedLotData.estimatedDurationDays || null,
              poseurCountRequired: transitionedLotData.poseurCountRequired || 1,
              materielRequis: transitionedLotData.materielRequis || "",
            },
            ...Object.entries(siblingLotDataById).map(([id, d]) => ({
              lotId: id,
              metierKey: d.metierKey,
              label: d.label,
              status: d.status,
              poseurIds: d.poseurIds || [],
              poseurNames: d.poseurNames || "",
              poseDate: d.poseDate || null,
              teamId: d.teamId || null,
              dependsOn: d.dependsOn || [],
              estimatedDurationDays: d.estimatedDurationDays || null,
              poseurCountRequired: d.poseurCountRequired || 1,
              materielRequis: d.materielRequis || "",
            })),
          ];
          devisUpdate = {
            status: aggregateDevisStatus(allLotData),
            poseurIds: aggregateUnion(allLotData, "poseurIds"),
            poseDate: aggregateEarliest(allLotData, "poseDate"),
            lotsSummary: allLotSummaries,
            updatedAt: now,
          };
          lotContext = {lotId, label: current.label || lotId};
        }

        // ── Écritures ────────────────────────────────────────────────
        tx.update(targetRef, updatePayload);
        tx.set(targetRef.collection("statusHistory").doc(), {
          fromStatus,
          toStatus: newStatus,
          uid: callerUid,
          role: callerRole,
          at: now,
          comment,
          origin,
          extraFields,
        });
        if (seededLots) {
          for (const l of seededLots) {
            tx.set(devisRef.collection("lots").doc(l.lotId), l.data);
          }
        }
        if (devisUpdate) {
          tx.update(devisRef, devisUpdate);
        }

        after = {...current, ...updatePayload};
        notifyAfter = lotId ? {...devisData, ...updatePayload} : after;
      });

      try {
        await notifyTransition(
            db, newStatus, notifyAfter, {workspaceId, devisId}, lotContext,
        );
      } catch (e) {
        logger.error("transitionDevisStatus notify error:", e);
      }

      return {ok: true};
    });

/**
 * Phase 4 (Planner v2) : réécrit l'entrée `lotId` dans `devis.lotsSummary`
 * avec les champs fournis dans `patch`, sans toucher aux autres lots. Utilisé
 * par `setLotDependencies` et `updateLotPlanningFields`, qui écrivent toutes
 * deux directement sur le document lot (pas via `transitionDevisStatus`) et
 * doivent donc répercuter le changement elles-mêmes sur la dénormalisation
 * lue par le Planner — sinon celui-ci resterait sur une valeur obsolète
 * jusqu'à la prochaine transition de statut de ce lot.
 * @param {FirebaseFirestore.DocumentReference} devisRef
 * @param {FirebaseFirestore.DocumentSnapshot} devisSnap
 * @param {string} lotId
 * @param {Object} patch
 * @return {Promise<void>}
 */
async function patchLotSummary(devisRef, devisSnap, lotId, patch) {
  const lotsSummary = Array.isArray(devisSnap.data().lotsSummary) ?
    devisSnap.data().lotsSummary : [];
  const updated = lotsSummary.map((entry) =>
    entry.lotId === lotId ? {...entry, ...patch} : entry);
  await devisRef.update({lotsSummary: updated});
}

/**
 * Phase 3 (multi-lots) : déclare les dépendances d'un lot envers d'autres
 * lots du même chantier (ex. "carrelage" dépend de "salle_de_bain_etancheite"
 * — le carrelage ne pourra pas démarrer sa pose tant que l'étanchéité n'est
 * pas Terminée, voir `requiresDependenciesValidated` sur la transition
 * À planifier → En pose dans devisWorkflow.js). Écriture directe (pas une
 * transition de statut) mais passe quand même par une Cloud Function pour
 * valider que les IDs fournis sont bien des lots du même chantier et pour
 * garder une vérification de rôle cohérente avec `transitionDevisStatus`.
 */
exports.setLotDependencies = onCall(
    {region: "europe-west1"},
    async (request) => {
      const callerUid = request.auth && request.auth.uid;
      if (!callerUid) throw new Error("Non autorisé");

      const data = request.data || {};
      const workspaceId = data.workspaceId;
      const devisId = data.devisId;
      const lotId = data.lotId;
      const dependsOn = Array.isArray(data.dependsOn) ? data.dependsOn : [];

      if (!workspaceId || !devisId || !lotId) {
        throw new Error("workspaceId, devisId et lotId sont requis");
      }
      if (dependsOn.includes(lotId)) {
        throw new Error("Un lot ne peut pas dépendre de lui-même");
      }

      const callerDoc = await db.collection("users").doc(callerUid).get();
      if (!callerDoc.exists) throw new Error("Utilisateur inconnu");
      const callerData = callerDoc.data();
      const callerRole = callerData.role;
      const callerWorkspaceId = callerData.workspaceId || callerData.companyId;
      if (!["metreur", "admin"].includes(callerRole)) {
        throw new Error(
            `Non autorisé : le rôle ${callerRole} ne peut pas modifier les ` +
            "dépendances de lots",
        );
      }

      const workspaceDoc =
        await db.collection("workspaces").doc(workspaceId).get();
      if (!workspaceDoc.exists) {
        throw new Error("Espace de travail introuvable");
      }
      const isWorkspaceAdmin = workspaceDoc.data().adminUid === callerUid;
      if (!isWorkspaceAdmin && callerWorkspaceId !== workspaceId) {
        throw new Error(
            "Non autorisé : ce chantier n'appartient pas à votre espace " +
            "de travail",
        );
      }

      const devisRef = db.collection("workspaces").doc(workspaceId)
          .collection("devis").doc(devisId);
      const devisSnap = await devisRef.get();
      if (!devisSnap.exists) throw new Error("Chantier introuvable");
      const lotIds = devisSnap.data().lotIds || [];
      if (!lotIds.includes(lotId)) {
        throw new Error("Lot introuvable sur ce chantier");
      }
      const invalidIds = dependsOn.filter((id) => !lotIds.includes(id));
      if (invalidIds.length > 0) {
        throw new Error(
            `Lot(s) inconnu(s) sur ce chantier : ${invalidIds.join(", ")}`,
        );
      }
      // Détection de cycle simple (DFS) : dependsOn ne doit jamais pouvoir,
      // en suivant les dépendances déjà déclarées des autres lots, revenir
      // sur lotId lui-même.
      const otherLotsSnap = await devisRef.collection("lots").get();
      const graph = {};
      otherLotsSnap.forEach((doc) => {
        graph[doc.id] = doc.id === lotId ?
          dependsOn : (doc.data().dependsOn || []);
      });
      const visited = new Set();
      const hasCycle = (nodeId, stack) => {
        if (stack.has(nodeId)) return true;
        if (visited.has(nodeId)) return false;
        visited.add(nodeId);
        stack.add(nodeId);
        for (const next of graph[nodeId] || []) {
          if (hasCycle(next, stack)) return true;
        }
        stack.delete(nodeId);
        return false;
      };
      if (hasCycle(lotId, new Set())) {
        throw new Error("Dépendance cyclique détectée entre lots");
      }

      await devisRef.collection("lots").doc(lotId).update({
        dependsOn,
        updatedAt: Timestamp.now(),
      });
      await patchLotSummary(devisRef, devisSnap, lotId, {dependsOn});

      return {ok: true};
    });

/**
 * Phase 4 (Planner v2) : met à jour la durée estimée, le nombre de poseurs
 * requis et le matériel requis d'un lot — des champs de planification qui ne
 * sont pas des transitions de statut et ne passent donc pas par
 * `transitionDevisStatus`. Passe quand même par une Cloud Function car
 * `lots/{lotId}` reste en écriture serveur uniquement côté règles
 * Firestore (voir firestore.rules) ; vérification de rôle calquée sur
 * `setLotDependencies`.
 */
exports.updateLotPlanningFields = onCall(
    {region: "europe-west1"},
    async (request) => {
      const callerUid = request.auth && request.auth.uid;
      if (!callerUid) throw new Error("Non autorisé");

      const data = request.data || {};
      const workspaceId = data.workspaceId;
      const devisId = data.devisId;
      const lotId = data.lotId;

      if (!workspaceId || !devisId || !lotId) {
        throw new Error("workspaceId, devisId et lotId sont requis");
      }

      const callerDoc = await db.collection("users").doc(callerUid).get();
      if (!callerDoc.exists) throw new Error("Utilisateur inconnu");
      const callerData = callerDoc.data();
      const callerRole = callerData.role;
      const callerWorkspaceId = callerData.workspaceId || callerData.companyId;
      if (!["metreur", "admin"].includes(callerRole)) {
        throw new Error(
            `Non autorisé : le rôle ${callerRole} ne peut pas modifier les ` +
            "champs de planification d'un lot",
        );
      }

      const workspaceDoc =
        await db.collection("workspaces").doc(workspaceId).get();
      if (!workspaceDoc.exists) {
        throw new Error("Espace de travail introuvable");
      }
      const isWorkspaceAdmin = workspaceDoc.data().adminUid === callerUid;
      if (!isWorkspaceAdmin && callerWorkspaceId !== workspaceId) {
        throw new Error(
            "Non autorisé : ce chantier n'appartient pas à votre espace " +
            "de travail",
        );
      }

      const devisRef = db.collection("workspaces").doc(workspaceId)
          .collection("devis").doc(devisId);
      const devisSnap = await devisRef.get();
      if (!devisSnap.exists) throw new Error("Chantier introuvable");
      const lotIds = devisSnap.data().lotIds || [];
      if (!lotIds.includes(lotId)) {
        throw new Error("Lot introuvable sur ce chantier");
      }

      const patch = {};
      if (Object.prototype.hasOwnProperty
          .call(data, "estimatedDurationDays")) {
        patch.estimatedDurationDays = data.estimatedDurationDays;
      }
      if (Object.prototype.hasOwnProperty.call(data, "poseurCountRequired")) {
        patch.poseurCountRequired = data.poseurCountRequired;
      }
      if (Object.prototype.hasOwnProperty.call(data, "materielRequis")) {
        patch.materielRequis = data.materielRequis;
      }
      if (Object.keys(patch).length === 0) {
        throw new Error("Aucun champ à mettre à jour");
      }

      await devisRef.collection("lots").doc(lotId).update({
        ...patch,
        updatedAt: Timestamp.now(),
      });
      await patchLotSummary(devisRef, devisSnap, lotId, patch);

      return {ok: true};
    });

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

        // Toutes les transitions de statut suivantes (Acceptée, En cours,
        // À commander, À planifier, En pose, Terminé, À clôturer) sont
        // désormais notifiées depuis transitionDevisStatus (devisWorkflow.js)
        // au moment même de l'écriture — ce trigger n'a plus qu'à gérer la
        // création (avant) et les champs indépendants du statut (ci-dessus).
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

