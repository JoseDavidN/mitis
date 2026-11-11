#include "networkfactory.h"

#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkDiskCache>

namespace {
// Iconos y titulares ocupan poco: con esto sobra
constexpr qint64 MaxCacheSize = 20 * 1024 * 1024;
}

NetworkFactory::NetworkFactory(const QString &cacheDir)
    : m_cacheDir(cacheDir)
{
}

// El motor puede pedir un gestor por hilo (las imágenes asíncronas cargan
// en otro); todos comparten la carpeta, cuya escritura es atómica por archivo
QNetworkAccessManager *NetworkFactory::create(QObject *parent)
{
    auto *manager = new QNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(manager);
    cache->setCacheDirectory(m_cacheDir);
    cache->setMaximumCacheSize(MaxCacheSize);
    manager->setCache(cache);
    // El proxy de las páginas (EngineBridge::applyProxy) es el de la
    // aplicación: la interfaz no lo usa
    manager->setProxy(QNetworkProxy::NoProxy);
    return manager;
}
