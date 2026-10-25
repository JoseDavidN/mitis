import QtQuick
import Mitis.Core

// Icono SVG de assets/icons/ (Lucide, trazo redondeado) coloreado con el
// tema. Lo dibuja IconProvider (C++) al tamaño exacto, nítido a cualquier
// escala. Uso: Icon { name: "back"; color: Colors.inkSoft }
Image {
    id: root

    // Nombre del archivo sin ".svg"
    property string name: ""
    property color color: Colors.inkSoft
    // Con un color aquí, el icono se rellena con un degradado diagonal de
    // `color` (arriba a la izquierda) a `colorEnd` (abajo a la derecha)
    property color colorEnd: "transparent"
    property int size: Theme.iconSize

    width: size
    height: size
    sourceSize: Qt.size(size, size)
    fillMode: Image.PreserveAspectFit
    // "#aarrggbb" → "aarrggbb": el "#" no puede ir en la URL
    source: name === "" ? ""
          : "image://icon/" + name + "?color=" + color.toString().slice(1)
            + (colorEnd.a > 0 ? "&end=" + colorEnd.toString().slice(1) : "")
}
