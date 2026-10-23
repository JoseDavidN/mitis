#include "instalacion.h"

#include <windows.h>
#include <objidl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <iterator>
#include <vector>

#include "miniz.h"

namespace fs = std::filesystem;

namespace {

const wchar_t *const ClaveDesinstalar = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Mitis";
const wchar_t *const Ejecutable = L"Mitis.exe";
// El instalador que queda junto a Mitis: actualiza y desinstala
const wchar_t *const Instalador = L"mitis-instalador.exe";

std::wstring carpetaConocida(REFKNOWNFOLDERID id)
{
    PWSTR ruta = nullptr;
    std::wstring resultado;
    if (SUCCEEDED(SHGetKnownFolderPath(id, KF_FLAG_CREATE, nullptr, &ruta)))
        resultado = ruta;
    CoTaskMemFree(ruta);
    return resultado;
}

std::wstring desdeUtf8(const char *texto)
{
    const int largo = MultiByteToWideChar(CP_UTF8, 0, texto, -1, nullptr, 0);
    std::wstring resultado(largo > 0 ? largo - 1 : 0, L'\0');
    if (largo > 1)
        MultiByteToWideChar(CP_UTF8, 0, texto, -1, resultado.data(), largo);
    return resultado;
}

// Avisa como mucho una vez por milésima: no satura la ventana de mensajes
class Contador
{
public:
    Contador(const Avance &avance, double desde, double hasta)
        : m_avance(avance), m_desde(desde), m_hasta(hasta) {}
    void fraccion(double f)
    {
        const int milesima = int(f * 1000);
        if (milesima == m_ultima)
            return;
        m_ultima = milesima;
        m_avance(m_desde + (m_hasta - m_desde) * f);
    }

private:
    const Avance &m_avance;
    double m_desde, m_hasta;
    int m_ultima = -1;
};

struct Escritura {
    HANDLE archivo;
    uint64_t *hechos;
    uint64_t total;
    Contador *contador;
};

size_t escribir(void *opaco, mz_uint64, const void *datos, size_t n)
{
    auto *e = static_cast<Escritura *>(opaco);
    DWORD escritos = 0;
    if (!WriteFile(e->archivo, datos, DWORD(n), &escritos, nullptr) || escritos != n)
        return 0;
    *e->hechos += n;
    if (e->total)
        e->contador->fraccion(double(*e->hechos) / double(e->total));
    return n;
}

// Un ZIP podría traer rutas que se salgan de la carpeta («..», absolutas)
bool rutaSegura(const std::wstring &ruta)
{
    if (ruta.empty() || ruta[0] == L'/' || ruta[0] == L'\\' || ruta.find(L':') != std::wstring::npos)
        return false;
    for (const auto &parte : fs::path(ruta)) {
        if (parte == L"..")
            return false;
    }
    return true;
}

bool accesoDirecto(const std::wstring &destino, const std::wstring &enlace)
{
    IShellLinkW *link = nullptr;
    if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link))))
        return false;
    link->SetPath(destino.c_str());
    link->SetWorkingDirectory(fs::path(destino).parent_path().c_str());
    link->SetDescription(L"Mitis, navegador web");
    IPersistFile *archivo = nullptr;
    bool hecho = false;
    if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&archivo)))) {
        hecho = SUCCEEDED(archivo->Save(enlace.c_str(), TRUE));
        archivo->Release();
    }
    link->Release();
    return hecho;
}

void textoRegistro(HKEY clave, const wchar_t *nombre, const std::wstring &valor)
{
    RegSetValueExW(clave, nombre, 0, REG_SZ, reinterpret_cast<const BYTE *>(valor.c_str()),
                   DWORD((valor.size() + 1) * sizeof(wchar_t)));
}

void numeroRegistro(HKEY clave, const wchar_t *nombre, DWORD valor)
{
    RegSetValueExW(clave, nombre, 0, REG_DWORD, reinterpret_cast<const BYTE *>(&valor), sizeof(valor));
}

// Valor de texto en HKCU\<ruta> (`nombre` nulo: el valor por defecto)
void valorUsuario(const std::wstring &ruta, const wchar_t *nombre, const std::wstring &valor)
{
    HKEY clave = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, ruta.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &clave, nullptr)
        == ERROR_SUCCESS) {
        textoRegistro(clave, nombre, valor);
        RegCloseKey(clave);
    }
}

// Navegador que se puede elegir como predeterminado (Configuración de
// Windows → Aplicaciones predeterminadas), como manda Microsoft: un ProgID
// que abre Mitis con la dirección, sus capacidades y RegisteredApplications.
// Elegirlo lo hace el usuario: Windows no deja que un programa se imponga.
const wchar_t *const ClaveNavegador = L"Software\\Clients\\StartMenuInternet\\Mitis";
const wchar_t *const ClaveProgId = L"Software\\Classes\\MitisHTML";

