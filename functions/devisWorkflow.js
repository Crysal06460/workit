/**
 * Config déclarative du moteur de workflow des chantiers (collection
 * workspaces/{workspaceId}/devis). Consommée par la Cloud Function callable
 * transitionDevisStatus (functions/index.js) : statuts, rôles autorisés par
 * transition, champs additionnels acceptés (whitelist), et effets de bord
 * (notification push FCM + notification in-app) — plutôt que des blocs
 * switch/if répétés à chaque nouvel écran.
 *
 * Remplace la logique auparavant dispersée entre les 8 blocs `if` de
 * onDevisStatusChange (notifications) et les écritures Firestore directes
 * de metreur_home_screen.dart / poseurs_home_screen.dart / planner_screen.dart.
 */

const {
  getTokensByRole,
  getTokenByUid,
  sendNotification,
  formatFrDateTime,
  writeInAppNotification,
} = require("./notifyHelpers");

// Statuts vus comme équivalents à l'état initial pour un vieux document
// n'ayant ni `status` ni `metreurStatus` (jamais censé arriver en pratique
// depuis Phase 0, mais garde un comportement défini).
const INITIAL_STATUS = "Nouvelle demande";

/**
 * Table des transitions autorisées, indexée par statut source.
 * `requirePoseurAssigned: true` impose que l'appelant figure dans
 * `poseurIds` du devis (ferme le trou de sécurité où un poseur pouvait
 * clôturer un chantier qui n'est pas le sien).
 */
const TRANSITIONS = {
  "Nouvelle demande": [
    {to: "Acceptée", roles: ["metreur", "admin"], extraFields: ["updated"]},
  ],
  "En cours": [
    // Ré-acceptation : le bouton "Accepter la demande" reste affiché tant
    // qu'aucun cas explicite n'existe pour 'En cours' côté client.
    {to: "Acceptée", roles: ["metreur", "admin"], extraFields: ["updated"]},
    // Modifier le rendez-vous déjà pris.
    {to: "En cours", roles: ["metreur", "admin"], extraFields: ["meetingAt"],
      dateFields: ["meetingAt"]},
    {to: "À commander", roles: ["metreur", "admin"],
      extraFields: ["draft", "updated"]},
  ],
  "Acceptée": [
    {to: "En cours", roles: ["metreur", "admin"], extraFields: ["meetingAt"],
      dateFields: ["meetingAt"]},
    {to: "À commander", roles: ["metreur", "admin"],
      extraFields: ["draft", "updated"]},
  ],
  "À commander": [
    {to: "À planifier", roles: ["metreur", "admin"], extraFields: ["updated"]},
  ],
  "Commande en cours": [
    {to: "À planifier", roles: ["metreur", "admin"], extraFields: ["updated"]},
  ],
  "À planifier": [
    {to: "En pose", roles: ["metreur", "admin"],
      extraFields: [
        "teamId", "poseDate", "poseurIds", "poseurNames", "updated",
      ],
      dateFields: ["poseDate"]},
  ],
  "En pose": [
    // Réaffectation (déplacer un chantier déjà planifié vers une autre
    // équipe/jour depuis le Planner — glisser-déposer libre comme avant
    // l'introduction du moteur de transitions).
    {to: "En pose", roles: ["metreur", "admin"],
      extraFields: [
        "teamId", "poseDate", "poseurIds", "poseurNames", "updated",
      ],
      dateFields: ["poseDate"]},
    {to: "Terminé", roles: ["poseur", "admin"], requirePoseurAssigned: true,
      extraFields: ["rapportFin", "paiementEffectue"]},
    {to: "À clôturer", roles: ["poseur", "admin"], requirePoseurAssigned: true,
      extraFields: ["rapportProbleme", "paiementEffectue"]},
  ],
};

/**
 * Cherche l'entrée de config correspondant à la transition demandée.
 * @param {string|null} currentStatus
 * @param {string} newStatus
 * @return {Object|null}
 */
function findTransition(currentStatus, newStatus) {
  const from = currentStatus || INITIAL_STATUS;
  const candidates = TRANSITIONS[from] || [];
  return candidates.find((c) => c.to === newStatus) || null;
}

/**
 * Envoie les effets de bord (push FCM + in-app) d'une transition, une fois
 * le statut et l'historique écrits. Reprend telle quelle la copie des
 * anciens blocs `if` de onDevisStatusChange (lignes 619-747 avant cette
 * session) et de DevisService._notifForTransition côté client — désormais
 * au même endroit, côté serveur.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} newStatus
 * @param {Object} after Données du devis après écriture.
 * @param {Object} ctx {workspaceId, devisId}
 */
