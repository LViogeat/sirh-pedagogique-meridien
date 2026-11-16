/**
 * Les pièces jointes des candidats : lecture, enregistrement, ouverture.
 *
 * Le socle n'a pas de stockage de fichiers : un document est enregistré en
 * base64 dans notre table `pieces_jointes`. D'où la limite de taille, et la
 * règle de ne JAMAIS relire la colonne `contenu` dans une liste.
 */
import { sql, insert } from '@/socle/sdk'

export const TAILLE_MAX = 500 * 1024 // 500 Ko

export const TYPES_DOCUMENT = [
  { code: 'cv', label: 'CV' },
  { code: 'lettre', label: 'Lettre de motivation' },
  { code: 'autre', label: 'Autre document' },
]

export const libelleType = (code) => TYPES_DOCUMENT.find((t) => t.code === code)?.label || code

/** 245 760 → « 240 Ko » */
export function formatTaille(octets) {
  if (octets < 1024) return `${octets} o`
  return `${Math.round(octets / 1024)} Ko`
}

/** Vérifie le fichier ; renvoie un message d'erreur, ou null s'il est acceptable. */
export function verifierFichier(fichier, { pdfSeulement = false } = {}) {
  if (!fichier) return 'Aucun fichier choisi.'
  if (fichier.size > TAILLE_MAX) {
    return `« ${fichier.name} » fait ${formatTaille(fichier.size)} : la limite est de 500 Ko.`
  }
  if (pdfSeulement && fichier.type !== 'application/pdf') {
    return 'Le CV doit être un fichier PDF.'
  }
  return null
}

/** Lit un fichier du navigateur et renvoie son contenu en base64 (sans l'en-tête data:). */
function lireEnBase64(fichier) {
  return new Promise((resoudre, rejeter) => {
    const lecteur = new FileReader()
    lecteur.onload = () => resoudre(String(lecteur.result).split(',')[1] || '')
    lecteur.onerror = () => rejeter(new Error(`Impossible de lire « ${fichier.name} ».`))
    lecteur.readAsDataURL(fichier)
  })
}

/** Enregistre un fichier pour un candidat ; renvoie la ligne créée (sans le contenu). */
export async function ajouterPiece(candidatId, fichier, typeDocument = 'cv') {
  const erreur = verifierFichier(fichier)
  if (erreur) throw new Error(erreur)
  const contenu = await lireEnBase64(fichier)
  const piece = await insert('pieces_jointes', {
    candidat_id: candidatId,
    type_document: typeDocument,
    nom_fichier: fichier.name,
    type_mime: fichier.type || 'application/octet-stream',
    taille: fichier.size,
    contenu,
  })
  delete piece.contenu
  return piece
}

/** La liste des pièces d'un candidat, sans leur contenu. */
export function listerPieces(candidatId) {
  return sql(
    `select id, type_document, nom_fichier, type_mime, taille, ajoutee_le
       from pieces_jointes where candidat_id = :id order by ajoutee_le desc, id desc`,
    { id: candidatId },
  )
}

/** Recharge un document et en fait un objet Blob. */
async function chargerBlob(pieceId) {
  const [piece] = await sql(
    'select nom_fichier, type_mime, contenu from pieces_jointes where id = :id',
    { id: pieceId },
  )
  if (!piece) throw new Error('Document introuvable.')
  const octets = Uint8Array.from(atob(piece.contenu), (c) => c.charCodeAt(0))
  return { blob: new Blob([octets], { type: piece.type_mime }), nom: piece.nom_fichier }
}

/** Ouvre le document dans un nouvel onglet (un PDF s'affiche directement). */
export async function ouvrirPiece(pieceId) {
  const fenetre = window.open('', '_blank') // ouverte tout de suite, sinon le navigateur la bloque
  const { blob } = await chargerBlob(pieceId)
  const url = URL.createObjectURL(blob)
  if (fenetre) fenetre.location.href = url
  else window.location.href = url
}

/** Télécharge le document sous son nom d'origine. */
export async function telechargerPiece(pieceId) {
  const { blob, nom } = await chargerBlob(pieceId)
  const lien = document.createElement('a')
  lien.href = URL.createObjectURL(blob)
  lien.download = nom
  lien.click()
  setTimeout(() => URL.revokeObjectURL(lien.href), 10000)
}
