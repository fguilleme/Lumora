# Beauty V2 + Correction/Zone — intégration dans MAIN

Date : 26 septembre 2026.

## Livraison et provenance

Projet de référence : `/Volumes/XTRA/Dev/Lumora/Lumora.xcodeproj`, branche `main`, cible/schéma `Lumora`, bundle **com.guilleme.Lumora**, version **1.0 (4)**. Aucun changement de bundle, de projet Xcode ou de version importé du worktree. Les modifications sont dans le checkout principal ; aucun commit n’a été créé.

Avant intégration : diff de travail binaire, diff indexé, statut complet et copie des fichiers touchés sauvegardés dans `BeautyIntegration/Backup/`. Aucune modification locale préexistante supprimée ; aucun reset ni remplacement du projet.

Comparaison à trois versions : ancêtre commun `b68ba47`, état courant de MAIN, état du worktree Beauty V2. Les fichiers absents de MAIN ont été ajoutés après inspection ; les fichiers partagés ont été fusionnés. La liste complète est dans `BeautyIntegration/file-plan.json`.

## Fichiers et raccordements

- `Lumora/Beauty/BeautyV2State.swift`, `BeautyV2MaskAnalyzer.swift`, `BeautyV2Renderer.swift` : contrôles et traitement V2 validés.
- `BeautyState.swift`, `BeautyFaceAnalysis.swift`, `BeautyMaskPipeline.swift` : stockage additif, masques lèvres et partage de l’analyse existante.
- `ManualBlemishCorrection.swift`, `ManualHealingAnalysis.swift`, `ManualHealingRenderer.swift`, `HealingGeometry.swift`, `HealingTargetMask.swift` : moteur **Current**, source/cible, coordonnées, strokes ordonnés Ajouter/Effacer et masque arbitraire.
- `EditorSession.swift`, `RenderEngine.swift`, `EditorView.swift`, `PhotoCanvas.swift` : état, transactions, persistance et graphes de rendu.
- `BeautyView.swift`, `ManualHealingControls.swift`, `HealingGuides.swift` : sections de production, contrôle Correction/Zone, cible turquoise et source orange.
- Aide et localisations français/anglais intégrées. README actualisé.
- Tests V2, Healing, Zone et nouveaux tests d’intégration ajoutés au cœur ; test UI de production conservé et complété.

`BeautyIntegration/preservation.json` confirme que V2Renderer, V2MaskAnalyzer, ManualHealingRenderer, ManualHealingAnalysis et HealingTargetMask sont identiques aux fichiers du worktree. Aucun tuning, changement de preset ou changement de constante photographique.

## Conflit avec le pipeline courant

Le seul conflit textuel était dans `RenderEngine.adjusted` : MAIN possède maintenant Core Image Auto, absent de l’ancienne base du worktree.

- Documents sans Core Image Auto : développement → Current Healing en coordonnées canoniques → géométrie → Beauty V1/V2.
- Documents avec Core Image Auto : optique → Current Healing canonique → géométrie → recette Auto persistée → développement → Beauty V1/V2. La préparation des sources Healing utilise alors l’image optique, correspondant à son entrée de rendu.
- Une correction active empêche de réutiliser le baseline Auto non corrigé. Une correction neutre/désactivée conserve le chemin de cache existant, y compris l’identité exacte Amount=0.
- Les corrections seules ne demandent pas de masques Vision au rendu : leurs coordonnées, sources et strokes sont déjà persistés. Les contrôles automatiques Beauty continuent à utiliser leurs vrais masques.

Il s’agit d’un raccordement de pipeline ; les algorithmes et gains des renderers n’ont pas été modifiés.

## UI finale de production

| Section | Contrôles |
|---|---|
| Peau | Uniformité, Texture, Imperfections, Brillance, Correction |
| Regard | Cernes, Éclat yeux, Détail yeux |
| Sourire | Dents |
| Lèvres | Couleur, Saturation, Luminosité, Détail |
| Visage | Équilibre |

Pas de section Cheveux. Correction expose source/cible, Taille, Force, Supprimer. Zone expose Ajouter, Effacer, Taille pinceau et Contour.

## Chaîne UI → état → document → rendu

`BeautyView.onV2Change` → `EditorSession.setBeautyV2` → `state.beauty.finishing[control]` → transaction HistoryManager et `persist()` → `PhotoDocument.state` → `RenderEngine.adjusted` → `BeautyV2Renderer.apply` → image preview/HQ/export.

`ManualHealingControls` / `PhotoCanvas` → méthodes Healing de `EditorSession` → `state.beauty.manualCorrections` → même document/historique → `ManualHealingRenderer.apply` avec `HealingTargetMask`. Les strokes ne sont pas seulement un overlay UI.

Vérification réelle sur `08_open_smile_teeth.jpg`, via le RenderEngine du checkout MAIN après encodage/décodage des valeurs :

