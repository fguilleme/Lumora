# Aide intégrée de l’éditeur

L’onglet **Aide** se trouve après **Presets** dans la barre des outils, en portrait comme dans la colonne de contrôles du mode paysage. Il présente les onze panneaux de retouche. Toucher une rubrique ouvre une page de lecture défilante avec les réglages, les gestes et les interactions propres au panneau ; **Fermer** ramène à la liste. L’aide est embarquée dans l’application et reste accessible hors ligne.

Les rubriques sont **Creative**, **Lumière**, **Couleur**, **Courbes**, **Colorimétrie**, **Effets**, **Détail**, **Optique**, **Géométrie**, **Masques** et **Presets**. Leur contenu est maintenu dans `Lumora/UI/EditorHelpView.swift`, au plus près des libellés de l’interface. Quand un réglage est renommé, ajouté ou retiré, mettre à jour la rubrique correspondante et ce document.

L’aide est une vue de lecture : ouvrir une rubrique ou la refermer ne crée pas d’opération Undo, ne change pas le calque actif et ne déclenche aucun réglage de développement. La ligne d’informations photo est masquée dans cet onglet pour réserver l’espace aux rubriques. Les identifiants d’accessibilité `help-controls`, `help-topic-*`, `help-detail-*` et `help-close` permettent de vérifier le parcours au simulateur.
