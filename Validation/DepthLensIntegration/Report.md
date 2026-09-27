# Depth Lens — intégration Lumora

## Fonctionnalité

Onglet **Depth Lens**, après Détail. Activation explicite, ouverture f/1,2 à f/8, focales 50/85/135 mm, mise au point par toucher avec repère non exporté, recentrage et réinitialisation. Désactivé par défaut. Textes français et anglais.

DA2 Small FP16 embarqué, poids inchangés ; préparation proportionnelle avec prolongement des bords et retrait des marges sur la carte. Shader optique identique au prototype optimisé validé. Aucun nouveau look, aucun retuning, aucun sélecteur de modèle.

Historique, sauvegarde et réouverture inclus. Les anciens documents ne portant pas de clé depthLens restent inchangés. Depth Lens est un réglage global, distinct des masques locaux. Le modèle est chargé hors du thread UI, dans le moteur de rendu sérialisé. Une carte par source/géométrie/optique ; changer ouverture, focale ou point ne relance pas l’inférence. La dernière requête de rendu remplace les requêtes annulées suivant le mécanisme de génération existant.

Aperçu interactif 640 px, haute qualité jusqu’à 2048 px au relâchement, export natif par le même graphe. Flou appliqué après développement et masques, avant glow et grain. La sélection de visibilité et d’ordre des onglets est volontairement réservée à une étape ultérieure.

## Vérifications

- 3 tests Swift : migration/aller-retour/historique, bornes de paramètres, indépendance de la LUT couleur.
- Test UI réel en français : onglet, activation, toucher de mise au point, curseur, annulation ; réussi. Deux premières tentatives du script échouaient à localiser un onglet hors écran ; navigation du test corrigée.
- Modèle et shader comparés aux fichiers validés : identiques.
- Probe dans le véritable RenderEngine de Lumora DEBUG, sur iPhone 15 Pro / iOS 27.0.
- Photo native néon 2560 × 4096, non agrandie. Portrait 768 × 1152 également exécuté dans la première campagne.
- Bypass final : pixels identiques, zéro inférence.
- Une inférence pour aperçu, HQ, 20 changements d’ouverture et export.
- Persistance de l’état : identique après encodage/décodage.

## Mesures finales appareil, source native 4K

- Premier rendu de cette relance, caches système déjà chauds : 7323.9 ms. Ce n’est pas un démarrage froid garanti ; le premier chargement observé lors de la campagne portrait antérieure prenait environ 8,9 s au total.
- Aperçu 640 px pendant les réglages : médiane 29.4 ms pour tout le RenderEngine, pas seulement le GPU.
- Haute qualité 2048 px : 683.6 ms.
- Export PNG natif 2560 × 4096 : 2.78 s.
- Mémoire physique relevée après les rendus interactifs : 212.6–212.6 Mio.
- Mémoire relevée à la fin de l’export : 877.0 Mio. Ce relevé n’est pas une mesure continue du pic d’allocation.
- 0 avertissement mémoire ; export terminé ; état thermique relevé aux rendus : [1] (1 = fair).

## Limites conservées

Les contours de cheveux, les transparences et les erreurs de profondeur monoculaire restent ceux du prototype accepté. Les résultats ne garantissent pas une segmentation parfaite. Le modèle paysage fixe réduit la résolution utile des portraits. L’export testé couvre une vraie source 4K ; les sources 48 MP et la stabilité thermique prolongée ne sont pas validées par cette campagne.

Le contrôle de bypass initial a détecté une LUT couleur inutile déclenchée par le nouveau champ d’état. Correction : le réglage Depth Lens est exclu de l’état couleur. Test ajouté et bypass exact confirmé dans `native-final.json`. Les premiers résultats de `Portrait/` et `Native4K/` sont antérieurs à cette correction ; utiliser `native-final.json` pour les mesures finales.

**PASS intégration, interface, persistance, bypass et export 4K.**

Compilation Debug et Release réussie. Version Release installée et lancée normalement sur l’iPhone 15 Pro après les vérifications ; les probes de validation sont absentes de Release.
