#include "windowstyle.h"

#include <QWindow>

#if defined(Q_OS_WIN)
#include <windows.h>
#include <dwmapi.h>

namespace {
// Del SDK de Windows 11 (22000); se definen por si se compila con uno anterior
constexpr DWORD CornerPreference = 33;  // DWMWA_WINDOW_CORNER_PREFERENCE
constexpr DWORD CornerDefault = 0;      // DWMWCP_DEFAULT
constexpr DWORD CornerRound = 2;        // DWMWCP_ROUND
}

void setWindowRoundedCorners(QWindow *window, bool rounded)
{
    if (!window)
        return;
    const DWORD preference = rounded ? CornerRound : CornerDefault;
    // En Windows 10 falla sin más: no tiene esquinas redondeadas
    DwmSetWindowAttribute(reinterpret_cast<HWND>(window->winId()), CornerPreference,
                          &preference, sizeof(preference));
}

#elif !defined(Q_OS_MACOS)

void setWindowRoundedCorners(QWindow *, bool) {}

#endif
