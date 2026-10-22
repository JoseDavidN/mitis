import QtQuick

// Avatar del perfil: la foto recortada en círculo o, sin foto, la inicial del
// nombre sobre el color elegido (Theme.avatarColors). Sin nombre ni foto,
// el icono de perfil. El recorte va en un Canvas: funciona también sin GPU.
Item {
    id: root

    property string name: ""
    // Dirección file:// de la foto; vacía = sin foto
    property string photo: ""
    property string colorKey: ""
    property int size: Theme.titleButtonSize

    implicitWidth: size
    implicitHeight: size

    readonly property color fill: (Theme.avatarColors.find(item => item.key === colorKey)
                                   ?? Theme.avatarColors[0]).color
    readonly property bool hasPhoto: photo !== "" && probe.status === Image.Ready

    Rectangle {
        visible: !root.hasPhoto
        anchors.fill: parent
        radius: width / 2
        color: root.fill
    }
    Text {
        visible: !root.hasPhoto && root.name !== ""
        anchors.centerIn: parent
        text: root.name.charAt(0).toUpperCase()
        color: Theme.onBrand
        font.pixelSize: Math.round(root.size * 0.45)
        font.weight: Font.Bold
    }
    Icon {
        visible: !root.hasPhoto && root.name === ""
        anchors.centerIn: parent
        name: "profile"
        size: Math.round(root.size * 0.6)
        color: Theme.onBrand
    }

    // Solo para saber el tamaño de la foto (y si carga); no se dibuja
    Image {
        id: probe
        visible: false
        source: root.photo
        asynchronous: true
        onStatusChanged: if (status === Image.Ready) canvas.loadImage(root.photo)
    }

    Canvas {
        id: canvas
        visible: root.hasPhoto
        anchors.fill: parent
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (!isImageLoaded(root.photo))
                return
            // Círculo y la foto recortada al centro, sin deformar
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI)
            ctx.clip()
            const w = probe.implicitWidth, h = probe.implicitHeight
            const side = Math.min(w, h)
            ctx.drawImage(root.photo, (w - side) / 2, (h - side) / 2, side, side, 0, 0, width, height)
        }
    }
    Connections {
        target: root
        function onPhotoChanged() {
            canvas.requestPaint()
        }
    }
}
