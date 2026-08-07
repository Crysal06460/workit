/**
 * Config déclarative des relances manuelles (déclenchées par un clic
 * utilisateur, pas par une transition de statut — voir sendRelance dans
 * index.js). Sur le même principe que TRANSITIONS dans devisWorkflow.js :
 * une table indexée par type, consommée par une seule Cloud Function
 * générique plutôt que plusieurs fonctions dédiées.
 */

const RELANCE_TYPES = {
  // Commercial/admin relance le métreur : chantier accepté ou pas.
  metreur_non_accepte: {
    fromRoles: ["commercial", "admin"],
    targetRole: "metreur",
    applicableStatuses: ["Nouvelle demande", "Acceptée", "En cours"],
    cooldownMinutes: 15,
    title: "🔔 Relance : chantier en attente",
    body: (client) =>
      `${client} attend toujours une action du métreur.`,
  },
  // Commercial/admin relance le métreur : commande toujours pas passée.
  metreur_commande_attente: {
    fromRoles: ["commercial", "admin"],
    targetRole: "metreur",
    applicableStatuses: ["À commander", "Commande en cours"],
    cooldownMinutes: 15,
    title: "🔔 Relance : commande en attente",
    body: (client) =>
      `La commande de ${client} est toujours en attente.`,
  },
  // Métreur/admin relance les poseurs assignés : chantier fini sur le
  // terrain mais jamais clôturé dans l'appli (cas réel : les poseurs
  // enchaînent sur le chantier suivant et oublient de faire la clôture).
  cloture_manquante: {
    fromRoles: ["metreur", "admin"],
    targetRole: "poseur",
    applicableStatuses: ["En pose"],
    cooldownMinutes: 15,
    title: "🔔 Relance : clôture à faire",
    body: (client) =>
      `Le chantier ${client} semble terminé — pensez à le clôturer ` +
      "dans l'appli.",
  },
};

/**
 * @param {string} type
 * @return {Object|null}
 */
function getRelanceConfig(type) {
  return RELANCE_TYPES[type] || null;
}

module.exports = {RELANCE_TYPES, getRelanceConfig};
