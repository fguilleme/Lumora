import SwiftUI

/// Read-only, offline guidance for the editor's existing tools.
struct EditorHelpView: View {
    @State private var selectedTopic: EditorHelpTopic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aide")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 2)
                Text("Choisissez un onglet pour comprendre ses réglages et ses gestes. L’aide ne modifie pas la photographie.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                ForEach(EditorHelpTopic.allCases) { topic in
                    Button { selectedTopic = topic } label: {
                        HStack(spacing: 12) {
                            Image(systemName: topic.symbol)
                                .font(.system(size: 17))
                                .frame(width: 24)
                                .foregroundStyle(.mint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title).font(.subheadline.weight(.semibold))
                                Text(topic.summary).font(.caption2).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help-topic-\(topic.rawValue)")
                    Divider()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("help-controls")
        .sheet(item: $selectedTopic) { topic in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(topic.introduction)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(topic.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title).font(.headline)
                                ForEach(section.items) { item in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.mint)
                                        Text(item.explanation).font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("help-detail-\(topic.rawValue)")
                .navigationTitle(topic.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") { selectedTopic = nil }
                            .accessibilityIdentifier("help-close")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct HelpItem: Identifiable {
    let name: String
    let explanation: String
    var id: String { name }
    init(_ name: String, _ explanation: String) {
        self.name = name
        self.explanation = explanation
    }
}

private struct HelpSection: Identifiable {
    let title: String
    let items: [HelpItem]
    var id: String { title }
    init(_ title: String, _ items: [HelpItem]) {
        self.title = title
        self.items = items
    }
}

private enum EditorHelpTopic: String, CaseIterable, Identifiable {
    case creative, light, color, curves, colorTools, effects, detail, optics, geometry, masks, presets
    var id: String { rawValue }

    var title: String {
        switch self {
        case .creative: "Creative"
        case .light: "Lumière"
        case .color: "Couleur"
        case .curves: "Courbes"
        case .colorTools: "Colorimétrie"
        case .effects: "Effets"
        case .detail: "Détail"
        case .optics: "Optique"
        case .geometry: "Géométrie"
        case .masks: "Masques"
        case .presets: "Presets"
        }
    }

    var symbol: String {
        switch self {
        case .creative: "sparkles"
        case .light: "sun.max"
        case .color: "slider.horizontal.3"
        case .curves: "point.topleft.down.to.point.bottomright.curvepath"
        case .colorTools: "circle.lefthalf.filled"
        case .effects: "camera.filters"
        case .detail: "triangle"
        case .optics: "camera.aperture"
        case .geometry: "crop.rotate"
        case .masks: "circle.dashed.inset.filled"
        case .presets: "slider.horizontal.2.square"
        }
    }

    var summary: String {
        switch self {
        case .creative: "Pile d’effets photographiques et looks"
        case .light: "Exposition et répartition des tons"
        case .color: "Balance des blancs et intensité des couleurs"
        case .curves: "Contrôle précis des tons et des canaux"
        case .colorTools: "Mélangeur de couleurs et grading"
        case .effects: "Texture, clarté, voile, vignette et grain"
        case .detail: "Netteté et réduction du bruit"
        case .optics: "Profil optique et corrections manuelles"
        case .geometry: "Horizon, perspective et recadrage"
        case .masks: "Calques et retouches locales"
        case .presets: "Enregistrer et réutiliser ses réglages"
        }
    }

    var introduction: String {
        switch self {
        case .creative: "Creative assemble des effets autonomes. Chacun possède ses propres réglages ; leur ordre dans la pile change le rendu. Les looks intégrés servent de point de départ et restent modifiables."
        case .light: "Lumière règle l’équilibre tonal général ou celui du masque sélectionné. Commencez par l’exposition, puis protégez les hautes lumières et ajustez ombres, blancs et noirs."
        case .color: "Couleur règle la dominante et l’intensité colorée. Une balance des blancs prudente préserve l’ambiance d’une scène volontairement chaude ou froide."
        case .curves: "Courbes permet de placer précisément les tons et de modifier séparément les canaux RVB. Son mode consultation évite toute modification accidentelle pendant le défilement."
        case .colorTools: "Colorimétrie contient deux outils : Mélangeur pour les couleurs de la scène, Grading pour colorer les zones tonales. Ils agissent sur des propriétés différentes."
        case .effects: "Effets rassemble des ajustements de finition. Texture et clarté modifient le contraste local ; la correction du voile, la vignette et le grain répondent à d’autres besoins."
        case .detail: "Détail règle la netteté et les réductions de bruit. Examinez le résultat à 100 % : une vignette réduite masque facilement un excès de netteté ou de lissage."
        case .optics: "Optique corrige des défauts d’objectif. Le profil constructeur est disponible seulement lorsque le RAW expose un profil compatible ; les corrections manuelles restent utilisables autrement."
        case .geometry: "Géométrie corrige l’orientation, la perspective et le cadrage. Les corrections modifient la portion de l’image visible, sans altérer le fichier source."
        case .masks: "Masques crée des calques de retouche locale. Sélectionnez un masque ici, puis utilisez les réglages des autres onglets pour modifier seulement sa zone."
        case .presets: "Presets enregistre des groupes de réglages personnels et les applique à d’autres images. Vous choisissez les groupes inclus lors de la création."
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .creative:
            return [
                HelpSection("Construire une pile", [
                    HelpItem("Ajouter un effet", "Choisissez un effet dans le catalogue. Chaque effet devient une étape distincte de la pile ; les effets sont calculés dans leur ordre affiché."),
                    HelpItem("Réorganiser", "Déplacez un effet avant ou après un autre pour changer le résultat. Par exemple, Silver B&W avant Silver Toning produit un tirage viré ; l’ordre inverse peut supprimer sa coloration."),
                    HelpItem("Actions rapides", "L’œil active ou désactive une étape. Les icônes permettent aussi de dupliquer, supprimer, réinitialiser ou réordonner l’effet sélectionné."),
                    HelpItem("Opacité et masque", "L’opacité dose l’effet. Vous pouvez lui affecter un masque existant pour limiter son action à une zone de la photo.")
                ]),
                HelpSection("Familles et usage", [
                    HelpItem("Tons et détail", "High Key, Low Key, Pro Contrast, Tonal Contrast, Detail Extractor et Glamour Glow façonnent la lumière ou le détail. Comparez à 100 % pour éviter une structure excessive."),
                    HelpItem("Film et procédés", "Film Grain ajoute du grain ; Film Emulation modifie la réponse de film sans en générer ; Cross Processing et Bleach Bypass transforment le rendu coloré."),
                    HelpItem("Argentique monochrome", "Silver B&W convertit les couleurs en densités de gris et Silver Toning colore le tirage selon sa densité. Vous pouvez ajouter Film Grain ensuite si souhaité."),
                    HelpItem("Darken / Lighten Center", "Placez le centre sur le sujet, puis dosez séparément l’éclaircissement ou l’assombrissement du centre et des bords."),
                    HelpItem("Looks et Custom", "Choisir un look remplit les paramètres de l’effet. Après une modification, le réglage devient Custom ; le look d’origine reste disponible.")
                ])
            ]
        case .light:
            return [
                HelpSection("Les six réglages", [
                    HelpItem("Exposition", "Déplace la luminosité globale en valeurs d’exposition. Une augmentation éclaire aussi les zones déjà lumineuses ; surveillez l’histogramme et les hautes lumières."),
                    HelpItem("Contraste", "Écarte ou rapproche les valeurs sombres et claires autour des tons moyens. Une forte valeur peut réduire les nuances aux extrémités."),
                    HelpItem("Hautes lumières", "Agit surtout sur les parties lumineuses. Réduisez-les pour mieux préserver une robe, des nuages ou un reflet qui contiennent encore du détail."),
                    HelpItem("Ombres", "Agit surtout sur les parties sombres. Les ouvrir révèle de l’information, mais peut aussi rendre le bruit plus visible."),
                    HelpItem("Blancs", "Ajuste la présence du blanc et des tons très clairs ; ce n’est pas un outil de reconstruction des pixels définitivement écrêtés."),
                    HelpItem("Noirs", "Ajuste la profondeur des tons les plus sombres. Ouvrir légèrement les noirs peut préserver une texture ; les fermer donne plus d’assise.")
                ]),
                HelpSection("Utilisation", [
                    HelpItem("Auto", "Analyse l’image et remplit les curseurs visibles avec une proposition de départ. C’est une action ponctuelle : vous pouvez ensuite retoucher chaque valeur, annuler ou relancer Auto."),
                    HelpItem("Réglage local", "Si un masque est sélectionné, ces curseurs agissent sur ce calque. Sélectionnez Photo entière pour revenir au réglage général."),
                    HelpItem("Contrôle fin", "Touchez la valeur numérique d’un curseur pour réduire sa plage de déplacement ; double-touchez le curseur ou utilisez sa flèche pour le remettre à sa valeur initiale.")
                ])
            ]
        case .color:
            return [
                HelpSection("Balance et intensité", [
                    HelpItem("Température", "Déplace la balance des blancs entre une impression plus froide et plus chaude. Servez-vous d’un gris connu seulement s’il doit réellement être neutre dans la scène."),
                    HelpItem("Teinte", "Corrige l’axe vert–magenta, utile quand l’éclairage laisse une dominante que Température ne suffit pas à enlever."),
                    HelpItem("Saturation", "Augmente ou réduit l’intensité de toutes les couleurs. À forte valeur, les couleurs déjà vives peuvent devenir excessives."),
                    HelpItem("Vibrance", "Dose la couleur plus prudemment sur une scène hétérogène ; contrôlez toujours les carnations et les couleurs proches du gamut.")
                ]),
                HelpSection("Auto et retouche locale", [
                    HelpItem("Auto Couleur", "Utilise la même analyse d’image que les autres outils Auto, mais ne remplit que les réglages colorimétriques. Une scène volontairement chaude n’est pas forcément une erreur de balance des blancs."),
                    HelpItem("Avec Auto Lumière", "Auto Couleur ne reproduit pas l’exposition ni le contraste. Les deux propositions peuvent être utilisées ensemble, puis affinées à la main."),
                    HelpItem("Avec un masque", "Les réglages Couleur peuvent cibler le calque actif. Revenez à Photo entière pour ajuster la photographie dans son ensemble.")
                ])
            ]
        case .curves:
            return [
                HelpSection("Lire et modifier la courbe", [
                    HelpItem("Axes", "L’axe horizontal représente la valeur d’entrée, du noir à gauche au blanc à droite ; l’axe vertical représente la valeur de sortie. Monter un point éclaircit les tons correspondants."),
                    HelpItem("RVB et canaux", "RVB règle la courbe tonale commune. Rouge, Vert et Bleu modifient séparément les canaux : des écarts entre eux peuvent introduire une dominante colorée."),
                    HelpItem("Mode consultation", "Le graphe est passif : commencez un défilement dessus sans risque de déplacer ou créer un point."),
                    HelpItem("Mode Modifier", "Activez Modifier pour déplacer les points. Touchez le graphe pour en créer un ; utilisez les contrôles Entrée/Sortie pour un placement précis, puis Terminé pour redevenir passif."),
                    HelpItem("Pipette", "Touchez la pipette, puis parcourez la photo pour situer une tonalité sur la courbe. L’échantillon n’ajoute pas de point tout seul ; utilisez + pour le faire volontairement."),
                    HelpItem("Supprimer un point", "Sélectionnez un point intérieur puis utilisez la corbeille. Les points d’extrémité gardent leur position horizontale, mais leur hauteur peut être ajustée.")
                ]),
                HelpSection("Auto et cohérence", [
                    HelpItem("Naturel, Équilibré, Soutenu", "Ces trois variantes expriment la même analyse Auto avec une intensité tonale croissante. Les points générés restent éditables."),
                    HelpItem("Avec Auto Lumière", "Auto Courbes représente une correction tonale alternative. Lumora évite d’empiler automatiquement une courbe équivalente sur Auto Lumière, ce qui doublerait la correction."),
                    HelpItem("Undo/Redo", "La création, la suppression ou le déplacement d’un point peuvent être annulés ; quitter Modifier ne change pas le rendu.")
                ])
            ]
        case .colorTools:
            return [
                HelpSection("Mélangeur", [
                    HelpItem("Huit plages", "Rouge, Orange, Jaune, Vert, Turquoise, Bleu, Violet et Magenta sélectionnent des familles de couleurs présentes dans l’image."),
                    HelpItem("Teinte", "Déplace la couleur choisie vers ses voisines. Par exemple, le bleu d’un ciel peut devenir légèrement plus turquoise ou violet."),
                    HelpItem("Saturation", "Rend la famille plus ou moins intense sans appliquer une saturation globale à toute la photographie."),
                    HelpItem("Luminance", "Éclaircit ou assombrit la famille. Un changement important peut modifier la séparation entre ciel, végétation et sujet."),
                    HelpItem("Réinitialiser une plage", "Le reset de la plage courante rend ses trois paramètres neutres, sans toucher aux sept autres.")
                ]),
                HelpSection("Grading", [
                    HelpItem("Zones tonales", "Choisissez Ombres, Tons moyens ou Hautes lumières. La roue règle la nuance et l’intensité de la zone choisie ; sa luminance se règle séparément."),
                    HelpItem("Mélange et Balance", "Mélange adoucit ou distingue les transitions entre zones ; Balance déplace la répartition du traitement vers les tons sombres ou clairs."),
                    HelpItem("Presets Grading", "Les looks proposés remplissent uniquement le grading. Vous pouvez ensuite déplacer la roue ou les curseurs ; l’état devient Personnalisé.")
                ])
            ]
        case .effects:
            return [
                HelpSection("Réglages de finition", [
                    HelpItem("Texture", "Renforce ou adoucit les petits détails, comme un tissu ou des cheveux. Une valeur négative les atténue."),
                    HelpItem("Clarté", "Agit sur un contraste local plus large que Texture. Une dose élevée peut donner un aspect dur aux visages et produire des transitions trop marquées."),
                    HelpItem("Correction du voile", "Augmente ou réduit la séparation dans une scène voilée. Elle influence également le contraste global et légèrement la couleur ; contrôlez les ombres."),
                    HelpItem("Vignette", "Module la luminosité des bords pour guider le regard. Ce réglage de finition diffère du Vignetage optique, destiné à corriger l’objectif."),
                    HelpItem("Grain", "Ajoute une texture de grain à la finition. Creative propose aussi Film Grain : utiliser les deux peut accumuler le grain.")
                ]),
                HelpSection("Conseils de contrôle", [
                    HelpItem("À 100 %", "Vérifiez Texture, Clarté et Grain en taille réelle ; une vue réduite peut masquer un effet trop prononcé."),
                    HelpItem("Masque actif", "Ces réglages suivent le calque sélectionné comme les autres réglages de développement.")
                ])
            ]
        case .detail:
            return [
                HelpSection("Netteté", [
                    HelpItem("Gain", "Détermine l’intensité de netteté. Gardez une valeur modérée si le fichier est déjà accentué."),
                    HelpItem("Rayon", "Détermine la largeur de la transition accentuée autour des contours. Un rayon trop grand peut créer des liserés."),
                    HelpItem("Détail", "Dose la part des structures fines dans l’accentuation. Vérifiez cheveux, pierre et peau à 100 %."),
                    HelpItem("Masquage", "Restreint l’accentuation aux contours pour éviter de renforcer uniformément les zones lisses et leur bruit.")
                ]),
                HelpSection("Réduction du bruit", [
                    HelpItem("Luminance", "Réduit le bruit clair/sombre. Trop de réduction efface les textures ; Détail et Contraste aident à conserver leur présence."),
                    HelpItem("Couleur", "Réduit les taches colorées du bruit. Détail et Lissage contrôlent la finesse de cette correction."),
                    HelpItem("Activation", "Les sous-réglages de netteté et de débruitage deviennent disponibles lorsque leur réglage principal est supérieur à zéro.")
                ])
            ]
        case .optics:
            return [
                HelpSection("Profil constructeur", [
                    HelpItem("Quand il est disponible", "Un RAW peut exposer un profil optique compatible avec iOS. Activez Profil constructeur pour utiliser cette correction. Un fichier déjà développé ne fournit généralement plus ce profil réglable."),
                    HelpItem("Quand il est indisponible", "Le commutateur reste désactivé et le panneau en indique la raison. Vous pouvez toujours utiliser les corrections manuelles ci-dessous.")
                ]),
                HelpSection("Corrections manuelles", [
                    HelpItem("Distorsion", "Compense une courbure visible des lignes, surtout près des bords. Comparez avec des lignes d’architecture et évitez une correction plus forte que nécessaire."),
                    HelpItem("Aberration chromatique", "Ajuste le décalage coloré au bord de forts contrastes. Examinez les silhouettes sur ciel clair à 100 %."),
                    HelpItem("Vignetage optique", "Compense l’assombrissement causé par l’objectif sur les bords. Pour ajouter une vignette artistique, utilisez plutôt Effets → Vignette.")
                ])
            ]
        case .geometry:
            return [
                HelpSection("Orientation et redressement", [
                    HelpItem("Rotation et miroirs", "Les boutons tournent par quarts de tour ou inversent horizontalement/verticalement. Réinitialiser remet les corrections de ce panneau à leur état initial."),
                    HelpItem("Horizon auto", "Estime un redressement de la ligne d’horizon. Vérifiez le résultat sur une scène dépourvue d’horizon évident."),
                    HelpItem("Redresser", "Corrige finement l’inclinaison. La grille de tiers aide à aligner l’horizon ou une ligne architecturale.")
                ]),
                HelpSection("Perspective et cadrage", [
                    HelpItem("Perspective auto", "Propose une correction géométrique, notamment pour des lignes convergentes. L’analyse peut être annulée ou ajustée manuellement."),
                    HelpItem("Verticale et horizontale", "Redressent les convergences dans ces deux directions. Surveillez les bords et la forme du sujet après une forte correction."),
                    HelpItem("Aspect, échelle et décalages", "Affinent les proportions et la position après correction de perspective, afin de retrouver un cadrage utile."),
                    HelpItem("Format", "Choisissez un ratio de recadrage. Recadrage ajuste le zoom et Position horizontale/verticale déplace la fenêtre visible dans l’image.")
                ])
            ]
        case .masks:
            return [
                HelpSection("Calques", [
                    HelpItem("Photo entière", "C’est la base globale. Ajouter un masque crée un calque local au-dessus, sélectionnable et réordonnable."),
                    HelpItem("Sélection et réglages", "Sélectionnez un masque ici, puis ouvrez Lumière, Couleur, Courbes, Colorimétrie, Effets ou Détail pour ajuster cette zone. Les curseurs ne sont pas dupliqués dans Masques."),
                    HelpItem("Nom, opacité et ordre", "Renommez un masque pour le retrouver, dosez sa contribution avec l’opacité et déplacez-le dans la pile si son interaction avec les autres calques doit changer."),
                    HelpItem("Visible / Contour", "Bascule entre l’overlay rouge et le contour du masque. Ce bouton concerne l’affichage de l’overlay, pas l’activation de la retouche."),
                    HelpItem("Inverser", "Échange la zone sélectionnée et son complément. Pratique pour traiter l’arrière-plan après avoir isolé un sujet.")
                ]),
                HelpSection("Créer une zone", [
                    HelpItem("Pinceau", "Peindre ajoute au masque, Effacer le retire et Déplacer sert à naviguer dans la photo zoomée. Taille, contour progressif, débit et opacité déterminent la trace."),
                    HelpItem("Gradients", "Les masques linéaire et radial se placent et se redimensionnent avec leurs poignées directement sur la photo, y compris après zoom."),
                    HelpItem("Masques intelligents", "Selon l’image, Lumora peut proposer Sujet, Arrière-plan, Personne, Visage, Yeux, Ciel ou Peau ; inspectez le contour avant une retouche forte."),
                    HelpItem("Ajouter / Soustraire", "Combinez plusieurs composants pour construire une sélection plus précise. Chaque composant peut être sélectionné, réordonné ou retiré."),
                    HelpItem("Gestes de la photo", "Pincez pour zoomer et double-touchez pour rétablir le zoom, même avec le pinceau. Dans Masques, le tracé actualise la visualisation du masque sans relancer le développement complet à chaque geste.")
                ])
            ]
        case .presets:
            return [
                HelpSection("Créer et appliquer", [
                    HelpItem("Créer un preset", "Donnez-lui un nom et choisissez les groupes à sauvegarder. Lumière, Couleur, Courbes, Mélangeur, Grading, Effets, Détail et Creative peuvent être inclus ; Optique, Géométrie et Masques sont optionnels."),
                    HelpItem("Appliquer", "Seuls les groupes enregistrés dans le preset sont remplacés. Les autres réglages de la photo restent tels quels ; l’application peut être annulée en une opération."),
                    HelpItem("Presets personnels", "Ils servent à réutiliser vos choix de développement. Les looks Creative et les presets de Grading sont des sélections intégrées à leurs outils respectifs.")
                ]),
                HelpSection("Gérer et partager", [
                    HelpItem("Renommer ou supprimer", "Organisez votre collection personnelle sans modifier les réglages déjà enregistrés dans une photographie."),
                    HelpItem("Importer et exporter", "Partagez un preset au format JSON Lumora. Avant d’appliquer un preset reçu, vérifiez quels groupes il contient, notamment Géométrie et Masques.")
                ])
            ]
        }
    }
}
