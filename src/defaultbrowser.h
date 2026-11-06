#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Mitis como navegador predeterminado, por el camino oficial de cada sistema:
// enlaces (http, https) y archivos de páginas web. Lo que deja elegir a Mitis
// lo registra la instalación (instalador de Windows, Info.plist de macOS,
// mitis.desktop en Linux).
//   Windows: ningún programa puede imponerse; se abre Configuración de Windows
//            en la página de Mitis, donde se confirma con un botón.
//   macOS:   el sistema pregunta y se confirma en su ventana (defaultbrowser_mac.mm).
//   Linux:   xdg-settings y xdg-mime, sin preguntar; un AppImage crea antes su
//            mitis.desktop, que no trae instalado.
//
// En QML es el singleton `DefaultBrowser` del módulo Mitis.Core; hay uno para
// toda la app (también entre recargas de --dev).
class DefaultBrowser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Mitis abre los enlaces del sistema
    Q_PROPERTY(bool isDefault READ isDefault NOTIFY changed)
    // Se puede elegir: está instalado (registrado en el sistema)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    // Ya se comprobó al menos una vez (en Linux tarda un momento)
    Q_PROPERTY(bool checked READ checked NOTIFY changed)

public:
    static DefaultBrowser *instance();
    static DefaultBrowser *create(QQmlEngine *, QJSEngine *);

    bool isDefault() const { return m_isDefault; }
    bool available() const { return m_available; }
    bool checked() const { return m_checked; }

    // Vuelve a mirar: el usuario puede cambiarlo fuera de Mitis
    Q_INVOKABLE void refresh();
    // Pide al sistema que Mitis sea el predeterminado
    Q_INVOKABLE void makeDefault();

signals:
    void changed();

private:
    explicit DefaultBrowser(QObject *parent = nullptr);
    void report(bool available, bool isDefault);

    bool m_isDefault = false;
    bool m_available = false;
    bool m_checked = false;
};

#ifdef Q_OS_MACOS
// defaultbrowser_mac.mm: `done` se llama en el hilo principal
#include <functional>
bool macIsDefaultBrowser();
void macMakeDefaultBrowser(std::function<void()> done);
#endif
