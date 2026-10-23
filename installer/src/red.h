#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

// Lo que el instalador pide al servidor de Mitis (MITIS_SERVIDOR, sin barra
// final). Allí están:
//
//   version.txt                  la última versión, una clave por línea:
//                                  version=0.8.1-beta
//                                  paquete=Mitis-0.8.1-beta-windows.zip
//                                  sha256=<64 caracteres hexadecimales>
//                                  instalador=MitisInstalador.exe
//                                  instalador_sha256=<…>
//                                  macos=…, macos_sha256=…, linux=…, linux_sha256=…
//                                  (los usa Mitis para actualizarse en esos sistemas)
//   Mitis-…-windows.zip          Mitis con Qt y el runtime de Visual C++
//   MitisInstalador.exe          este instalador (el que queda instalado
//                                para actualizar y desinstalar)
//
// El servidor es /srv/docker/mitis-releases (nginx en Docker); el workflow
// arma su contenido en el artefacto «mitis-servidor».
//
// Todo se descarga a memoria: en el disco solo queda lo instalado.

struct Ultima {
    std::wstring version;
    std::wstring paquete;     // nombre del ZIP en el servidor
    std::string sha256;       // del ZIP, en minúsculas
    std::wstring instalador;  // "" si el servidor no lo da
    std::string instaladorSha256;
};

// Descarga `url` entera en `datos`. `avance` (0 a 1) solo si el servidor dice
// el tamaño. Devuelve "" o el error en español
std::wstring descargar(const std::wstring &url, std::vector<char> &datos,
                       const std::function<void(double)> &avance = {});

// Lee version.txt del servidor
std::wstring consultarUltima(Ultima &ultima);

std::wstring urlServidor(const std::wstring &archivo);

// SHA-256 en hexadecimal (minúsculas)
std::string sha256(const std::vector<char> &datos);

// <0, 0 o >0 como strcmp: 0.8.1 < 0.8.2; 0.9.0-beta < 0.9.0
int compararVersiones(const std::wstring &a, const std::wstring &b);
