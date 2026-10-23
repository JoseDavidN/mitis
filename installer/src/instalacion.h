#pragma once

#include <functional>
#include <string>
#include <vector>

// Lo que hace el instalador, sin interfaz. Cada función informa del avance
// (0 a 1) por `avance`, desde el hilo en el que se la llame, y devuelve ""
// si todo fue bien o el error en español, listo para mostrar.
//
// Mitis se instala para el usuario, sin permisos de administrador (como
// Chrome): en %LOCALAPPDATA%\Programs\Mitis, con accesos directos en el menú
// Inicio y el escritorio y su entrada en «Aplicaciones instaladas».

using Avance = std::function<void(double)>;

// Carpeta donde se instala Mitis ("" si Windows no da la de programas del usuario)
std::wstring carpetaInstalacion();

// Lo que hay instalado, según lo que deja instalar(): la entrada de
// «Aplicaciones instaladas» en el registro o Mitis.exe en su carpeta
struct Instalada {
    bool hay = false;
    std::wstring version; // DisplayVersion; "" si no se sabe
};
Instalada instalacionExistente();

// Si el ejecutable está dentro de la carpeta de instalación (el instalador
// que queda allí para actualizar y desinstalar)
bool dentroDeInstalacion(const std::wstring &ejecutable);

// Instala `paquete` (el ZIP descargado, en memoria: ver empaquetar.ps1) como
// la versión `version`. En la carpeta queda `instaladorNuevo` (el del
// servidor) como mitis-instalador.exe o, si está vacío, una copia de
// `instalador` (este mismo). Si Mitis se está cerrando (actualización),
// espera unos segundos a que suelte sus archivos.
std::wstring instalar(const std::vector<char> &paquete, const std::wstring &version,
                      const std::vector<char> &instaladorNuevo, const std::wstring &instalador,
                      const Avance &avance);

// Quita Mitis: archivos, accesos directos y la entrada de Windows. Los datos
// del usuario (historial, marcadores…, en %LOCALAPPDATA%\Mitis) se conservan.
// Desde fuera de la carpeta (el instalador) la borra entera al momento; desde
// dentro (desinstalar.exe), la carpeta se borra cuando el proceso termina.
std::wstring desinstalar(const Avance &avance);

// Abre el Mitis instalado
void abrirMitis();

// Espera (hasta `milisegundos`) a que termine el proceso `pid`: el Mitis que
// pidió la actualización
void esperarProceso(unsigned long pid, unsigned long milisegundos);

// Borra `archivo` en cuanto termine este proceso (la copia temporal del
// instalador con la que se actualiza)
void borrarAlTerminar(const std::wstring &archivo);