void registrarNavegador(const std::wstring &mitis)
{
    const std::wstring icono = mitis + L",0";
    const std::wstring abrir = L"\"" + mitis + L"\" \"%1\"";
    const std::wstring progId = ClaveProgId;
    valorUsuario(progId, nullptr, L"Página web de Mitis");
    valorUsuario(progId, L"URL Protocol", L"");
    valorUsuario(progId + L"\\DefaultIcon", nullptr, icono);
    valorUsuario(progId + L"\\shell\\open\\command", nullptr, abrir);

    const std::wstring navegador = ClaveNavegador;
    const std::wstring capacidades = navegador + L"\\Capabilities";
    valorUsuario(navegador, nullptr, L"Mitis");
    valorUsuario(navegador + L"\\DefaultIcon", nullptr, icono);
    valorUsuario(navegador + L"\\shell\\open\\command", nullptr, L"\"" + mitis + L"\"");
    valorUsuario(capacidades, L"ApplicationName", L"Mitis");
    valorUsuario(capacidades, L"ApplicationDescription", L"Navegador web ligero y con interfaz propia");
    valorUsuario(capacidades, L"ApplicationIcon", icono);
    valorUsuario(capacidades + L"\\StartMenu", L"StartMenuInternet", L"Mitis");
    for (const wchar_t *esquema : { L"http", L"https" })
        valorUsuario(capacidades + L"\\URLAssociations", esquema, L"MitisHTML");
    for (const wchar_t *extension : { L".htm", L".html", L".xhtml" })
        valorUsuario(capacidades + L"\\FileAssociations", extension, L"MitisHTML");
    valorUsuario(L"Software\\RegisteredApplications", L"Mitis", capacidades);
}

void quitarNavegador()
{
    RegDeleteTreeW(HKEY_CURRENT_USER, ClaveNavegador);
    RegDeleteTreeW(HKEY_CURRENT_USER, ClaveProgId);
    HKEY clave = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\RegisteredApplications", 0, KEY_SET_VALUE, &clave)
        == ERROR_SUCCESS) {
        RegDeleteValueW(clave, L"Mitis");
        RegCloseKey(clave);
    }
}

std::wstring accesoMenuInicio()
{
    return carpetaConocida(FOLDERID_Programs) + L"\\Mitis.lnk";
}

std::wstring accesoEscritorio()
{
    return carpetaConocida(FOLDERID_Desktop) + L"\\Mitis.lnk";
}

bool escribirArchivo(const fs::path &destino, const std::vector<char> &datos)
{
    HANDLE archivo = CreateFileW(destino.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (archivo == INVALID_HANDLE_VALUE)
        return false;
    DWORD escritos = 0;
    const bool bien = WriteFile(archivo, datos.data(), DWORD(datos.size()), &escritos, nullptr) && escritos == datos.size();
    CloseHandle(archivo);
    return bien;
}

} // namespace

std::wstring carpetaInstalacion()
{
    // %LOCALAPPDATA%\Programs: programas por usuario, sin administrador. Sin
    // ella, "" (y no «\Mitis», que sería una carpeta en la raíz del disco)
    const std::wstring programas = carpetaConocida(FOLDERID_UserProgramFiles);
    return programas.empty() ? std::wstring() : programas + L"\\Mitis";
}

Instalada instalacionExistente()
{
    Instalada actual;
    HKEY clave = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, ClaveDesinstalar, 0, KEY_QUERY_VALUE, &clave) == ERROR_SUCCESS) {
        actual.hay = true;
        // Búfer a ceros y un carácter menos: el texto siempre acaba en nulo
        wchar_t version[64] = {};
        DWORD tipo = 0;
        DWORD bytes = DWORD(sizeof(version) - sizeof(wchar_t));
        if (RegQueryValueExW(clave, L"DisplayVersion", nullptr, &tipo, reinterpret_cast<BYTE *>(version), &bytes)
                == ERROR_SUCCESS
            && tipo == REG_SZ)
            actual.version = version;
        RegCloseKey(clave);
    }
    const std::wstring carpeta = carpetaInstalacion();
    std::error_code error;
    if (!carpeta.empty() && fs::exists(fs::path(carpeta) / Ejecutable, error))
        actual.hay = true;
    return actual;
}

bool dentroDeInstalacion(const std::wstring &ejecutable)
{
    const std::wstring carpeta = carpetaInstalacion();
    if (carpeta.empty())
        return false;
    // equivalent() compara el archivo real: sin líos de mayúsculas ni rutas cortas
    std::error_code error;
    return fs::equivalent(fs::path(ejecutable).parent_path(), carpeta, error);
}

