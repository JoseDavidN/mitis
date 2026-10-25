#pragma once

#include <QByteArray>
#include <QSet>
#include <QString>
#include <QWebEngineUrlRequestInterceptor>

#include <atomic>

class ContentBlocker;

// Ve cada petición de las páginas antes de que salga: bloquea anuncios y
// rastreadores (ContentBlocker) y quita el rastreo de los enlaces, pide no
// ser rastreado (Configuración → Privacidad), abre con https:// las
// direcciones http:// (Seguridad).
// Se llama para cada petición, en el hilo de la interfaz: debe ser rápido.
class RequestInterceptor : public QWebEngineUrlRequestInterceptor
{
public:
    // `strict`: el de las ventanas privadas, con todo lo de privacidad
    // siempre activo (bloqueador sin sitios permitidos, sin parámetros de
    // rastreo, DNT y https), sin mirar Configuración
    explicit RequestInterceptor(ContentBlocker *blocker, bool strict = false, QObject *parent = nullptr);

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

private:
    ContentBlocker *m_blocker;
    const bool m_strict;

    // Hosts subidos a https cuya carga aún no ha terminado bien
    QSet<QString> m_upgraded;
    // Hosts que se quedan en http (https no funcionó)
    QSet<QString> m_httpAllowed;
};
