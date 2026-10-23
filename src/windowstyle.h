#pragma once

class QWindow;

// Esquinas redondeadas de la ventana sin marco, como las del sistema:
//  · Windows 11: se lo pide a DWM (DWMWA_WINDOW_CORNER_PREFERENCE); en
//    Windows 10 no hace nada.
//  · macOS: recorta la superficie de la ventana con esquinas redondeadas y
//    deja transparente lo de fuera; la sombra del sistema sigue la forma
//    (windowstyle_mac.mm). No cambia cómo llega el ratón a la ventana.
//  · Linux: lo decide el gestor de ventanas; no hace nada.
// `rounded` en falso (maximizada, pantalla completa): esquinas rectas.
void setWindowRoundedCorners(QWindow *window, bool rounded);
