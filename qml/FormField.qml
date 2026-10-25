import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Campo de texto de formulario con el estilo de Mitis.
TextField {
    id: root

    implicitHeight: Theme.controlHeight
    leftPadding: Theme.margin
    rightPadding: Theme.margin
    verticalAlignment: TextInput.AlignVCenter
    color: Colors.ink
    placeholderTextColor: Colors.inkMuted
    selectionColor: Colors.selection
    selectedTextColor: Colors.ink
    font.pixelSize: Theme.fontSize
    selectByMouse: true

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Colors.tintSunken
        border.width: 1
        border.color: root.activeFocus ? Colors.focusRing : Colors.hairline
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }
}
