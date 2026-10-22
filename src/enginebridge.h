#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

#include <atomic>

class RequestInterceptor;

// Lo que BrowserProfile.qml y BrowserTab.qml necesitan del motor y QML no
// ofrece: el interceptor de peticiones y el filtro de cookies del perfil, y
// las preferencias de Configuración que estos aplican. Se publica en QML como la
// propiedad de contexto `MitisEngine` (no como tipo del módulo, que en
// --dev no existe).
class EngineBridge : public QObject
{
    Q_OBJECT
    // Versión de Chrome que se declara en el inicio de sesión de Google
    Q_PROPERTY(QString googleChromeVersion READ googleChromeVersion CONSTANT)
    // Biblioteca de Widevine que usa el motor; "" si no se encontró ninguna
    // (las páginas con contenido protegido no se podrán reproducir)
    Q_PROPERTY(QString widevinePath READ widevinePath CONSTANT)
    // Preferencias que se aplican petición a petición (las enlaza BrowserProfile)
    Q_PROPERTY(bool blockThirdPartyCookies READ blockThirdPartyCookies WRITE setBlockThirdPartyCookies NOTIFY preferencesChanged)
    Q_PROPERTY(bool doNotTrack READ doNotTrack WRITE setDoNotTrack NOTIFY preferencesChanged)
    Q_PROPERTY(bool httpsUpgrade READ httpsUpgrade WRITE setHttpsUpgrade NOTIFY preferencesChanged)

public:
    explicit EngineBridge(const QString &widevinePath, QObject *parent = nullptr);

    QString googleChromeVersion() const;
    QString widevinePath() const { return m_widevinePath; }
    bool blockThirdPartyCookies() const { return m_blockThirdPartyCookies; }
    void setBlockThirdPartyCookies(bool value);
    bool doNotTrack() const;
    void setDoNotTrack(bool value);
    bool httpsUpgrade() const;
    void setHttpsUpgrade(bool value);

    // `profile` es el WebEngineProfile de BrowserProfile.qml: le pone el
    // interceptor de peticiones y el filtro de cookies
    Q_INVOKABLE void installInterceptor(QObject *profile);
    // Borra todas las cookies del perfil (QML no llega a su almacén)
    Q_INVOKABLE void clearCookies(QObject *profile);
    // Falló la carga de `url`: true si era una página subida de http a https,
    // que entonces hay que volver a pedir por http (ver RequestInterceptor)
    Q_INVOKABLE bool takeHttpsFallback(const QUrl &url);
    // `url` es una página que Mitis subió de http a https (el usuario no pidió https)
    Q_INVOKABLE bool isHttpsUpgrade(const QUrl &url) const;
    // La página `url` cargó bien
    Q_INVOKABLE void confirmHttps(const QUrl &url);

signals:
    void preferencesChanged();

private:
    RequestInterceptor *m_interceptor;
    QString m_widevinePath;
    // Lo lee el filtro de cookies, que el motor puede llamar desde otro hilo
    std::atomic<bool> m_blockThirdPartyCookies { false };
};
