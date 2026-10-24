import QtQuick

// Lo que el vidrio esmerilado (Glass) difumina a través de los controles que
// tiene encima: el fondo de una página propia (nueva pestaña, Configuración,
// novedades). Se pone alrededor del fondo, debajo del contenido. Sin la
// transparencia experimental es un Item normal.
Item {
    readonly property bool glassBackdrop: true
}
