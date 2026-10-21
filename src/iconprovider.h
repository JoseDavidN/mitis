#pragma once

#include <QQuickImageProvider>
#include <QString>

// Iconos SVG de assets/icons/ coloreados al vuelo para QML.
// Se piden como "image://icon/<nombre>?color=<aarrggbb>": el SVG usa
// currentColor, que se sustituye por el color pedido (con su transparencia).
// Se dibuja al tamaño exacto que pide el Image, así el trazo queda nítido
// a cualquier escala de pantalla.
class IconProvider : public QQuickImageProvider
{
public:
    explicit IconProvider(const QString &iconDir);

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    QString m_iconDir;
};
