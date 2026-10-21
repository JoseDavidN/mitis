import QtQuick
import QtQuick.Controls.Basic

// Campo de texto de formulario con el estilo de Mitis.
TextField {
    id: root

    implicitHeight: Theme.controlHeight
    leftPadding: Theme.margin
    rightPadding: Theme.margin
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.ink
    placeholderTextColor: Theme.inkMuted
    selectionColor: Theme.selection
    selectedTextColor: Theme.ink
    font.pixelSize: Theme.fontSize
    selectByMouse: true

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.tintSunken
        border.width: 1
        border.color: root.activeFocus ? Theme.focusRing : Theme.hairline
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }
}
