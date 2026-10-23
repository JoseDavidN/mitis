#pragma once

#include <QImage>
#include <QObject>
#include <QRect>
#include <QVariant>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Captura de pantalla de la página (ScreenshotOverlay): junta en una imagen
// los trozos que copia QML (grabToImage de la capa de las páginas, sin la
// interfaz) y la guarda en PNG o la copia al portapapeles. Una captura más
// alta que la ventana llega en varios trozos, uno por cada desplazamiento de
// la página. Todo en píxeles de la imagen (lógicos × devicePixelRatio). En
// QML es el singleton `Screenshot` del módulo Mitis.Core.
class Screenshot : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Screenshot(QObject *parent = nullptr);

    // Empieza una captura de width × height píxeles (transparente)
    Q_INVOKABLE void begin(int width, int height, qreal devicePixelRatio);
    // Copia el rectángulo `source` de `image` (lo que da ItemGrabResult.image)
    // en la captura, a la altura `targetY`
    Q_INVOKABLE bool paste(const QVariant &image, const QRect &source, int targetY);
    // Guarda la captura en `folder` como «Captura de Mitis AAAA-MM-DD HH.MM.SS.png»
    // (sin pisar otra). Devuelve { path, fileName, bytes }, o {} si no se pudo
    Q_INVOKABLE QVariantMap save(const QString &folder) const;
    // Al portapapeles del sistema
    Q_INVOKABLE bool copy() const;
    Q_INVOKABLE void clear();

private:
    QImage m_image;      // en píxeles, sin devicePixelRatio
    qreal m_devicePixelRatio = 1;
};
