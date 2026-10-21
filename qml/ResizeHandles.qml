pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

// Bordes invisibles para redimensionar la ventana sin marco del sistema.
// Se desactivan cuando la ventana está maximizada.
Item {
    id: root

    required property Window window
    property int grip: Theme.resizeGrip

    anchors.fill: parent
    z: 1000
    visible: window.visibility !== Window.Maximized
             && window.visibility !== Window.FullScreen

    component Edge: MouseArea {
        property int edges: 0
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        // Las inline components no ven los ids del archivo
        onPressed: Window.window.startSystemResize(edges)
    }

    // Lados
    Edge { edges: Qt.TopEdge;    cursorShape: Qt.SizeVerCursor
           x: root.grip; y: 0; width: root.width - 2 * root.grip; height: root.grip }
    Edge { edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor
           x: root.grip; y: root.height - root.grip; width: root.width - 2 * root.grip; height: root.grip }
    Edge { edges: Qt.LeftEdge;   cursorShape: Qt.SizeHorCursor
           x: 0; y: root.grip; width: root.grip; height: root.height - 2 * root.grip }
    Edge { edges: Qt.RightEdge;  cursorShape: Qt.SizeHorCursor
           x: root.width - root.grip; y: root.grip; width: root.grip; height: root.height - 2 * root.grip }

    // Esquinas
    Edge { edges: Qt.TopEdge | Qt.LeftEdge;     cursorShape: Qt.SizeFDiagCursor
           x: 0; y: 0; width: root.grip; height: root.grip }
    Edge { edges: Qt.TopEdge | Qt.RightEdge;    cursorShape: Qt.SizeBDiagCursor
           x: root.width - root.grip; y: 0; width: root.grip; height: root.grip }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge;  cursorShape: Qt.SizeBDiagCursor
           x: 0; y: root.height - root.grip; width: root.grip; height: root.grip }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; cursorShape: Qt.SizeFDiagCursor
           x: root.width - root.grip; y: root.height - root.grip; width: root.grip; height: root.grip }
}