std::wstring instalar(const std::vector<char> &paquete, const std::wstring &version,
                      const std::vector<char> &instaladorNuevo, const std::wstring &instalador,
                      const Avance &avance)
{
    mz_zip_archive zip;
    mz_zip_zero_struct(&zip);
    if (!mz_zip_reader_init_mem(&zip, paquete.data(), paquete.size(), 0))
        return L"La descarga llegó dañada. Vuelve a intentarlo.";

    if (carpetaInstalacion().empty()) {
        mz_zip_reader_end(&zip);
        return L"Windows no indica dónde instalar los programas del usuario.";
    }
    const fs::path carpeta = carpetaInstalacion();
    const fs::path anterior = carpeta.wstring() + L".anterior";
    std::error_code error;
    fs::remove_all(anterior, error);
    // Una versión instalada se aparta (no se borra hasta terminar). Si no se
    // puede mover es que Mitis está abierto: sus archivos están en uso. Al
    // actualizar, Mitis (y sus procesos de páginas) tarda un poco en cerrarse
    if (fs::exists(carpeta)) {
        for (int intento = 0; intento < 40; ++intento) {
            error.clear();
            fs::rename(carpeta, anterior, error);
            if (!error)
                break;
            Sleep(500);
        }
        if (error) {
            mz_zip_reader_end(&zip);
            return L"Mitis está abierto. Ciérralo y vuelve a intentarlo.";
        }
    }

    // Si algo falla, se deja todo como estaba
    bool zipAbierto = true;
    auto deshacer = [&](const std::wstring &mensaje) {
        if (zipAbierto)
            mz_zip_reader_end(&zip);
        std::error_code ignorado;
        fs::remove_all(carpeta, ignorado);
        if (fs::exists(anterior))
            fs::rename(anterior, carpeta, ignorado);
        return mensaje;
    };

    // ── Archivos (2 % → 92 %) ──
    const mz_uint archivos = mz_zip_reader_get_num_files(&zip);
    uint64_t total = 0;
    for (mz_uint i = 0; i < archivos; ++i) {
        mz_zip_archive_file_stat info;
        if (mz_zip_reader_file_stat(&zip, i, &info))
            total += info.m_uncomp_size;
    }
    avance(0.02);
    Contador contador(avance, 0.02, 0.92);
    uint64_t hechos = 0;
    for (mz_uint i = 0; i < archivos; ++i) {
        mz_zip_archive_file_stat info;
        if (!mz_zip_reader_file_stat(&zip, i, &info))
            return deshacer(L"La descarga llegó dañada. Vuelve a intentarlo.");
        std::wstring nombre = desdeUtf8(info.m_filename);
        for (auto &c : nombre) {
            if (c == L'/')
                c = L'\\';
        }
        if (!rutaSegura(nombre))
            continue;
        const fs::path destino = carpeta / nombre;
        if (info.m_is_directory) {
            fs::create_directories(destino, error);
            continue;
        }
        fs::create_directories(destino.parent_path(), error);
        HANDLE archivo = CreateFileW(destino.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                                     FILE_ATTRIBUTE_NORMAL, nullptr);
        if (archivo == INVALID_HANDLE_VALUE)
            return deshacer(L"No se pudo escribir en " + carpeta.wstring() + L".");
        Escritura escritura { archivo, &hechos, total, &contador };
        const bool bien = mz_zip_reader_extract_to_callback(&zip, i, escribir, &escritura, 0);
        CloseHandle(archivo);
        if (!bien)
            return deshacer(L"No se pudo copiar " + nombre + L". ¿Queda espacio en el disco?");
    }
    mz_zip_reader_end(&zip);
    zipAbierto = false;

    const fs::path mitis = carpeta / Ejecutable;
    if (!fs::exists(mitis))
        return deshacer(L"El paquete de Mitis está incompleto. Vuelve a intentarlo más tarde.");
    // El instalador del servidor (o este mismo) queda para actualizar y desinstalar
    const bool conInstalador = instaladorNuevo.empty()
        ? CopyFileW(instalador.c_str(), (carpeta / Instalador).c_str(), FALSE) != 0
        : escribirArchivo(carpeta / Instalador, instaladorNuevo);
    if (!conInstalador)
        return deshacer(L"No se pudo copiar el instalador en la carpeta de Mitis.");
    avance(0.94);

    // ── Accesos directos y entrada en «Aplicaciones instaladas» ──
    accesoDirecto(mitis.wstring(), accesoMenuInicio());
    accesoDirecto(mitis.wstring(), accesoEscritorio());
    HKEY clave = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, ClaveDesinstalar, 0, nullptr, 0, KEY_WRITE, nullptr, &clave, nullptr)
        == ERROR_SUCCESS) {
        textoRegistro(clave, L"DisplayName", L"Mitis");
        textoRegistro(clave, L"DisplayVersion", version);
        textoRegistro(clave, L"Publisher", L"StartCode");
        textoRegistro(clave, L"DisplayIcon", mitis.wstring());
        textoRegistro(clave, L"InstallLocation", carpeta.wstring());
        textoRegistro(clave, L"UninstallString", L"\"" + (carpeta / Instalador).wstring() + L"\" --desinstalar");
        numeroRegistro(clave, L"EstimatedSize", DWORD(total / 1024));
        numeroRegistro(clave, L"NoModify", 1);
        numeroRegistro(clave, L"NoRepair", 1);
        RegCloseKey(clave);
    }
    registrarNavegador(mitis.wstring());
    // Los iconos del menú y del escritorio, y el navegador en Aplicaciones
    // predeterminadas, aparecen al momento
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);

    fs::remove_all(anterior, error);
    avance(1.0);
    return std::wstring();
}

