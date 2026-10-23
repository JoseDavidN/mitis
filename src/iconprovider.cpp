#include "iconprovider.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QLinearGradient>
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
    // id = "<nombre>?color=<aarrggbb>[&end=<aarrggbb>]"; con `end`, el icono
    // se rellena con un degradado diagonal de `color` a `end`
    const QString name = id.section(QLatin1Char('?'), 0, 0);
    const QStringList params = id.section(QLatin1Char('?'), 1).split(QLatin1Char('&'));
    QColor color(Qt::white);
    QColor end;
    for (const QString &param : params) {
        if (param.startsWith(QLatin1String("color=")))
            color = QColor(QLatin1Char('#') + param.mid(6));
        else if (param.startsWith(QLatin1String("end=")))
            end = QColor(QLatin1Char('#') + param.mid(4));
    }

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

    // Degradado: la forma del icono (dibujada arriba) recorta el degradado
    if (end.isValid()) {
        QLinearGradient gradient(0, 0, target.width(), target.height());
        gradient.setColorAt(0, color);
        gradient.setColorAt(1, end);
        painter.setOpacity(1);
        painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
        painter.fillRect(image.rect(), gradient);
    }

    return image;
}
