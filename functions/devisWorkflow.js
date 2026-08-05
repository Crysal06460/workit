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
      // "metierLabels" (Phase 3, multi-lots) : libellés métier utilisés
      // uniquement si ce passage crée les lots (premier "À commander" de ce
      // devis) — voir transitionDevisStatus. Ignoré sinon.
      extraFields: ["draft", "updated", "metierLabels"]},
  ],
  "Acceptée": [
    {to: "En cours", roles: ["metreur", "admin"], extraFields: ["meetingAt"],
      dateFields: ["meetingAt"]},
    {to: "À commander", roles: ["metreur", "admin"],
      // "metierLabels" (Phase 3, multi-lots) : libellés métier utilisés
      // uniquement si ce passage crée les lots (premier "À commander" de ce
      // devis) — voir transitionDevisStatus. Ignoré sinon.
      extraFields: ["draft", "updated", "metierLabels"]},
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
      dateFields: ["poseDate"],
      // Phase 3 (multi-lots) : le démarrage de pose d'un lot peut être
      // bloqué tant qu'un lot dont il dépend (`dependsOn`) n'est pas
      // Terminé/À clôturer. N'a d'effet que sur les transitions de lot
      // (lotId fourni) — sans effet sur les devis sans lots.
      requiresDependenciesValidated: true},
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
    // Phase 5 — soumission unifiée du rapport poseur (fin propre ou
    // problème) : plus de statut final direct, tout passe par À clôturer
    // qui devient un statut pivot "en attente de validation" (voir plus
    // bas). `rapportType` indique à l'écran de validation quel rapport
    // afficher.
    {to: "À clôturer", roles: ["poseur", "admin"], requirePoseurAssigned: true,
      extraFields: [
        "rapportType", "rapportFin", "rapportProbleme", "paiementEffectue",
      ]},
  ],
  // Phase 5 — circuit de validation : le responsable (commercial/admin)
  // examine le rapport soumis par le poseur et choisit une issue. Jamais
  // accessible au poseur (contrairement à avant, où À clôturer/Terminé
  // étaient déjà définitifs dès sa propre soumission).
  "À clôturer": [
    {to: "Terminé", roles: ["commercial", "admin"],
      extraFields: ["validationComment"]},
    {to: "En pose", roles: ["commercial", "admin"],
      extraFields: ["retourCommentaire"]},
    {to: "SAV", roles: ["commercial", "admin"],
      extraFields: ["savReason"]},
  ],
};

// Phase 5 — causes de non-conformité structurées (liste fermée, roadmap
// Phase 5). Le champ libre `commentaire` reste optionnel en complément.
const NON_CONFORMITE_CAUSES = [
  "Erreur de métré",
  "Erreur de commande",
  "Produit manquant/endommagé",
  "Défaut fournisseur",
  "Erreur de pose",
  "Support non conforme",
  "Oubli matériel",
  "Absence client",
  "Intempéries",
  "Autre",
];

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

// ─── Phase 3 (multi-lots) : agrégation du statut/champs des lots vers le
// devis parent, pour que les écrans qui ne manipulent que le devis dans son
// ensemble (commercial, dashboard admin — Planner et écran poseur sont
// devenus lot-aware en Phases 4/5) continuent de lire des champs devis-level
// cohérents. ─────────────────────────────────────────────────────────────

// Un lot ne naît qu'au passage en "À commander" (voir functions/index.js) :
// pas besoin de couvrir les statuts antérieurs ici.
const LOT_STATUS_ORDER = {
  "À commander": 0,
  "Commande en cours": 0,
  "À planifier": 1,
  "En pose": 2,
  // Phase 5 : À clôturer n'est plus terminal, c'est le statut pivot "rapport
  // soumis, en attente de validation par le responsable" — plus avancé que
  // En pose mais pas encore définitif.
  "À clôturer": 3,
  "Terminé": 4,
  "SAV": 4,
};
// Phase 5 : À clôturer retiré (devenu un statut pivot, pas terminal — un lot
// en attente de validation ne doit plus débloquer les lots qui en dépendent).
// SAV ajouté comme second état terminal possible, à côté de Terminé.
const LOT_TERMINAL_STATUSES = new Set(["Terminé", "SAV"]);

/**
 * Statut agrégé du devis à partir des statuts de ses lots : le moins avancé,
 * sauf si tous les lots sont à un statut terminal (Terminé/SAV), auquel cas
 * le devis passe lui-même Terminé (ou SAV si au moins un lot est en SAV).
 * @param {Object[]} lotDataList Données brutes (pas des DocumentSnapshot) de
 *   chaque lot — le lot en cours de transition doit y figurer avec son
 *   NOUVEAU statut (voir functions/index.js, qui fusionne current+updatePayload
 *   avant d'appeler ces helpers, car une transaction Firestore ne peut pas
 *   relire un document qu'elle vient d'écrire).
 * @return {string}
 */
