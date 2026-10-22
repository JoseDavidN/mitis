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
#include <vector>

#include "miniz.h"

namespace fs = std::filesystem;

namespace {

// Final del instalador: [stub][ZIP][desplazamiento del ZIP: 8 bytes][marca: 8 bytes]
constexpr char Marca[8] = { 'M', 'I', 'T', 'I', 'S', 'P', 'A', 'Q' };
constexpr int Pie = 16;

const wchar_t *const ClaveDesinstalar = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Mitis";
const wchar_t *const Ejecutable = L"Mitis.exe";
const wchar_t *const Desinstalador = L"desinstalar.exe";

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

// Copia el principio del instalador (sin el paquete): sirve de desinstalador
bool copiarDesinstalador(FILE *instalador, uint64_t tamano, const std::wstring &destino)
{
    FILE *salida = _wfopen(destino.c_str(), L"wb");
    if (!salida)
        return false;
    std::vector<char> bloque(1 << 16);
    _fseeki64(instalador, 0, SEEK_SET);
    uint64_t faltan = tamano;
    bool bien = true;
    while (faltan > 0 && bien) {
        const size_t pedir = size_t(faltan < bloque.size() ? faltan : bloque.size());
        const size_t leidos = fread(bloque.data(), 1, pedir, instalador);
        bien = leidos == pedir && fwrite(bloque.data(), 1, leidos, salida) == leidos;
        faltan -= leidos;
    }
    return fclose(salida) == 0 && bien;
}

} // namespace

std::wstring carpetaInstalacion()
{
    // %LOCALAPPDATA%\Programs: programas por usuario, sin administrador
    return carpetaConocida(FOLDERID_UserProgramFiles) + L"\\Mitis";
}

std::wstring instalar(const std::wstring &instalador, const Avance &avance)
{
    FILE *exe = _wfopen(instalador.c_str(), L"rb");
    if (!exe)
        return L"No se pudo leer el instalador.";

    // El pie: dónde empieza el paquete
    char pie[Pie] = {};
    _fseeki64(exe, -Pie, SEEK_END);
    const int64_t tamanoExe = _ftelli64(exe) + Pie;
    uint64_t inicio = 0;
    if (fread(pie, 1, Pie, exe) != Pie || std::memcmp(pie + 8, Marca, 8) != 0) {
        fclose(exe);
        return L"El instalador está dañado: descárgalo de nuevo.";
    }
    std::memcpy(&inicio, pie, 8);
    if (inicio == 0 || int64_t(inicio) >= tamanoExe - Pie) {
        fclose(exe);
        return L"El instalador está dañado: descárgalo de nuevo.";
    }

    mz_zip_archive zip;
    mz_zip_zero_struct(&zip);
    _fseeki64(exe, int64_t(inicio), SEEK_SET);
    if (!mz_zip_reader_init_cfile(&zip, exe, uint64_t(tamanoExe - Pie) - inicio, 0)) {
        fclose(exe);
        return L"El instalador está dañado: descárgalo de nuevo.";
    }

    const fs::path carpeta = carpetaInstalacion();
    const fs::path anterior = carpeta.wstring() + L".anterior";
    std::error_code error;
    fs::remove_all(anterior, error);
    // Una versión instalada se aparta (no se borra hasta terminar). Si no se
    // puede mover es que Mitis está abierto: sus archivos están en uso.
    if (fs::exists(carpeta)) {
        fs::rename(carpeta, anterior, error);
        if (error) {
            mz_zip_reader_end(&zip);
            fclose(exe);
            return L"Mitis está abierto. Ciérralo y vuelve a intentarlo.";
        }
    }

    // Si algo falla, se deja todo como estaba
    bool zipAbierto = true;
    bool exeAbierto = true;
    auto deshacer = [&](const std::wstring &mensaje) {
        if (zipAbierto)
            mz_zip_reader_end(&zip);
        if (exeAbierto)
            fclose(exe);
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
            return deshacer(L"El instalador está dañado: descárgalo de nuevo.");
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
        return deshacer(L"El instalador está incompleto: descárgalo de nuevo.");
    const bool conDesinstalador = copiarDesinstalador(exe, inicio, (carpeta / Desinstalador).wstring());
    fclose(exe);
    exeAbierto = false;
    if (!conDesinstalador)
        return deshacer(L"No se pudo crear el desinstalador.");
    avance(0.94);

    // ── Accesos directos y entrada en «Aplicaciones instaladas» ──
    accesoDirecto(mitis.wstring(), accesoMenuInicio());
    accesoDirecto(mitis.wstring(), accesoEscritorio());
    HKEY clave = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, ClaveDesinstalar, 0, nullptr, 0, KEY_WRITE, nullptr, &clave, nullptr)
        == ERROR_SUCCESS) {
        textoRegistro(clave, L"DisplayName", L"Mitis");
        textoRegistro(clave, L"DisplayVersion", desdeUtf8(MITIS_VERSION));
        textoRegistro(clave, L"Publisher", L"StartCode");
        textoRegistro(clave, L"DisplayIcon", mitis.wstring());
        textoRegistro(clave, L"InstallLocation", carpeta.wstring());
        textoRegistro(clave, L"UninstallString", L"\"" + (carpeta / Desinstalador).wstring() + L"\" --desinstalar");
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
    const fs::path carpeta = carpetaInstalacion();
    std::error_code error;

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

    // El resto de archivos, menos este desinstalador (está en marcha)
    std::vector<fs::path> archivos;
    for (const auto &entrada : fs::recursive_directory_iterator(carpeta, error)) {
        if (entrada.is_regular_file() && entrada.path().filename() != Desinstalador)
            archivos.push_back(entrada.path());
    }
    for (size_t i = 0; i < archivos.size(); ++i) {
        fs::remove(archivos[i], error);
        avance(0.05 + 0.95 * double(i + 1) / double(archivos.size()));
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
