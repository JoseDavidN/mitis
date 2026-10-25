#pragma once

#include <QByteArray>
#include <QDateTime>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QUrl>

#include <memory>

#include "filterengine.h"

class QNetworkAccessManager;
class QThread;

// Bloqueador de anuncios y rastreadores: descarga las listas de filtros, las
// guarda en disco (carpeta de datos de Mitis, "filtros"), las renueva cada
// pocos días y las compila en un hilo aparte (FilterEngine). Lo consulta
// RequestInterceptor en cada petición, en el hilo de la interfaz.
//
// Listas: EasyList y EasyPrivacy (anuncios y rastreadores), EasyList en
// español, HaGeZi Pro (dominios, la lista que se usa con Pi-hole) y
// uBlock Origin Unbreak (excepciones que arreglan sitios rotos por las demás).
class ContentBlocker : public QObject
{
    Q_OBJECT

public:
    explicit ContentBlocker(QObject *parent = nullptr);
    ~ContentBlocker() override;

    bool isEnabled() const { return m_enabled; }
    // Al activarlo por primera vez carga las listas (y las descarga si faltan)
    void setEnabled(bool enabled);
    // Sitios (dominio registrable) donde no se bloquea nada
    void setAllowedSites(const QStringList &sites);
    bool stripTracking = true;
    // Hay una ventana privada abierta: las listas hacen falta aunque el
    // bloqueador esté apagado (allí siempre bloquea)
    void setPrivateActive(bool active);

    // `strict` (ventanas privadas): bloquea y limpia aunque esté apagado y
    // sin sitios permitidos
    // ¿Se bloquea esta petición? `page` es la página que la hace
    bool shouldBlock(const QUrl &url, const QUrl &page, FilterEngine::Type type, bool strict = false);
    // La dirección sin parámetros de rastreo (utm_…, fbclid…); igual si no tiene
    QUrl withoutTrackingParams(const QUrl &url, bool strict = false) const;
    // CSS que oculta los huecos de anuncios en la página `page` ("" si nada)
    QString cosmeticCss(const QUrl &page, bool strict = false) const;
    // Sitio de una dirección para la lista de permitidos ("www.a.com" → "a.com")
    static QString siteOf(const QUrl &url);

    int ruleCount() const { return m_engine ? m_engine->ruleCount() : 0; }
    quint64 blockedCount() const { return m_blocked; }
    // Cuándo se descargaron las listas (la más antigua); inválido si no hay
    QDateTime updated() const { return m_updated; }
    bool updating() const { return m_network != nullptr || m_compiling; }

    // Vuelve a descargar las listas ahora
    void update();

signals:
    // Reglas, fecha o estado de actualización
    void stateChanged();
    // Como mucho una vez por segundo
    void blockedCountChanged();

private:
    void compile();
    void downloadNext();
    bool allowedSite(const QByteArray &pageHost) const;
    QString filterDir() const;

    bool m_enabled = false;
    bool m_privateActive = false;
    QSet<QByteArray> m_allowedSites;
    std::shared_ptr<const FilterEngine> m_engine;
    bool m_compiling = false;
    bool m_recompile = false;
    QThread *m_thread = nullptr;
    QDateTime m_updated;
    quint64 m_blocked = 0;
    bool m_blockedNotifyPending = false;

    // Descarga en curso (solo existe mientras dura)
    QNetworkAccessManager *m_network = nullptr;
    int m_downloadIndex = 0;
    // Ya se intentó renovar al compilar (sin conexión no se reintenta en bucle)
    bool m_autoUpdated = false;

    // Última página con excepción total consultada (muchas peticiones seguidas son de la misma)
    QByteArray m_lastPageUrl;
    bool m_lastPageAllowed = false;
};
