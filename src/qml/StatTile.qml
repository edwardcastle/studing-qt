// ---------------------------------------------------------------------------
// StatTile.qml -- a tiny reusable component: caption on top, big value below.
//
// TEACHING NOTE
// Any .qml file whose name starts with a capital letter is a *type*. Put it in
// the module and you can use it like a built-in element. Extracting repeated
// blocks into small files like this one is the main way QML stays readable.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: tile

    property string caption
    property string value

    spacing: 0

    Text {
        text: tile.caption
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }
    Text {
        text: tile.value
        color: Theme.text
        font.pixelSize: Theme.fontLarge
        font.bold: true
    }
}
