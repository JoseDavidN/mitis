import QtQuick

// Icono SVG de assets/icons/ (Lucide, trazo redondeado) coloreado con el
// tema. Lo dibuja IconProvider (C++) al tamaño exacto, nítido a cualquier
// escala. Uso: Icon { name: "back"; color: Theme.inkSoft }
Image {
    id: root

    // Nombre del archivo sin ".svg"
    property string name: ""
    property color color: Theme.inkSoft
    property int size: Theme.iconSize

    width: size
    height: size
    sourceSize: Qt.size(size, size)
    fillMode: Image.PreserveAspectFit
    // "#aarrggbb" → "aarrggbb": el "#" no puede ir en la URL
    source: name !== "" ? "image://icon/" + name + "?color=" + color.toString().slice(1) : ""
}
