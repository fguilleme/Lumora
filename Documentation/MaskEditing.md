# Édition directe des masques

Les gradients se règlent désormais sur la photographie, en complément des curseurs numériques. La poignée blanche déplace le centre. Sur un radial, les deux poignées jaunes règlent séparément la largeur et la hauteur. Sur un linéaire, la poignée jaune définit sa direction et son angle.

Les positions sont immédiatement reconverties en coordonnées normalisées entre 0 et 1. Elles restent donc identiques entre l’aperçu réduit, une restauration du document et l’export pleine résolution. Le zoom et le déplacement du canvas sont appliqués à la photo, à la matte et aux poignées avec la même transformation ; un point peint dans une vue agrandie est reconverti depuis cet espace zoomé. Les rayons sont bornés entre 0,02 et 1 et l’angle entre −180 et 180 degrés par les mêmes validateurs que les curseurs.

Le début du glissement ouvre une transaction d’historique, les déplacements intermédiaires demandent un aperçu interactif et la fin du geste enregistre une seule opération Undo. Annuler restaure ainsi toute la transformation plutôt que chaque point intermédiaire.

La rangée de la composante sélectionnée permet aussi de choisir **Ajouter** ou **Soustraire**, de la déplacer plus tôt ou plus tard dans la composition et de la supprimer. La dernière composante ne peut pas être supprimée : supprimer le calque entier reste l’action explicite correspondante.

Chaque poignée possède une cible tactile de 44 points et un libellé d’accessibilité distinct. Les curseurs restent disponibles pour une valeur précise et comme solution accessible lorsque le glissement direct n’est pas adapté.

Le radial affiche son contour extérieur ainsi qu'une ellipse orange qui marque la fin de sa zone pleine. Déplacer la poignée orange change directement le contour progressif. Pour le linéaire, cette poignée règle la largeur de transition le long de l'axe du dégradé. Ces gestes réutilisent les bornes de 1 à 100 du curseur et restent disponibles après restauration du document. L’overlay rouge est produit depuis la matte Core Image composée : son alpha reproduit donc le contour progressif, le débit et la douceur du pinceau, les soustractions, l’inversion et l’opacité du calque.

Le pinceau propose les modes **Peindre** et **Effacer**. Chaque trait est stocké dans la composante active en coordonnées normalisées ; les traits d’effacement sont appliqués après les traits peints pour retirer réellement de la matte. Un cercle rouge ou cyan montre la taille de la brosse pendant le geste. Chaque trait forme une seule opération Undo/Redo et les deux types de traits sont restaurés avec le document.

Les mattes Vision ne proposent pas encore de pinceau d’affinage directement attaché à leur composante. On peut néanmoins ajouter une composante Pinceau en ajout ou en soustraction dans le même calque.

![Poignées radiales et commandes de composante](AdjustmentLayers-Simulator.png)
