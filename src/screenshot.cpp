#include "screenshot.h"

#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPainter>

Screenshot::Screenshot(QObject *parent)
    : QObject(parent)
{
}

void Screenshot::begin(int width, int height, qreal devicePixelRatio)
{
    m_image = QImage(qMax(1, width), qMax(1, height), QImage::Format_ARGB32_Premultiplied);
    m_image.fill(Qt::transparent);
    m_devicePixelRatio = devicePixelRatio > 0 ? devicePixelRatio : 1;
}

bool Screenshot::paste(const QVariant &image, const QRect &source, int targetY)
{
    const QImage slice = image.value<QImage>();
    if (m_image.isNull() || slice.isNull() || source.isEmpty())
        return false;
    // En píxeles de la imagen: sin devicePixelRatio de por medio
    QImage piece = slice.copy(source);
    piece.setDevicePixelRatio(1);
    QPainter painter(&m_image);
    painter.setCompositionMode(QPainter::CompositionMode_Source);
    painter.drawImage(QPoint(0, targetY), piece);
    return true;
}

QVariantMap Screenshot::save(const QString &folder) const
{
    if (m_image.isNull())
        return {};
    QDir dir(folder);
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return {};
    const QString base = QStringLiteral("Captura de Mitis ")
                         + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH.mm.ss"));
    QString path = dir.filePath(base + QStringLiteral(".png"));
    for (int n = 2; QFileInfo::exists(path); ++n)
        path = dir.filePath(QStringLiteral("%1 (%2).png").arg(base).arg(n));
    if (!m_image.save(path, "PNG"))
        return {};
    const QFileInfo file(path);
    return { { QStringLiteral("path"), path },
             { QStringLiteral("fileName"), file.fileName() },
             { QStringLiteral("bytes"), double(file.size()) } };
}

bool Screenshot::copy() const
{
    if (m_image.isNull())
        return false;
    // Con su devicePixelRatio, para que quien la pegue sepa su tamaño real
    QImage image = m_image;
    image.setDevicePixelRatio(m_devicePixelRatio);
    QGuiApplication::clipboard()->setImage(image);
    return true;
}

void Screenshot::clear()
{
    m_image = QImage();
}
