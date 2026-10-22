#pragma once

#include <QString>

// Widevine: el módulo de Google para contenido protegido (Netflix, Spotify,
// Disney+…). Qt WebEngine sabe usarlo pero no lo trae, y Mitis no puede
// redistribuirlo: se usa el que ya dejó en el equipo Google Chrome,
// Chromium (en Arch, el paquete chromium-widevine) o Firefox.
namespace Widevine {

// Ruta de la biblioteca encontrada, o "" si no hay ninguna. Busca en los
// sitios habituales de cada sistema y, si hay varias, se queda con la de
// versión más alta.
QString find();

// Se la pasa al motor (--widevine-path en QTWEBENGINE_CHROMIUM_FLAGS). Debe
// llamarse antes de QtWebEngineQuick::initialize(). Si el usuario ya indicó
// una ruta en esa variable, se respeta. Devuelve la ruta que usará el motor
// ("" si no hay).
QString setup();

}
