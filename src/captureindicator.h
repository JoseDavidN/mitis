#pragma once

#include <QHash>
#include <QIcon>
#include <QObject>
#include <QPair>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Aviso de micrófono y cámara en el icono de Mitis (barra de tareas en
// Windows y Linux, Dock en macOS). Cada pestaña informa de lo suyo con
// report() y aquí se junta lo de todas las ventanas:
//  · Sin uso: el icono normal.
//  · En uso: el icono con una marca roja (micrófono, cámara o los dos) que
//    parpadea, alternando con el normal.
//  · Abierto pero silenciado (Meet, Zoom… al silenciar dejan el micrófono
//    abierto y mudo): la marca, fija.
// Los dos iconos se dibujan una sola vez por combinación; el parpadeo solo
// cambia cuál se muestra. En QML es el singleton `CaptureIndicator` del
// módulo Mitis.Core.
class CaptureIndicator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Estado de todo Mitis: Off, Muted o Active
    Q_PROPERTY(int microphone READ microphone NOTIFY changed)
    Q_PROPERTY(int camera READ camera NOTIFY changed)

public:
    enum State { Off = 0, Muted = 1, Active = 2 };
    Q_ENUM(State)

    explicit CaptureIndicator(QObject *parent = nullptr);
    ~CaptureIndicator() override;

    int microphone() const { return m_microphone; }
    int camera() const { return m_camera; }

    // Lo que usa ahora `source` (una pestaña). Con los dos en Off se olvida.
    Q_INVOKABLE void report(QObject *source, int microphone, int camera);

signals:
    void changed();

private:
    void update();
    void showMarked(bool marked);
    QIcon markedIcon(const QString &glyph) const;

    QHash<QObject *, QPair<int, int>> m_sources;
    int m_microphone = Off;
    int m_camera = Off;
    QIcon m_base;
    QIcon m_marked;
    QString m_markedGlyph;
    QTimer m_blink;
    bool m_markShown = false;
};