std::wstring desinstalar(const Avance &avance)
{
    if (carpetaInstalacion().empty())
        return L"Windows no indica dónde están los programas del usuario.";
    const fs::path carpeta = carpetaInstalacion();
    std::error_code error;

    // Desde fuera de la carpeta todo se borra ya; desde el instalador que
    // queda dentro, este no puede borrarse mientras se ejecuta
    wchar_t propio[MAX_PATH * 4] = {};
    GetModuleFileNameW(nullptr, propio, DWORD(std::size(propio)));
    const bool dentro = dentroDeInstalacion(propio);

    // Primero Mitis.exe: si está en uso, Mitis está abierto y no se toca nada
    const fs::path mitis = carpeta / Ejecutable;
    if (fs::exists(mitis) && !DeleteFileW(mitis.c_str()))
        return L"Mitis está abierto. Ciérralo y vuelve a intentarlo.";

    DeleteFileW(accesoMenuInicio().c_str());
    DeleteFileW(accesoEscritorio().c_str());
    RegDeleteTreeW(HKEY_CURRENT_USER, ClaveDesinstalar);
    quitarNavegador();
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
    avance(0.05);

    // El resto de archivos, menos este desinstalador si está en marcha
    std::vector<fs::path> archivos;
    for (const auto &entrada : fs::recursive_directory_iterator(carpeta, error)) {
        if (entrada.is_regular_file() && (!dentro || entrada.path().filename() != Instalador))
            archivos.push_back(entrada.path());
    }
    for (size_t i = 0; i < archivos.size(); ++i) {
        fs::remove(archivos[i], error);
        avance(0.05 + 0.95 * double(i + 1) / double(archivos.size()));
    }

    if (!dentro) {
        // Las subcarpetas, ya vacías, y la propia carpeta
        fs::remove_all(carpeta, error);
        if (fs::exists(carpeta, error))
            return L"No se pudo borrar del todo " + carpeta.wstring() + L". Bórrala a mano.";
        avance(1.0);
        return std::wstring();
    }

    // La carpeta y el desinstalador se borran en cuanto este termine
    std::wstring orden = L"cmd.exe /c ping 127.0.0.1 -n 3 > nul & rmdir /s /q \"" + carpeta.wstring() + L"\"";
    STARTUPINFOW inicio { sizeof(inicio) };
    PROCESS_INFORMATION proceso {};
    if (CreateProcessW(nullptr, orden.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr,
                       &inicio, &proceso)) {
        CloseHandle(proceso.hThread);
        CloseHandle(proceso.hProcess);
    }
    avance(1.0);
    return std::wstring();
}

void abrirMitis()
{
    const fs::path carpeta = carpetaInstalacion();
    ShellExecuteW(nullptr, L"open", (carpeta / Ejecutable).c_str(), nullptr, carpeta.c_str(), SW_SHOWNORMAL);
}

void esperarProceso(unsigned long pid, unsigned long milisegundos)
{
    HANDLE proceso = OpenProcess(SYNCHRONIZE, FALSE, pid);
    if (!proceso)
        return; // ya terminó
    WaitForSingleObject(proceso, milisegundos);
    CloseHandle(proceso);
}

void borrarAlTerminar(const std::wstring &archivo)
{
    std::wstring orden = L"cmd.exe /c ping 127.0.0.1 -n 3 > nul & del /f /q \"" + archivo + L"\"";
    STARTUPINFOW inicio { sizeof(inicio) };
    PROCESS_INFORMATION proceso {};
    if (CreateProcessW(nullptr, orden.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &inicio,
                       &proceso)) {
        CloseHandle(proceso.hThread);
        CloseHandle(proceso.hProcess);
    }
}
