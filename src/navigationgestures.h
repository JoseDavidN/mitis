#pragma once

#include <QHash>
#include <QObject>
#include <QtQml/qqmlregistration.h>

class QWindow;

// Atrás y adelante sin la barra: botones laterales del ratón (todos los
// sistemas) y gestos de macOS: deslizar con tres dedos y deslizar con dos
// dedos (o uno en el Magic Mouse) si el sistema lo tiene activado
// («Deslizar entre páginas»). Qt WebEngine pasa todo esto a la página pero
// no navega, así que se mira aquí: un filtro de eventos de la aplicación que
// solo observa (los eventos siguen llegando a la página).
//
// El deslizar con dos dedos es también desplazamiento horizontal: mientras
// dura se emite swipeUpdated con su avance y, al soltar, swipeFinished. Es
// la interfaz (Main.qml, con la página) quien decide si era para navegar o
// para desplazar algo de la página. En QML es el singleton
// `NavigationGestures` del módulo Mitis.Core.
class NavigationGestures : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit NavigationGestures(QObject *parent = nullptr);

signals:
    // direction: -1 atrás, 1 adelante. window: la ventana del gesto
    void navigateRequested(QObject *window, int direction);
    // Deslizar con dos dedos: avance 0…1 (1 = soltar navega) en una dirección
    void swipeUpdated(QObject *window, int direction, qreal progress);
    void swipeFinished(QObject *window, bool navigate);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    // Ajuste del sistema: deslizar entre páginas con desplazamiento (solo macOS)
    static bool swipeFromScrollEnabled();

    struct Swipe {
        qreal x = 0;
        qreal y = 0;
        int direction = 0;   // 0: aún sin decidir; ±1: horizontal
        bool ignored = false;
        bool finished = true;
    };
    // Una por ventana: cada una recibe sus eventos
    QHash<QWindow *, Swipe> m_swipes;
};
