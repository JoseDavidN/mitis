#include "red.h"

#include <windows.h>
#include <bcrypt.h>
#include <winhttp.h>

#include <algorithm>
#include <cctype>
#include <cwctype>
#include <iterator>
#include <sstream>

// L"…" a partir de la versión que da CMake ("0.8.1-beta")
#define ANCHO_(x) L##x
#define ANCHO(x) ANCHO_(x)

namespace {

std::wstring desdeUtf8(const std::string &texto)
{
    const int largo = MultiByteToWideChar(CP_UTF8, 0, texto.data(), int(texto.size()), nullptr, 0);
    std::wstring resultado(size_t(largo), L'\0');
    if (largo > 0)
        MultiByteToWideChar(CP_UTF8, 0, texto.data(), int(texto.size()), resultado.data(), largo);
    return resultado;
}

std::string recortar(const std::string &texto)
{
    const size_t inicio = texto.find_first_not_of(" \t\r\n");
    if (inicio == std::string::npos)
        return {};
    const size_t fin = texto.find_last_not_of(" \t\r\n");
    return texto.substr(inicio, fin - inicio + 1);
}

// Cierra los manejadores de WinHTTP al salir del ámbito
struct Manejador {
    HINTERNET h = nullptr;
    ~Manejador()
    {
        if (h)
            WinHttpCloseHandle(h);
    }
};

const wchar_t *const SinConexion =
    L"No se pudo conectar con el servidor de Mitis. Comprueba tu conexión y vuelve a intentarlo.";

// Números de la versión (0.8.1) y si es una etapa previa (-beta)
struct Partes {
    int numeros[3] = {};
    bool previa = false;
};

Partes partes(const std::wstring &version)
{
    Partes p;
    size_t i = 0;
    for (int n = 0; n < 3 && i < version.size(); ++n) {
        while (i < version.size() && iswdigit(version[i]))
            p.numeros[n] = p.numeros[n] * 10 + (version[i++] - L'0');
        if (i < version.size() && version[i] == L'.')
            ++i;
    }
    p.previa = version.find(L'-') != std::wstring::npos;
    return p;
}

} // namespace

std::wstring urlServidor(const std::wstring &archivo)
{
    return desdeUtf8(MITIS_SERVIDOR) + L"/" + archivo;
}

std::wstring descargar(const std::wstring &url, std::vector<char> &datos, const std::function<void(double)> &avance)
{
    datos.clear();
    URL_COMPONENTS partesUrl { sizeof(partesUrl) };
    wchar_t servidor[256] = {};
    wchar_t ruta[2048] = {};
    partesUrl.lpszHostName = servidor;
    partesUrl.dwHostNameLength = DWORD(std::size(servidor));
    partesUrl.lpszUrlPath = ruta;
    partesUrl.dwUrlPathLength = DWORD(std::size(ruta));
    if (!WinHttpCrackUrl(url.c_str(), 0, 0, &partesUrl))
        return L"La dirección del servidor de Mitis no es válida.";

    Manejador sesion { WinHttpOpen(L"MitisInstalador/" ANCHO(MITIS_VERSION), WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                   WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0) };
    if (!sesion.h)
        return SinConexion;
    // Conectar: 15 s; cada lectura: 60 s (paquete grande, conexión lenta)
    WinHttpSetTimeouts(sesion.h, 15000, 15000, 30000, 60000);
    Manejador conexion { WinHttpConnect(sesion.h, servidor, partesUrl.nPort, 0) };
    if (!conexion.h)
        return SinConexion;
    const DWORD segura = partesUrl.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0;
    Manejador peticion { WinHttpOpenRequest(conexion.h, L"GET", ruta, nullptr, WINHTTP_NO_REFERER,
                                            WINHTTP_DEFAULT_ACCEPT_TYPES, segura | WINHTTP_FLAG_REFRESH) };
    if (!peticion.h)
        return SinConexion;
    if (!WinHttpSendRequest(peticion.h, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0)
        || !WinHttpReceiveResponse(peticion.h, nullptr))
        return SinConexion;

    DWORD estado = 0;
    DWORD tamano = sizeof(estado);
    WinHttpQueryHeaders(peticion.h, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX,
                        &estado, &tamano, WINHTTP_NO_HEADER_INDEX);
    if (estado != 200)
        return L"El servidor de Mitis no tiene el archivo que se buscaba (código " + std::to_wstring(estado) + L").";

    uint64_t total = 0;
    wchar_t largo[32] = {};
    tamano = sizeof(largo);
    if (WinHttpQueryHeaders(peticion.h, WINHTTP_QUERY_CONTENT_LENGTH, WINHTTP_HEADER_NAME_BY_INDEX, largo, &tamano,
                            WINHTTP_NO_HEADER_INDEX))
        total = _wcstoui64(largo, nullptr, 10);
    if (total)
        datos.reserve(size_t(total));

    int ultimaMilesima = -1;
    for (;;) {
        DWORD disponibles = 0;
        if (!WinHttpQueryDataAvailable(peticion.h, &disponibles))
            return L"Se cortó la descarga. Comprueba tu conexión y vuelve a intentarlo.";
        if (disponibles == 0)
            break;
        const size_t antes = datos.size();
        datos.resize(antes + disponibles);
        DWORD leidos = 0;
        if (!WinHttpReadData(peticion.h, datos.data() + antes, disponibles, &leidos))
            return L"Se cortó la descarga. Comprueba tu conexión y vuelve a intentarlo.";
        datos.resize(antes + leidos);
        if (avance && total) {
            const int milesima = int(double(datos.size()) * 1000 / double(total));
            if (milesima != ultimaMilesima) {
                ultimaMilesima = milesima;
                avance(double(datos.size()) / double(total));
            }
        }
    }
    if (total && datos.size() != total)
        return L"La descarga llegó incompleta. Vuelve a intentarlo.";
    return std::wstring();
}

