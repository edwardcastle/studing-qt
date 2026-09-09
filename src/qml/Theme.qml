// ---------------------------------------------------------------------------
// Theme.qml -- a QML singleton holding every colour and size used by the UI.
//
// TEACHING NOTE
// `pragma Singleton` + the QT_QML_SINGLETON_TYPE property in CMakeLists.txt
// makes exactly one instance of this object, created the first time something
// says `Theme.something`. Because the properties are ordinary QML properties,
// any binding that reads them updates itself if you ever change them at
// runtime -- that is all a "dark mode switch" really is.
//
// Hard coding "#e05252" in twelve delegates is the single most common reason a
// QML project becomes impossible to restyle. Put it here instead.
// ---------------------------------------------------------------------------

pragma Singleton

import QtQuick

// A QML file that lives in the DevBoard module still has to import the module
// explicitly to see the C++ types registered under that URI -- here the
// `Priority` enum namespace from src/core/Task.h. Only sibling *.qml types are
// visible automatically.
import DevBoard

QtObject {
    // --- Colours -----------------------------------------------------------
    readonly property color background:     "#11131a"
    readonly property color surface:        "#1a1d26"
    readonly property color surfaceHover:   "#222634"
    readonly property color border:         "#2c3140"
    readonly property color accent:         "#5b8def"
    readonly property color accentSoft:     "#28344d"
    readonly property color text:           "#e6e9f0"
    readonly property color textMuted:      "#8d93a6"
    readonly property color danger:         "#e0605a"
    readonly property color warning:        "#e0a458"
    readonly property color success:        "#57b894"

    // --- Metrics -----------------------------------------------------------
    readonly property int spacingSmall: 6
    readonly property int spacing: 12
    readonly property int spacingLarge: 20
    readonly property int radius: 8
    readonly property int rowHeight: 64

    // --- Type --------------------------------------------------------------
    readonly property int fontSmall: 12
    readonly property int fontNormal: 14
    readonly property int fontLarge: 18
    readonly property int fontTitle: 22

    // --- Helpers -----------------------------------------------------------
    // A plain JavaScript function on a singleton is a perfectly good place for
    // small presentation rules. Anything heavier belongs in C++.
    function priorityColor(level) {
        switch (level) {
        case Priority.High:   return danger;
        case Priority.Low:    return textMuted;
        default:              return accent;
        }
    }
}