| Contrôle | Valeur | MAE RGB globale | Maximum RGB |
|---|---:|---:|---:|
| Couleur lèvres | +100 | 0.00008047 | 0.03169 |
| Saturation lèvres | +100 | 0.00012903 | 0.09998 |
| Luminosité lèvres | +100 | 0.00016072 | 0.13808 |
| Détail lèvres | +100 | 0.00006009 | 0.05848 |
| Brillance | 100 | 0.00032258 | 0.04693 |
| Équilibre | +100 | 0.00007854 | 0.02249 |
| Équilibre | −100 | 0.00166667 | 0.05189 |

Mesures en RGB linéaire depuis la preview de production ; moyenne sur toute l’image, donc diluée par les zones non affectées. Elles prouvent un changement effectif, sans jugement esthétique. CSV : `BeautyIntegration/render-wiring.csv`. La combinaison Lèvres change également l’export PNG (maximum 0.15775) ; HQ et export sont finis. Les exports sont dans `BeautyIntegration/Exports/`.

## Correction, persistance et migration

`beautyMainManualPersistenceAndRender` utilise `03_acne_redness.jpg` et le proposeur Current inchangé sur le Mac : création d’une proposition réelle, modification Taille/Force/source, strokes Ajouter/Effacer, Undo/Redo, sauvegarde DocumentStore, rechargement et comparaison des pixels. Le rendu rechargé est identique.

Compatibilité testée : document sans Beauty, Beauty V1 sans nouvelles clés, V2, champs Hair expérimentaux, corrections sans strokes et corrections avec masque arbitraire. Les valeurs Hair restent encodables/décodables mais n’activent aucun traitement. Modifier un contrôle V2 conserve les champs Hair hérités au lieu de les effacer quand les contrôles de production reviennent à zéro.

## Vision Simulator — limite explicite

Le runtime iOS 27 Simulator renvoie toujours `Could not create inference context`. Aucun masque n’est fabriqué pour le contourner. L’état UI affiche désormais « Analyse du visage indisponible » au lieu de « Analyse… » après l’échec.

Une correction déjà persistée reste sélectionnable et éditable, même si la recherche automatique de nouvelles sources ne peut pas être préparée. La création d’une nouvelle correction via Vision n’est **pas certifiée sur ce simulateur** ; elle est vérifiée dans les tests fonctionnels sur Mac et reste à essayer sur l’iPhone.

Le test UI est lancé avec un véritable document produit par le test fonctionnel, installé dans la bibliothèque du simulateur via `BeautyIntegration/prepare_simulator_document.py`. Il n’utilise ni vue de remplacement, ni stub Vision, ni masque injecté. Ce prérequis est explicite et reproductible ; une présence de correction n’est pas présentée comme la preuve d’une nouvelle création par tap sur Simulator.

## Éléments volontairement non intégrés

- Hair UI, analyse Hair, segmentation de personne Hair et renderer Hair.
- LocalFrequencyPrototype / Local Frequency Inpainting.
- HealingDeviceProbe, démarrage par arguments de benchmark, panneaux de diagnostic fréquentiel réservés à la R&D.

Les recherches et rapports restent dans leur emplacement existant. Le résultat historique de **10/12 FAIL photographiques du prototype Local Frequency** n’est ni supprimé ni requalifié : ce prototype n’est pas le moteur de production intégré ici.

## Validation

Résultats finaux et captures : voir les fichiers de preuve dans `BeautyIntegration/` et la section finale ci-dessous.

### Résultats finaux

| Vérification | Résultat |
|---|---|
| MAIN Debug Simulator | PASS |
| MAIN Release Simulator | PASS |
| Tests du cœur | PASS : 148 tests, puis 1 test ciblé supplémentaire Auto/cache/Amount=0 |
| `testProductionBeautyExposureAndZone` | PASS, 0 échec |
| `testV2SlidersPersist` | PASS, 0 échec |
| Six sliders V2 → document réel du simulateur | PASS : les six valeurs sauvegardées sont à 100 |
| Source, Taille, Force, strokes via UI → document | PASS : source déplacée, rayon modifié, Force 75 → 45, 2 → 4 strokes |
| Undo/Redo via UI | PASS : valeur Force restaurée exactement |
| Rechargement après gestes UI | PASS : le test V2 suivant ouvre le document corrigé et sa preview |
| V2 → RenderEngine → changements pixels | PASS sur le portrait réel, détail des valeurs ci-dessus |
| Migrations, neutralité, HDR, masques Zone, coordonnées | PASS dans les tests du cœur |
| Création d’une nouvelle correction via tap sur Simulator | WARN : bloquée par Vision indisponible ; ne pas confondre avec l’édition d’une correction persistée |
| Inspection esthétique sur iPhone | À effectuer ; aucun tuning réalisé |
| FAIL final d’intégration constaté | Aucun dans les campagnes finales exécutées |

