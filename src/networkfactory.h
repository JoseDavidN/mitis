#pragma once

#include <QQmlNetworkAccessManagerFactory>
#include <QString>

// Red de la interfaz QML (favicons de los accesos rápidos, noticias) con
// caché en disco: lo ya descargado no se vuelve a pedir en cada arranque.
// No afecta a las páginas web, que van por el perfil de WebEngine.
class NetworkFactory : public QQmlNetworkAccessManagerFactory
{
public:
    explicit NetworkFactory(const QString &cacheDir);

    QNetworkAccessManager *create(QObject *parent) override;

private:
    QString m_cacheDir;
};
