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
const OpenAI = require("openai");
const logger = require("firebase-functions/logger");

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

initializeApp();

/**
 * Analyse un devis via OpenAI Vision.
 */
exports.analyzeDevis = onCall({region: "europe-west1", secrets: ["OPENAI_API_KEY"]},
    async (request) => {
  const fileUrl = request.data && request.data.fileUrl;
  if (!fileUrl) {
    throw new Error("fileUrl manquant");
  }
  const openai = getOpenAIClient();

  const systemPrompt = `
Tu es une IA WorkIt, experte des devis menuiserie/pose
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

    const text = (response && response.output_text) ? response.output_text : "";
    logger.info("Analyse terminée", {length: text.length});
    return {text};
  } catch (error) {
    logger.error("Erreur OpenAI", error);
    throw new Error(`Analyse échouée: ${error.message}`);
  }
});

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
