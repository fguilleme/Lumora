# Cinematic Glow — Production Integration Report

27 septembre 2026 — **Intégration et validations terminées. PASS avec limite SDR V2 acceptée sous 70.**

Un effet Cinematic Glow dans Effects, Intensity 0…100, défaut et Reset à 0. Pas d’Auto Glow, pas de nouveaux looks, pas de réglages techniques exposés. Installation Release sur iPhone consignée dans release-install.log et release-launch.log.

## Mapping validé

| Intensity | Référence |
|---|---|
| 0 | Bypass exact, aucune matérialisation Cinematic Glow |
| 40 | V2 actuel inchangé |
| 70 | Cinematic Safe inchangé |
| 100 | Strong Safe inchangé |

Transitions smoothstep, continuité C1 aux points d’ancrage. 40→70 interpole les poids de recombinaison V2/Safe pour éviter tout dépassement entre eux. 70→100 interpole gain 1.10→1.50 et shoulder .85→.65, compensation .45 et protection complètes. Voir [Implementation.md](Implementation.md).

**Décision utilisateur conservée :** le V2 exact à 40 conserve son clipping mesuré. Zéro clipping nouveau n’est pas revendiqué entre 0 et 70. Le prototype additif et Halo-biased ne sont pas intégrés.

## Tests moteur et pipeline

- Ancien JSON sans ce champ décodé avec intensité 0 ; validation des valeurs, sérialisation et Reset vérifiés.
- Bypass : même CIImage retournée, aucune texture allouée par l’effet neuf. Retour à zéro après rendu non nul identique au baseline dans RenderEngine.
- HDR : fixture RGBA32Float explicite avec canaux 2.0/1.5 ; valeurs >1 conservées par la sortie Safe. L’export existant de Lumora reste SDR ; aucun nouveau format HDR n’est ajouté.
- Corpus : niveaux 0/25/40/55/70/85/100, huit images incluant fenêtre, lampadaire, phares, néon, métal, peau, golden hour/cheveux et soleil bas. Golden hour et cheveux utilisent la même source avec crops distincts.
- Erreur maximale des références 40/70/100 par rapport aux float32 gelés : **1.19e-07**, soit un écart d’arrondi float. Aucun retuning.
- Jonctions à 40±.001 et 70±.001 : delta RGB maximal **0**.
- Preview/HQ/export : même graphe RenderEngine.adjusted. Test à taille commune : preview et HQ identiques, export PNG à ≤2 niveaux sur 255 après normalisation couleur. La source 4K est également testée sur l’iPhone aux trois résolutions réelles.
- Prefix shader extraction/réduction/accumulation identique octet pour octet au mobile V2 ; mêmes sigmas, poids de flous et planification MPS. Intermédiaires half, source/accumulateur float32, frame et kernels réutilisés. Aucun renderer historique réintroduit.

## Saturation SDR du corpus

Nouveau pixel : au moins un canal original PNG <255 atteint 255. Totaux sur les huit images :

| Intensity | Nouveaux pixels saturés |
|---|---:|
| 0 | 0 |
| 25 | 3024 |
| 40 | 5316 |
| 55 | 2446 |
| 70 | 0 |
| 85 | 0 |
| 100 | 0 |

[Planche complète](contact.png) · [Crops](index.html) · [Mesures](metrics.json)

Inspection des crops finaux : détails des yeux/peau conservés, pas de peau laiteuse manifeste, pas de halo rouge artificiel (halation désactivée), pas de voile global évident. Éclaircissement local du bord de fenêtre et des reflets métalliques conforme aux références choisies. La limite du point V2 n’est pas masquée par les métriques. L’appréciation humaine précédente reste celle des références, pas un nouveau choix automatique.

## iPhone 15 Pro réel

Appareil iPhone16,1 / Apple A17 Pro / iOS 27.0. Diagnostic compilé dans Lumora DEBUG, exécutant son vrai RenderEngine ; hooks absents de Release. Photo native néon **2560 × 4096**, sans agrandissement. Bibliothèque des essais UI isolée des documents utilisateur.

| Intensity | Preview 960 ms | HQ 2048 ms | Export natif PNG ms |
|---|---:|---:|---:|
| 0 | 172.3 | 170.9 | 580.8 |
| 40 | 31.4 | 37.7 | 510.0 |
| 70 | 14.1 | 39.6 | 502.3 |
| 100 | 14.3 | 39.5 | 513.6 |

Les timings portent sur le pipeline complet, pas uniquement le shader. Le premier chargement à 0 inclut les coûts froids et n’est pas comparable à une frame chaude. Après chauffe, les snapshots des 90 rendus interactifs se situent autour de 11 ms.

- 4 exports natifs réussis ; zéro nouveau pixel saturé sur les exports 70 et 100, clipping du V2 présent à 40.
- Mémoire physique maximale **observée aux jalons** : 581.3 MiB ; ce n’est pas un pic instrumenté pendant l’export. Metal observé aux jalons : 143.0 MiB, les textures export sont déjà libérées aux relevés après export.
- Séquence interactive : Metal stable à environ 44.9 MiB ; mémoire physique environ 106–118 MiB, puis redescendue à 97.7 MiB en fin de passe. Pas de croissance continue observée.
- 0 memory warnings, aucun kill observé. Dernière passe : état thermique **fair (1)** ; première passe nominale. Aucun diagnostic jetsam système indépendant, ni garantie de stabilité à toutes les dimensions supérieures à 4K.
- Test XCUITest **réussi sur appareil** : contrôle Effects visible, gestes répétés, Undo/Redo, export natif depuis l’interface. Captures dans UIVerifiedAttachments ; résultat iPhoneUIVerified.xcresult. Les positions normalisées des gestes XCUITest sont approximatives ; les valeurs numériques exactes 0/40/70/100 sont celles du diagnostic RenderEngine, pas une déduction des gestes.

Les premiers échecs du banc sont conservés dans leurs logs : fixture HDR initialement incorrecte, navigation UI hors écran et interruption par notification. Les vérifications finales corrigées passent (final-tests.log, iphone-ui-verified.log). Le raccord initial à 55 dépassait V2 ; sa version finale corrigée est celle des planches et mesures présentées ici.

## Arrêt

Intégration d’un seul effet terminée. Défaut 0. Pas de retuning des références, pas d’Auto Glow, pas de preset ajouté. Aucun commit ou publication distante effectué.