std::wstring consultarUltima(Ultima &ultima)
{
    std::vector<char> datos;
    const std::wstring error = descargar(urlServidor(L"version.txt"), datos);
    if (!error.empty())
        return error;
    std::istringstream lineas(std::string(datos.begin(), datos.end()));
    std::string linea;
    while (std::getline(lineas, linea)) {
        const size_t igual = linea.find('=');
        if (igual == std::string::npos)
            continue;
        const std::string clave = recortar(linea.substr(0, igual));
        const std::string valor = recortar(linea.substr(igual + 1));
        if (clave == "version")
            ultima.version = desdeUtf8(valor);
        else if (clave == "paquete")
            ultima.paquete = desdeUtf8(valor);
        else if (clave == "sha256")
            ultima.sha256 = valor;
        else if (clave == "instalador")
            ultima.instalador = desdeUtf8(valor);
        else if (clave == "instalador_sha256")
            ultima.instaladorSha256 = valor;
    }
    for (auto *hash : { &ultima.sha256, &ultima.instaladorSha256 }) {
        for (char &c : *hash)
            c = char(tolower(static_cast<unsigned char>(c)));
    }
    // El nombre del paquete no puede salirse de la carpeta del servidor
    if (ultima.version.empty() || ultima.paquete.empty() || ultima.sha256.size() != 64
        || ultima.paquete.find_first_of(L"/\\:") != std::wstring::npos
        || ultima.instalador.find_first_of(L"/\\:") != std::wstring::npos)
        return L"El servidor de Mitis respondió algo inesperado. Vuelve a intentarlo más tarde.";
    return std::wstring();
}

std::string sha256(const std::vector<char> &datos)
{
    BCRYPT_ALG_HANDLE algoritmo = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    unsigned char resumen[32] = {};
    std::string resultado;
    if (BCryptOpenAlgorithmProvider(&algoritmo, BCRYPT_SHA256_ALGORITHM, nullptr, 0) != 0)
        return resultado;
    if (BCryptCreateHash(algoritmo, &hash, nullptr, 0, nullptr, 0, 0) == 0) {
        // Por bloques: BCryptHashData recibe un ULONG
        size_t hecho = 0;
        bool bien = true;
        while (bien && hecho < datos.size()) {
            const ULONG trozo = ULONG(std::min<size_t>(datos.size() - hecho, 1u << 30));
            bien = BCryptHashData(hash, reinterpret_cast<PUCHAR>(const_cast<char *>(datos.data() + hecho)), trozo, 0)
                == 0;
            hecho += trozo;
        }
        if (bien && BCryptFinishHash(hash, resumen, sizeof(resumen), 0) == 0) {
            const char *cifras = "0123456789abcdef";
            for (unsigned char byte : resumen) {
                resultado += cifras[byte >> 4];
                resultado += cifras[byte & 0xf];
            }
        }
        BCryptDestroyHash(hash);
    }
    BCryptCloseAlgorithmProvider(algoritmo, 0);
    return resultado;
}

int compararVersiones(const std::wstring &a, const std::wstring &b)
{
    const Partes pa = partes(a);
    const Partes pb = partes(b);
    for (int i = 0; i < 3; ++i) {
        if (pa.numeros[i] != pb.numeros[i])
            return pa.numeros[i] < pb.numeros[i] ? -1 : 1;
    }
    // Con los mismos números, la beta va antes que la final
    if (pa.previa != pb.previa)
        return pa.previa ? -1 : 1;
    return 0;
}
