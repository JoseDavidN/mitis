// Instalador de Mitis para Windows: una ventana propia (como la de Chrome)
// con el logo de Mitis, el estado, una barra de progreso y el logo de
// StartCode. Win32 y GDI+, sin Qt: tiene que funcionar antes de que Qt esté
// instalado. El trabajo (instalacion.cpp) va en un hilo aparte y avisa a la
// ventana con mensajes.
//
//   MitisInstalador.exe                 instala (o actualiza) y abre Mitis
//   desinstalar.exe --desinstalar       lo quita (la entrada de Windows lo llama así)

#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <objidl.h>
#include <shlwapi.h>

#include <algorithm>
#include <memory>
#include <string>
#include <thread>

// Las cabeceras de GDI+ usan min y max sin calificar
namespace Gdiplus {
using std::max;
using std::min;
}
#include <gdiplus.h>

#include "instalacion.h"

using namespace Gdiplus;

namespace {

// Colores del tema Nocturno de Mitis (qml/Theme.qml: los mismos valores)
const Color BgBase(255, 0x07, 0x05, 0x0d);
const Color BgGlow(255, 0x2a, 0x13, 0x52);
const Color Brand1(255, 0xa8, 0x55, 0xf7);
const Color Brand2(255, 0xec, 0x48, 0x99);
const Color Ink(255, 0xf4, 0xf1, 0xff);
const Color InkSecondary(166, 255, 255, 255); // 65 %
const Color InkMuted(115, 255, 255, 255);     // 45 %
const Color Track(26, 255, 255, 255);         // tintActive, 10 %
const Color Hairline(33, 255, 255, 255);      // 13 %
const Color TintHover(15, 255, 255, 255);     // 6 %
const Color Danger(255, 0xfb, 0x71, 0x85);

// Medidas a 100 % de escala (se multiplican por los DPI de la pantalla)
constexpr int Ancho = 480;
constexpr int Alto = 340;

// Recursos (recursos.rc.in)
constexpr int RecursoFuente = 101;
constexpr int RecursoStartCode = 102;

constexpr UINT MsgAvance = WM_APP + 1;    // wParam: milésimas
constexpr UINT MsgTerminado = WM_APP + 2; // lParam: std::wstring* con el error ("" si bien)
constexpr UINT_PTR TimerAnimacion = 1;
constexpr UINT_PTR TimerCerrar = 2;

enum class Fase { Trabajando, Listo, Error };

struct Estado {
    bool desinstalando = false;
    Fase fase = Fase::Trabajando;
    double objetivo = 0;  // avance real
    double mostrado = 0;  // el de la barra, que lo sigue suavemente
    std::wstring error;
    bool sobreBoton = false;
    float escala = 1;
    std::thread trabajo;
    // Objetos de GDI+: se crean tras GdiplusStartup y se sueltan antes de
    // GdiplusShutdown (liberarRecursos)
    std::unique_ptr<PrivateFontCollection> fuentes;
    std::unique_ptr<FontFamily> familia;
    std::unique_ptr<Bitmap> startcode;
    std::wstring instalador;
};

Estado estado;

// ── Recursos ─────────────────────────────────────────────────────────

const void *recurso(int id, DWORD *tamano)
{
    HRSRC info = FindResourceW(nullptr, MAKEINTRESOURCEW(id), MAKEINTRESOURCEW(10)); // RT_RCDATA
    HGLOBAL datos = info ? LoadResource(nullptr, info) : nullptr;
    *tamano = info ? SizeofResource(nullptr, info) : 0;
    return datos ? LockResource(datos) : nullptr;
}

void cargarRecursos()
{
    // Nunito, la fuente de la interfaz de Mitis; si falla, la del sistema
    DWORD tamano = 0;
    if (const void *fuente = recurso(RecursoFuente, &tamano)) {
        estado.fuentes = std::make_unique<PrivateFontCollection>();
        estado.fuentes->AddMemoryFont(fuente, INT(tamano));
        INT encontradas = 0;
        if (estado.fuentes->GetFamilyCount() > 0) {
            auto familia = std::make_unique<FontFamily>();
            estado.fuentes->GetFamilies(1, familia.get(), &encontradas);
            if (encontradas > 0)
                estado.familia = std::move(familia);
        }
    }
    if (!estado.familia)
        estado.familia = std::make_unique<FontFamily>(L"Segoe UI");
    if (const void *png = recurso(RecursoStartCode, &tamano)) {
        if (IStream *flujo = SHCreateMemStream(static_cast<const BYTE *>(png), tamano)) {
            estado.startcode.reset(Bitmap::FromStream(flujo));
            flujo->Release();
        }
    }
}

// ── Dibujo ───────────────────────────────────────────────────────────

float px(float valor)
{
    return valor * estado.escala;
}

RectF rectangulo(float x, float y, float ancho, float alto)
{
    return RectF(px(x), px(y), px(ancho), px(alto));
}

void redondeado(GraphicsPath &camino, const RectF &r, float radio)
{
    const float d = radio * 2;
    camino.AddArc(r.X, r.Y, d, d, 180, 90);
    camino.AddArc(r.GetRight() - d, r.Y, d, d, 270, 90);
    camino.AddArc(r.GetRight() - d, r.GetBottom() - d, d, d, 0, 90);
    camino.AddArc(r.X, r.GetBottom() - d, d, d, 90, 90);
    camino.CloseFigure();
}

void texto(Graphics &g, const std::wstring &cadena, const RectF &r, float tamano, int estilo, const Color &color)
{
    Font fuente(estado.familia.get(), px(tamano), estilo, UnitPixel);
    StringFormat formato;
    formato.SetAlignment(StringAlignmentCenter);
    formato.SetLineAlignment(StringAlignmentCenter);
    SolidBrush pincel(color);
    g.DrawString(cadena.c_str(), -1, &fuente, r, &formato, &pincel);
}

RectF rectBoton()
{
    return rectangulo((Ancho - 128) / 2.0f, 214, 128, 34);
}

void dibujar(HDC hdc, int ancho, int alto)
{
    Bitmap lienzo(ancho, alto, PixelFormat32bppARGB);
    Graphics g(&lienzo);
    g.SetSmoothingMode(SmoothingModeAntiAlias);
    g.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
    g.SetInterpolationMode(InterpolationModeHighQualityBicubic);

    // Fondo: resplandor violeta arriba a la izquierda que se funde en negro
    // (como ThemeBackground en Mitis)
    SolidBrush base(BgBase);
    g.FillRectangle(&base, 0, 0, ancho, alto);
    GraphicsPath brillo;
    brillo.AddEllipse(-ancho * 0.45f, -alto * 0.9f, ancho * 1.3f, alto * 1.5f);
    PathGradientBrush resplandor(&brillo);
    resplandor.SetCenterColor(BgGlow);
    Color borde(0, BgGlow.GetR(), BgGlow.GetG(), BgGlow.GetB());
    INT colores = 1;
    resplandor.SetSurroundColors(&borde, &colores);
    g.FillPath(&resplandor, &brillo);

    // Logo de Mitis (provisional, como en la barra de título): círculo con el
    // degradado de la marca y el nombre
    const RectF logo = rectangulo((Ancho - 64) / 2.0f, 46, 64, 64);
    LinearGradientBrush marca(logo, Brand1, Brand2, LinearGradientModeForwardDiagonal);
    g.FillEllipse(&marca, logo);
    texto(g, L"Mitis", rectangulo(0, 118, Ancho, 40), 28, FontStyleBold, Ink);

    // Estado
    std::wstring linea;
    Color colorLinea = InkSecondary;
    if (estado.fase == Fase::Error) {
        linea = estado.error;
        colorLinea = Danger;
    } else if (estado.fase == Fase::Listo) {
        linea = estado.desinstalando ? L"Mitis se ha desinstalado" : L"Mitis está listo. Abriéndolo…";
    } else {
        const int porcentaje = int(estado.mostrado * 100 + 0.5);
        linea = (estado.desinstalando ? L"Desinstalando Mitis… " : L"Instalando Mitis… ")
            + std::to_wstring(porcentaje) + L" %";
    }
    texto(g, linea, rectangulo(32, 160, Ancho - 64, 40), 14, FontStyleRegular, colorLinea);

    if (estado.fase == Fase::Error) {
        // Botón «Cerrar»
        const RectF r = rectBoton();
        GraphicsPath forma;
        redondeado(forma, r, r.Height / 2);
        SolidBrush fondo(estado.sobreBoton ? Track : TintHover);
        g.FillPath(&fondo, &forma);
        Pen linea1(Hairline, px(1));
        g.DrawPath(&linea1, &forma);
        texto(g, L"Cerrar", r, 13, FontStyleBold, Ink);
    } else {
        // Barra de progreso: pista y relleno con el degradado de la marca
        const RectF pista = rectangulo(60, 212, Ancho - 120, 6);
        GraphicsPath formaPista;
        redondeado(formaPista, pista, pista.Height / 2);
        SolidBrush fondoPista(Track);
        g.FillPath(&fondoPista, &formaPista);
        const float lleno = pista.Width * float(std::clamp(estado.mostrado, 0.0, 1.0));
        if (lleno >= pista.Height) {
            RectF relleno(pista.X, pista.Y, lleno, pista.Height);
            GraphicsPath formaRelleno;
            redondeado(formaRelleno, relleno, pista.Height / 2);
            LinearGradientBrush degradado(pista, Brand1, Brand2, LinearGradientModeHorizontal);
            g.FillPath(&degradado, &formaRelleno);
        }
    }

    // Pie: StartCode
    texto(g, L"un proyecto de", rectangulo(0, 262, Ancho, 16), 11, FontStyleRegular, InkMuted);
    if (estado.startcode) {
        const float anchoLogo = 112;
        const float altoLogo = anchoLogo * estado.startcode->GetHeight() / estado.startcode->GetWidth();
        g.DrawImage(estado.startcode.get(), rectangulo((Ancho - anchoLogo) / 2, 278, anchoLogo, altoLogo));
    }

    Graphics pantalla(hdc);
    pantalla.DrawImage(&lienzo, 0, 0);
}

// ── Ventana ──────────────────────────────────────────────────────────

void empezar(HWND ventana)
{
    auto avisar = [ventana](double avance) {
        PostMessageW(ventana, MsgAvance, WPARAM(avance * 1000), 0);
    };
    const bool desinstalando = estado.desinstalando;
    const std::wstring instalador = estado.instalador;
    estado.trabajo = std::thread([ventana, avisar, desinstalando, instalador] {
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        auto *error = new std::wstring(desinstalando ? desinstalar(avisar) : instalar(instalador, avisar));
        CoUninitialize();
        PostMessageW(ventana, MsgTerminado, 0, LPARAM(error));
    });
}

LRESULT CALLBACK procedimiento(HWND ventana, UINT mensaje, WPARAM wParam, LPARAM lParam)
{
    switch (mensaje) {
    case WM_CREATE: {
        estado.escala = GetDpiForWindow(ventana) / 96.0f;
        // Esquinas redondeadas de Windows 11 (en Windows 10 no hace nada)
        const DWORD redondear = 2; // DWMWCP_ROUND
        DwmSetWindowAttribute(ventana, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */, &redondear, sizeof(redondear));
        SetTimer(ventana, TimerAnimacion, 16, nullptr);
        empezar(ventana);
        return 0;
    }
    case WM_DPICHANGED: {
        estado.escala = HIWORD(wParam) / 96.0f;
        const RECT *sugerido = reinterpret_cast<const RECT *>(lParam);
        SetWindowPos(ventana, nullptr, sugerido->left, sugerido->top, sugerido->right - sugerido->left,
                     sugerido->bottom - sugerido->top, SWP_NOZORDER | SWP_NOACTIVATE);
        return 0;
    }
    case MsgAvance:
        estado.objetivo = std::max(estado.objetivo, double(wParam) / 1000.0);
        return 0;
    case MsgTerminado: {
        std::unique_ptr<std::wstring> error(reinterpret_cast<std::wstring *>(lParam));
        if (estado.trabajo.joinable())
            estado.trabajo.join();
        if (error->empty()) {
            estado.fase = Fase::Listo;
            estado.objetivo = 1;
        } else {
            estado.fase = Fase::Error;
            estado.error = *error;
            KillTimer(ventana, TimerAnimacion);
        }
        InvalidateRect(ventana, nullptr, FALSE);
        return 0;
    }
    case WM_TIMER:
        if (wParam == TimerAnimacion) {
            // La barra alcanza al avance real poco a poco
            estado.mostrado += (estado.objetivo - estado.mostrado) * 0.18;
            if (estado.objetivo - estado.mostrado < 0.001)
                estado.mostrado = estado.objetivo;
            InvalidateRect(ventana, nullptr, FALSE);
            if (estado.fase == Fase::Listo && estado.mostrado >= 1.0) {
                KillTimer(ventana, TimerAnimacion);
                if (!estado.desinstalando)
                    abrirMitis();
                SetTimer(ventana, TimerCerrar, 1200, nullptr);
            }
        } else if (wParam == TimerCerrar) {
            DestroyWindow(ventana);
        }
        return 0;
    case WM_NCHITTEST: {
        // Toda la ventana sirve para moverla, salvo el botón
        POINT punto { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
        ScreenToClient(ventana, &punto);
        if (estado.fase == Fase::Error && rectBoton().Contains(PointF(float(punto.x), float(punto.y))))
            return HTCLIENT;
        return HTCAPTION;
    }
    case WM_MOUSEMOVE: {
        const bool sobre = estado.fase == Fase::Error
            && rectBoton().Contains(PointF(float(GET_X_LPARAM(lParam)), float(GET_Y_LPARAM(lParam))));
        if (sobre != estado.sobreBoton) {
            estado.sobreBoton = sobre;
            InvalidateRect(ventana, nullptr, FALSE);
        }
        SetCursor(LoadCursorW(nullptr, sobre ? IDC_HAND : IDC_ARROW));
        return 0;
    }
    case WM_LBUTTONUP:
        if (estado.fase == Fase::Error
            && rectBoton().Contains(PointF(float(GET_X_LPARAM(lParam)), float(GET_Y_LPARAM(lParam)))))
            DestroyWindow(ventana);
        return 0;
    case WM_CLOSE:
        // A medias no se cierra: dejaría Mitis sin instalar del todo
        if (estado.fase != Fase::Trabajando)
            DestroyWindow(ventana);
        return 0;
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT pintura;
        HDC hdc = BeginPaint(ventana, &pintura);
        RECT cliente;
        GetClientRect(ventana, &cliente);
        dibujar(hdc, cliente.right, cliente.bottom);
        EndPaint(ventana, &pintura);
        return 0;
    }
    case WM_DESTROY:
        if (estado.trabajo.joinable())
            estado.trabajo.join();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(ventana, mensaje, wParam, lParam);
}

} // namespace

int WINAPI wWinMain(HINSTANCE instancia, HINSTANCE, PWSTR linea, int)
{
    estado.desinstalando = std::wstring(linea).find(L"--desinstalar") != std::wstring::npos;
    if (estado.desinstalando
        && MessageBoxW(nullptr,
                       L"¿Quieres desinstalar Mitis?\n\nTu historial, marcadores y demás datos se conservan.",
                       L"Desinstalar Mitis", MB_YESNO | MB_ICONQUESTION) != IDYES)
        return 0;

    wchar_t ruta[MAX_PATH * 4];
    GetModuleFileNameW(nullptr, ruta, DWORD(std::size(ruta)));
    estado.instalador = ruta;

    ULONG_PTR tokenGdi = 0;
    GdiplusStartupInput inicioGdi;
    GdiplusStartup(&tokenGdi, &inicioGdi, nullptr);
    cargarRecursos();

    WNDCLASSEXW clase { sizeof(clase) };
    clase.lpfnWndProc = procedimiento;
    clase.hInstance = instancia;
    clase.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    clase.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    clase.lpszClassName = L"MitisInstalador";
    RegisterClassExW(&clase);

    // Centrada en la pantalla principal, al tamaño de sus DPI
    const UINT dpi = GetDpiForSystem();
    const int ancho = MulDiv(Ancho, int(dpi), 96);
    const int alto = MulDiv(Alto, int(dpi), 96);
    const int x = (GetSystemMetrics(SM_CXSCREEN) - ancho) / 2;
    const int y = (GetSystemMetrics(SM_CYSCREEN) - alto) / 2;
    HWND ventana = CreateWindowExW(WS_EX_APPWINDOW, clase.lpszClassName,
                                   estado.desinstalando ? L"Desinstalar Mitis" : L"Instalar Mitis",
                                   WS_POPUP | WS_SYSMENU | WS_MINIMIZEBOX, x, y, ancho, alto, nullptr, nullptr,
                                   instancia, nullptr);
    if (!ventana)
        return 1;
    ShowWindow(ventana, SW_SHOW);
    UpdateWindow(ventana);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    estado.startcode.reset();
    estado.familia.reset();
    estado.fuentes.reset();
    GdiplusShutdown(tokenGdi);
    return 0;
}