async function notifyTransition(db, newStatus, after, ctx) {
  const {workspaceId, devisId} = ctx;
  const client = after.clientName || after.client || "client inconnu";
  const userId = after.userId || after.commercialId || null;
  const baseData = {workspaceId, devisId};

  const commercialTokens = userId ? await getTokenByUid(userId) : [];

  switch (newStatus) {
    case "Acceptée": {
      const metreurName = after.assignedMetreurName ||
        after.metreurName || "le métreur";
      const title = "📅 Métré planifié";
      const body = `Le chantier de ${client} va être métré par ${metreurName}`;
      await Promise.all([
        sendNotification(commercialTokens, title, body,
            {...baseData, type: "status"}),
        writeInAppNotification(db, {
          workspaceId, devisId, targetRole: "commercial",
          type: "status_acceptee", title, body,
        }),
      ]);
      return;
    }

    case "En cours": {
      const {dateStr, timeStr} = formatFrDateTime(after.meetingAt);
      const when = timeStr ? `le ${dateStr} à ${timeStr}` : `le ${dateStr}`;
      const title = "📅 Rendez-vous de métré confirmé";
      const body = `Le métré du chantier de ${client} est programmé ${when}`;
      await Promise.all([
        sendNotification(commercialTokens, title, body,
            {...baseData, type: "status"}),
        writeInAppNotification(db, {
          workspaceId, devisId, targetRole: "commercial",
          type: "status_en_cours", title, body,
        }),
      ]);
      return;
    }

    case "À commander": {
      const title = "✅ Métré terminé";
      const body = `Le métré de ${client} est terminé. ` +
        `La commande peut être passée.`;
      await Promise.all([
        sendNotification(commercialTokens, title, body,
            {...baseData, type: "status"}),
        writeInAppNotification(db, {
          workspaceId, devisId, targetRole: "commercial",
          type: "status_a_commander", title, body,
        }),
      ]);
      return;
    }

    case "À planifier": {
      const title = "📦 Commande passée";
      const body = `Le chantier ${client} est commandé`;
      await Promise.all([
        sendNotification(commercialTokens, title, body,
            {...baseData, type: "status"}),
        writeInAppNotification(db, {
          workspaceId, devisId, targetRole: "commercial",
          type: "status_a_planifier", title, body,
        }),
      ]);
      return;
    }

    case "En pose": {
      const poseurIds = Array.isArray(after.poseurIds) ? after.poseurIds : [];
      const poseurNames = after.poseurNames || "l'équipe de pose";
      const poseDate = after.poseDate || after.dateDebut || "";
      const {dateStr: poseDateStr, dateTimeStr: poseDateTimeStr} =
        formatFrDateTime(poseDate);
      const poseurTokenArrays = await Promise.all(
          poseurIds.map((id) => getTokenByUid(id)));
      const poseurTokens = poseurTokenArrays.flat();
      const commercialTitle = "📋 Pose programmée";
      const commercialBody = `${client} le ${poseDateStr} par ${poseurNames}`;
      await Promise.all([
        sendNotification(
            poseurTokens,
            "🏗️ Nouveau chantier assigné",
            `${client} le ${poseDateTimeStr}`,
            {...baseData, type: "status"},
        ),
        sendNotification(commercialTokens, commercialTitle, commercialBody,
            {...baseData, type: "status"}),
        writeInAppNotification(db, {
          workspaceId, devisId, targetRole: "commercial",
          type: "status_en_pose", title: commercialTitle, body: commercialBody,
        }),
      ]);
      return;
    }

    case "Terminé": {
      const metreurTokens = after.metreurId ?
        await getTokenByUid(after.metreurId) : [];
      const adminTokens = await getTokensByRole(workspaceId, "admin");
      const tokens = [...commercialTokens, ...metreurTokens, ...adminTokens];
      const title = "🎉 Chantier terminé";
      const body = `Chantier ${client} terminé`;
      await Promise.all([
        sendNotification(tokens, title, body, {...baseData, type: "status"}),
        ...["commercial", "metreur", "admin"].map((targetRole) =>
          writeInAppNotification(db, {
            workspaceId, devisId, targetRole, type: "status_termine",
            title, body,
          })),
      ]);
      return;
    }

    case "À clôturer": {
      const metreurTokens = after.metreurId ?
        await getTokenByUid(after.metreurId) : [];
      const adminTokens = await getTokensByRole(workspaceId, "admin");
      const tokens = [...commercialTokens, ...metreurTokens, ...adminTokens];
      const raison = (after.rapportProbleme &&
        after.rapportProbleme.raison) || null;
      const title = "⚠️ Chantier pas terminé";
      const body = raison ?
        `Chantier ${client} pas terminé car ${raison}` :
        `Chantier ${client} pas terminé`;
      await Promise.all([
        sendNotification(tokens, title, body, {...baseData, type: "status"}),
        ...["commercial", "metreur", "admin"].map((targetRole) =>
          writeInAppNotification(db, {
            workspaceId, devisId, targetRole, type: "status_a_cloturer",
            title, body,
          })),
      ]);
      return;
    }

    default:
      return;
  }
}

module.exports = {
  INITIAL_STATUS,
  TRANSITIONS,
  findTransition,
  notifyTransition,
};
