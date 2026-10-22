#pragma once

#include <QObject>
#include <QString>

class RequestInterceptor;

// Lo que BrowserProfile.qml necesita del motor y QML no ofrece: instalar el
// interceptor de peticiones en el perfil. Se publica en QML como la
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

public:
    explicit EngineBridge(const QString &widevinePath, QObject *parent = nullptr);

    QString googleChromeVersion() const;
    QString widevinePath() const { return m_widevinePath; }

    // `profile` es el WebEngineProfile de BrowserProfile.qml
    Q_INVOKABLE void installInterceptor(QObject *profile);

private:
    RequestInterceptor *m_interceptor;
    QString m_widevinePath;
};
