#pragma once

#include <functional>
#include <string>

// Lo que hace el instalador, sin interfaz. Cada función informa del avance
// (0 a 1) por `avance`, desde el hilo en el que se la llame, y devuelve ""
// si todo fue bien o el error en español, listo para mostrar.
//
// Mitis se instala para el usuario, sin permisos de administrador (como
// Chrome): en %LOCALAPPDATA%\Programs\Mitis, con accesos directos en el menú
// Inicio y el escritorio y su entrada en «Aplicaciones instaladas».

using Avance = std::function<void(double)>;

// Carpeta donde se instala Mitis
std::wstring carpetaInstalacion();

// Instala el paquete que lleva el propio ejecutable `instalador` (ver
// empaquetar.ps1: el ZIP va pegado al final del .exe, con una marca)
std::wstring instalar(const std::wstring &instalador, const Avance &avance);

// Quita Mitis: archivos, accesos directos y la entrada de Windows. Los datos
// del usuario (historial, marcadores…, en %LOCALAPPDATA%\Mitis) se conservan.
std::wstring desinstalar(const Avance &avance);

// Abre el Mitis instalado
void abrirMitis();