function aggregateDevisStatus(lotDataList) {
  const statuses = lotDataList.map((d) => d.status || INITIAL_STATUS);
  if (statuses.length === 0) return INITIAL_STATUS;
  if (statuses.every((s) => LOT_TERMINAL_STATUSES.has(s))) {
    return statuses.includes("SAV") ? "SAV" : "Terminé";
  }
  let least = statuses[0];
  let leastOrder = LOT_STATUS_ORDER[least] || 0;
  for (const s of statuses) {
    const order = LOT_STATUS_ORDER[s] || 0;
    if (order < leastOrder) {
      least = s;
      leastOrder = order;
    }
  }
  return least;
}

/**
 * Union (dédupliquée) d'un champ tableau à travers tous les lots.
 * @param {Object[]} lotDataList
 * @param {string} field
 * @return {Array}
 */
function aggregateUnion(lotDataList, field) {
  const set = new Set();
  for (const d of lotDataList) {
    const value = d[field];
    if (Array.isArray(value)) value.forEach((v) => set.add(v));
  }
  return Array.from(set);
}

/**
 * Timestamp le plus proche (le plus tôt) d'un champ date à travers les lots
 * qui le renseignent. Retourne null si aucun lot n'a de valeur.
 * @param {Object[]} lotDataList
 * @param {string} field
 * @return {FirebaseFirestore.Timestamp|null}
 */
function aggregateEarliest(lotDataList, field) {
  let earliest = null;
  for (const d of lotDataList) {
    const value = d[field];
    if (!value) continue;
    if (!earliest || value.toMillis() < earliest.toMillis()) earliest = value;
  }
  return earliest;
}

/**
 * Envoie les effets de bord (push FCM + in-app) d'une transition, une fois
 * le statut et l'historique écrits. Reprend telle quelle la copie des
 * anciens blocs `if` de onDevisStatusChange (lignes 619-747 avant cette
 * session) et de DevisService._notifForTransition côté client — désormais
 * au même endroit, côté serveur.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} newStatus
 * @param {Object} after Données du devis après écriture (fusionnées avec les
 *   données du lot quand `lotContext` est fourni — voir functions/index.js).
 * @param {Object} ctx {workspaceId, devisId}
 * @param {Object|null} lotContext Phase 3 (multi-lots) : {lotId, label} si la
 *   transition concerne un lot plutôt que le devis entier. Le nom du lot est
 *   ajouté au texte des notifications pour qu'un métreur avec plusieurs lots
 *   sur le même chantier puisse les distinguer.
 */
async function notifyTransition(db, newStatus, after, ctx, lotContext = null) {
  const {workspaceId, devisId} = ctx;
  const clientName = after.clientName || after.client || "client inconnu";
  const client = lotContext ?
    `${clientName} (lot ${lotContext.label})` : clientName;
  const userId = after.userId || after.commercialId || null;
  const baseData = {workspaceId, devisId,
    ...(lotContext ? {lotId: lotContext.lotId} : {})};

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

    // Phase 5 : À clôturer est désormais le statut pivot "rapport soumis,
    // en attente de validation par le responsable" (plus un état final direct
    // du poseur) — la notification informe qu'une action est attendue,
    // distincte selon qu'il s'agit d'un rapport de fin propre ou d'un
    // problème signalé (avec sa cause structurée, Phase 5).
    case "À clôturer": {
      const metreurTokens = after.metreurId ?
        await getTokenByUid(after.metreurId) : [];
      const adminTokens = await getTokensByRole(workspaceId, "admin");
      const tokens = [...commercialTokens, ...metreurTokens, ...adminTokens];
      const isProbleme = after.rapportType === "probleme";
      const cause = (after.rapportProbleme &&
        after.rapportProbleme.cause) || null;
      const title = isProbleme ?
        "⚠️ Problème signalé — à valider" : "✅ Rapport de fin — à valider";
      const body = isProbleme && cause ?
        `Chantier ${client} : ${cause}. Validation requise.` :
        `Chantier ${client} : rapport du poseur à valider.`;
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

    // Phase 5 : issue possible de la validation, à côté de Terminé — le
    // chantier (ou le lot) nécessite une intervention après-vente.
    case "SAV": {
      const poseurIds = Array.isArray(after.poseurIds) ? after.poseurIds : [];
      const metreurTokens = after.metreurId ?
        await getTokenByUid(after.metreurId) : [];
      const adminTokens = await getTokensByRole(workspaceId, "admin");
      const poseurTokenArrays = await Promise.all(
          poseurIds.map((id) => getTokenByUid(id)));
      const tokens = [
        ...commercialTokens, ...metreurTokens, ...adminTokens,
        ...poseurTokenArrays.flat(),
      ];
      const savReason = after.savReason || null;
      const title = "🔧 Chantier passé en SAV";
      const body = savReason ?
        `Chantier ${client} : SAV — ${savReason}` :
        `Chantier ${client} : SAV créé`;
      await Promise.all([
        sendNotification(tokens, title, body, {...baseData, type: "status"}),
        ...["commercial", "metreur", "admin"].map((targetRole) =>
          writeInAppNotification(db, {
            workspaceId, devisId, targetRole, type: "status_sav",
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
  aggregateDevisStatus,
  aggregateUnion,
  aggregateEarliest,
  LOT_TERMINAL_STATUSES,
  NON_CONFORMITE_CAUSES,
};
