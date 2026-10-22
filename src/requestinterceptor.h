#pragma once

#include <QByteArray>
#include <QWebEngineUrlRequestInterceptor>

// Ve cada petición de las páginas antes de que salga. Por ahora solo ajusta
// las Client Hints del inicio de sesión de Google; el bloqueador de anuncios
// de la Fase 5 se apoyará en esta misma pieza.
// Se llama para cada petición, en el hilo de red: debe ser rápido.
class RequestInterceptor : public QWebEngineUrlRequestInterceptor
{
public:
    explicit RequestInterceptor(QObject *parent = nullptr);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

    // Versión de Chrome que Mitis declara en el inicio de sesión de Google:
    // la del motor o, si es más antigua, la de Chrome estable vigente
    // (Google rechaza versiones viejas). Se actualiza a mano.
    static QByteArray googleChromeVersion();

private:
    // Google no deja iniciar sesión desde navegadores con motor embebido y
    // los detecta, entre otras cosas, porque sus Client Hints solo dicen
    // "Chromium". En su página de inicio de sesión Mitis añade la marca
    // "Google Chrome" con la versión real del motor, como el Chrome de verdad
    // (con el que comparte motor, conexión y User-Agent).
    QByteArray m_userAgent;
    QByteArray m_brands;
    QByteArray m_fullVersionList;
};
