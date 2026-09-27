# Cinematic Glow — intégration

Décision utilisateur : V2 exact à 40, avec son clipping connu ; protection Safe complète dès 70. Le défaut et Reset sont à 0, sans traitement GPU Cinematic Glow ni modification de l’image.

Un seul effet global dans Effects, un curseur Intensity 0…100. Persistance optionnelle pour lire les anciens documents, validation numérique, historique et Reset intégrés aux mécanismes existants. Aucun choix automatique selon la scène. Les masques locaux n’exposent pas un second Cinematic Glow ; activer le contrôle sélectionne la base.

## Courbe finale

On note s(x)=x²(3−2x) sur [0,1].

- 0…40 : poids s(Intensity/40) du V2, complément du signal original.
- 40…70 : poids s((Intensity−40)/30) de la contribution Safe 70, complément de la contribution V2. Interpolation des poids de recombinaison, sans état additif non protégé intermédiaire. Chaque canal reste entre les deux références : pas de dépassement au milieu du raccord.
- 70…100 : compensation .45 constante, glowGain 1.10→1.50 et échelle shoulder .85→.65 interpolés avec s((Intensity−70)/30), protection complète.

La courbe est continue avec pente nulle aux raccords. Aucun coefficient des trois points de référence n’est retouché. La plage sous 70 ne porte pas une garantie zéro clipping : c’est la limite du V2 explicitement acceptée. Le prototype additif qui clippe et Halo-biased ne sont pas intégrés.

## Pipeline et mémoire

CinematicGlowGPU provient du renderer mobile optimisé : extraction/réduction/accumulation shader identiques, même programme de flous MPS et mêmes rayons à l’échelle de résolution. Source et accumulateur RGBA32Float ; pyramide et scratch RGBA16Float. Pas de textures full-frame du moteur historique.

Un frame est réutilisé à résolution constante, l’ancien est libéré avant changement de dimensions. Le RenderEngine acteur en est propriétaire ; les CIImage sur ses textures sont consommées dans le même appel synchrone avant réutilisation. Cache MPS borné conservé. Les textures du frame natif sont libérées à la fin de l’export ou de la lecture de tuile, ainsi qu’au changement de source.

Le traitement est dans RenderEngine.adjusted après les masques, avant grain et Creative. Les autres effets en aval peuvent naturellement modifier la couleur ou saturer ; la protection de Cinematic Glow concerne sa propre sortie. Preview 960, HQ 2048, export à résolution native passent par ce même effet. Les différences de résolution et de décodage/quantification existantes restent possibles ; elles ne sont pas un autre look.

Le float étendu reste float : les canaux HDR au-dessus du blanc restent présents, et sont inchangés à partir de 70. Aucun nouvel encodeur HDR n’est ajouté : les formats d’export Lumora existants continuent leur encodage SDR actuel.

## Validation

Les artefacts, journaux, données appareil, planches et tests de cette intégration restent sous Validation/CinematicGlowProductionValidation. Les hooks appareil sont DEBUG uniquement, leur code est dans DeviceProbe.swift sous Validation. La bibliothèque utilisée par le test UI est isolée des documents utilisateur.