Le test UI complet a nécessité des corrections du harness : attente du premier rendu, défilement par la marge hors sliders, prise en compte du bouton compact Correction et du type accessibility `Switch` de Zone. Les campagnes antérieures en échec n’ont pas été présentées comme des succès. Aucun algorithme n’a été changé pour satisfaire ces tests.

Les essais SwiftPM trop larges ont aussi exécuté des validations existantes du Lab avant restriction du filtre. Ils ne sont pas utilisés comme preuves d’intégration ; la campagne retenue est explicitement filtrée sur `LumoraCoreTests`.

Preuves :

- `BeautyIntegration/core-tests.log`, `auto-cache-test.log`, `release-build.log`.
- `BeautyIntegration/ui-test.log`, `ui-test-summary.json`, `v2-ui-test.log`, `v2-ui-summary.json`.
- `BeautyIntegration/simulator-manual-after.json` : document réellement enregistré après les gestes, Taille/Force et Undo/Redo.
- `BeautyIntegration/simulator-v2-after.json` : document réellement enregistré après modification des six sliders V2.
- `BeautyIntegration/manual-document.json` : correction d’entrée créée par le proposeur de production sur Mac.
- Les bundles XCTest originaux restent `/tmp/LumoraBeautyIntegration-ui7.xcresult` et `/tmp/LumoraBeautyIntegration-v2-ui.xcresult` ; pièces jointes exportées dans `BeautyIntegration/UIAttachments/` et `V2UIAttachments/`.

### Captures prioritaires de com.guilleme.Lumora

1. [Beauty haut](BeautyIntegration/Screenshots/02_beauty_top.png)
2. [Peau : Brillance et Correction](BeautyIntegration/Screenshots/04_correction_button.png)
3. [Lèvres : quatre sliders](BeautyIntegration/Screenshots/V2_lipDetail.png)
4. [Visage : Équilibre](BeautyIntegration/Screenshots/V2_faceBalance.png)
5. [Correction active et poignées](BeautyIntegration/Screenshots/05_correction_selected.png)
6. [Zone : Ajouter/Effacer, Taille pinceau, Contour](BeautyIntegration/Screenshots/06_zone.png)

Les captures V2 attestent l’interface et les valeurs modifiées ; l’image affichée sur ce simulateur ne prouve pas le traitement V2 après l’échec Vision. La preuve des différences pixels vient du RenderEngine exécuté sur le Mac avec l’analyse réelle.

### Reproduction

Depuis le checkout principal, exécuter `swift test --build-system native --filter LumoraCoreTests` pour les tests et le document de correction réel. Sur un simulateur où `com.guilleme.Lumora` est installé, charger ce document avec `python3 BeautyIntegration/prepare_simulator_document.py <UUID>`. Exécuter ensuite les deux méthodes de `BeautyProductionAuditUITests` dans leur ordre (exposition/Zone puis sliders V2), avec le schéma `Lumora`. Réinitialiser le document de test avec le même script avant une nouvelle campagne : le test des sliders vérifie une modification effective depuis les valeurs neutres.

**STOP : intégration terminée, sans Hair, prototype Local Frequency, tuning ni changement de presets. Inspection iPhone attendue.**

## Manual Correction: enlarged-area seam investigation

After a reported visible edge when Size changes from 1 to 2, the GPU mask test confirms unchanged relative feathering. A separate render-region test reproduced inconsistent output when requesting small tiles: maximum RGB error against a full render was 0.0000798 / 0.001366 / 0.003466 at Size 1 / 2 / 5 respectively.

The renderer's Core Image ROI omitted the full source texture-energy ring. Every output pixel samples this ring, even when Core Image requests only a small output region. The ROI now includes that ring and a one-pixel interpolation margin. No mask, preset, reconstruction coefficient or slider range was changed.

After correction: maximum RGB discrepancy 0 / 0 / 0.001662 at Size 1 / 2 / 5. The regression allows 0.002 linear RGB for backend filtering variation; it does not certify photographic quality. All 12 focused healing tests and the Lumora iOS Simulator build pass. Confirmation on the user's original photograph/device remains required: this reproduces a technical seam defect, not necessarily every cause of a visible enlarged repair boundary.

## Follow-up: visible cheek patch after leaving Correction

The ROI fix did not fully resolve the reported enlarged repair boundary. A photo-08 reproduction and a failing synthetic regression identified bright extrapolation from the distant dark annulus in the quadratic LOW reconstruction. The manual renderer now reconstructs LOW with positive, normalized immediate-boundary weights, preserving the existing mask, smooth join, source texture, texture scaling and presets. See `BeautyIntegration/HealingResize/README.md`, its before/after crops and retained failure log. Fourteen focused tests pass; the actual iPhone edit still requires visual confirmation.
