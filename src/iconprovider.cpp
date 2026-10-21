#include "iconprovider.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QSvgRenderer>
#include <QtDebug>

namespace {
// Tamaño de dibujo de los SVG de Lucide cuando el Image no pide uno
constexpr int DefaultSize = 24;
}

IconProvider::IconProvider(const QString &iconDir)
    : QQuickImageProvider(QQuickImageProvider::Image)
    , m_iconDir(iconDir)
{
}

QImage IconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // id = "<nombre>?color=<aarrggbb>"
    const QString name = id.section(QLatin1Char('?'), 0, 0);
    const QString query = id.section(QLatin1Char('?'), 1);
    QColor color(Qt::white);
    if (query.startsWith(QLatin1String("color=")))
        color = QColor(QLatin1Char('#') + query.mid(6));

    const QSize target(requestedSize.width() > 0 ? requestedSize.width() : DefaultSize,
                       requestedSize.height() > 0 ? requestedSize.height() : DefaultSize);
    if (size)
        *size = target;

    QImage image(target, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);

    // El nombre solo puede ser un archivo de la carpeta de iconos
    if (name.isEmpty() || name.contains(QLatin1Char('/')) || name.contains(QLatin1String(".."))) {
        qWarning().noquote() << "[Mitis] Nombre de icono no válido:" << name;
        return image;
    }

    QFile file(QDir(m_iconDir).filePath(name + QLatin1String(".svg")));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning().noquote() << "[Mitis] Icono no encontrado:" << name;
        return image;
    }

    // El color va sin transparencia en el SVG; la transparencia se aplica al pintar
    QByteArray svg = file.readAll();
    svg.replace("currentColor", color.name(QColor::HexRgb).toLatin1());

    QSvgRenderer renderer(svg);
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setOpacity(color.alphaF());
    renderer.render(&painter);

    return image;
}
