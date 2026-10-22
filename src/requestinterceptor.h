#pragma once

#include <QByteArray>
#include <QSet>
#include <QString>
#include <QWebEngineUrlRequestInterceptor>

#include <atomic>

// Ve cada petición de las páginas antes de que salga: pide no ser rastreado
// (Configuración → Privacidad), abre con https:// las direcciones http://
// (Seguridad) y ajusta las Client Hints del inicio de sesión de Google. El
// bloqueador de anuncios de la Fase 5 se apoyará en esta misma pieza.
// Se llama para cada petición, en el hilo de la interfaz: debe ser rápido.
class RequestInterceptor : public QWebEngineUrlRequestInterceptor
{
public:
    explicit RequestInterceptor(QObject *parent = nullptr);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

    // Cabeceras DNT y Sec-GPC en todas las peticiones
    std::atomic<bool> doNotTrack { false };
    // Las páginas http:// se piden por https://, salvo los hosts de
    // m_httpAllowed (donde https falló) y los de la red local
    std::atomic<bool> httpsUpgrade { true };

    // La carga de `host` por https falló tras subirla desde http: true si
    // fue así (y desde ahora ese host va por http en esta sesión)
    bool takeHttpsFallback(const QString &host);
    // `host` se subió a https y aún no ha cargado bien
    bool isUpgraded(const QString &host) const { return m_upgraded.contains(host); }
    // La página de `host` cargó bien por https: un fallo posterior ya no se
    // debe a la subida (p. ej. sin conexión) y no vuelve a http
    void confirmHttps(const QString &host);

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

    // Hosts subidos a https cuya carga aún no ha terminado bien
    QSet<QString> m_upgraded;
    // Hosts que se quedan en http (https no funcionó)
    QSet<QString> m_httpAllowed;
};
