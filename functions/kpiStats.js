/**
 * Phase 6 (tableau de bord dirigeant) : agrégats KPI par workspace, mis à
 * jour incrémentalement (FieldValue.increment, pas de lecture nécessaire)
 * depuis transitionDevisStatus (functions/index.js) à chaque transition de
 * statut — en best-effort après le commit de la transaction, exactement
 * comme notifyTransition. Pas de trigger Firestore séparé : la fonction
 * appelante connaît déjà tout ce qu'il faut (fromStatus/newStatus,
 * `current.updatedAt` pour calculer le délai, extraFields) sans lecture
 * supplémentaire, qu'il s'agisse d'un devis sans lot ou d'un lot précis.
 *
 * Document unique : workspaces/{workspaceId}/stats/kpis — lecture ouverte
 * aux membres du workspace, écriture serveur uniquement (firestore.rules),
 * même principe que workspaces/{id}/usage/aiAnalysis (Phase 0).
 */

const {getFirestore, FieldValue, Timestamp} =
  require("firebase-admin/firestore");

/**
 * Enregistre une transition dans les agrégats KPI du workspace.
 * @param {string} workspaceId
 * @param {Object} params
 * @param {string|null} params.fromStatus Statut avant la transition.
 * @param {string} params.newStatus Statut après la transition.
 * @param {number|null} params.delayMs Délai (ms) depuis l'entrée dans
 *   `fromStatus` (`current.updatedAt` au moment de cette transition) — null
 *   si indisponible (ex. tout premier statut d'un devis fraîchement créé).
 * @param {Object} [params.extraFields] Champs additionnels de la transition
 *   (rapportType, rapportProbleme, paiementEffectue...).
 * @param {number} [params.returnCount] Valeur de `current.returnCount`
 *   AVANT cette transition — distingue clôture au premier passage / après
 *   un retour au poseur (Phase 5).
 * @return {Promise<void>}
 */
async function recordKpiTransition(workspaceId, {
  fromStatus,
  newStatus,
  delayMs = null,
  extraFields = {},
  returnCount = 0,
}) {
  const db = getFirestore();
  const update = {updatedAt: Timestamp.now()};

  const key = `${fromStatus || "(aucun)"}__${newStatus}`;
  update[`transitions.${key}.count`] = FieldValue.increment(1);
  if (typeof delayMs === "number" && delayMs >= 0) {
    update[`transitions.${key}.totalMs`] = FieldValue.increment(delayMs);
  }

  if (newStatus === "Terminé") {
    update[returnCount > 0 ? "cloturesApresRetour" : "cloturesPremierPassage"] =
      FieldValue.increment(1);
    if (typeof extraFields.paiementEffectue === "boolean") {
      update[extraFields.paiementEffectue ?
        "paiementEffectueCount" : "paiementNonEffectueCount"] =
        FieldValue.increment(1);
    }
  }

  if (newStatus === "SAV") {
    update.savCount = FieldValue.increment(1);
  }

  if (newStatus === "À clôturer" && extraFields.rapportType === "probleme") {
    const cause = extraFields.rapportProbleme &&
      extraFields.rapportProbleme.cause;
    if (cause) {
      update[`nonConformiteCauses.${cause}`] = FieldValue.increment(1);
    }
  }

  await db.collection("workspaces").doc(workspaceId)
      .collection("stats").doc("kpis")
      .set(update, {merge: true});
}

module.exports = {recordKpiTransition};
