# In-app editor help

The **Help** tab follows **Presets** in the full-width bottom editor toolbar, in portrait and landscape. Landscape controls occupy a side column above that toolbar. It covers all eleven editing tabs. Selecting a topic opens a scrollable reading sheet with that tab’s controls, gestures, and interactions; **Close** returns to the topic list. The guide is bundled with the app and works offline.

Topics are **Creative**, **Light**, **Color**, **Curves**, **Color Tools**, **Effects**, **Detail**, **Optics**, **Geometry**, **Masks**, and **Presets**. Their content lives in `Lumora/UI/EditorHelpView.swift`, alongside the interface labels. Update the relevant topic when a control is renamed, added, or removed.

Help is read-only: opening and closing a topic does not create an Undo operation, change the active layer, or alter development settings. The photo information row is hidden in this tab to leave room for the topics. The accessibility identifiers `help-controls`, `help-topic-*`, `help-detail-*`, and `help-close` support simulator tests.
