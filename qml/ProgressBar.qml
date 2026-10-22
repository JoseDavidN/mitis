import QtQuick

// Barra de progreso fina con el degradado de marca sobre una pista tenue.
// Sin total conocido (`indeterminate`), un tramo recorre la pista sin parar.
Item {
    id: root

    // 0..1
    property real value: 0
    property bool indeterminate: false

    implicitHeight: Theme.downloadBarHeight
    implicitWidth: Theme.downloadPanelWidth

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.tintActive
        clip: true

        Rectangle {
            id: fill
            readonly property real span: track.width * Theme.progressIndeterminateSpan

            height: parent.height
            radius: height / 2
            x: 0
            width: root.indeterminate ? span : track.width * Math.max(0, Math.min(1, root.value))
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.brand1 }
                GradientStop { position: 1.0; color: Theme.brand2 }
            }

            Behavior on width {
                enabled: !root.indeterminate
                NumberAnimation { duration: Theme.durationBase }
            }

            // El tramo entra por la izquierda y sale por la derecha
            NumberAnimation on x {
                running: root.indeterminate && root.visible
                loops: Animation.Infinite
                from: -fill.span
                to: track.width
                duration: Theme.durationIndeterminate
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeInOut
                onRunningChanged: if (!running) fill.x = 0
            }
        }
    }
}
