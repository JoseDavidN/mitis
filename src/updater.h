#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;
class QNetworkReply;
class QQmlEngine;
class QJSEngine;

// Actualizaciones: consulta version.txt en el servidor de descargas
// (MITIS_SERVIDOR: /srv/docker/mitis-releases) al poco de arrancar y cada
// `CheckInterval`. version.txt lleva una clave por línea (lo arma el
// workflow, artefacto «mitis-servidor»):
//
//   version=0.9.0-beta
//   windows=Mitis-0.9.0-beta-Instalador.exe     windows_sha256=…
//   macos=Mitis-0.9.0-beta-macOS.zip             macos_sha256=…
//   linux=Mitis-0.9.0-beta-x86_64.AppImage       linux_sha256=…   (opcional)
//
// (cada clave en su línea). Si hay una versión más nueva, la interfaz avisa y,
// al aceptar, install() la prepara y emite readyToRestart: la interfaz cierra
// Mitis (guardando la sesión) y lo que quedó en marcha lo reemplaza y lo
// vuelve a abrir.
//
// - Windows: descarga el instalador completo de la versión nueva (clave
//   «windows»: el mismo de siempre, con Mitis dentro), lo comprueba y lo abre
//   con --actualizar <pid>: con su ventana, espera a que Mitis se cierre,
//   instala sin preguntar y lo vuelve a abrir.
// - macOS: descarga Mitis.app comprimido (clave «macos»), lo comprueba y lo
//   descomprime en la carpeta temporal; un script espera a que Mitis se
//   cierre, cambia la app y la abre. Necesita poder escribir donde está la
//   app (en /Applications, si la instaló el usuario).
// - Linux: solo si Mitis se usa como AppImage (clave «linux»): el mismo
//   script cambia el archivo .AppImage. Instalado con el sistema de paquetes
//   (PKGBUILD), solo avisa: lo actualiza el sistema.
//
// En QML es el singleton `Updates` del módulo Mitis.Core.
class Updater : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Updates)
    QML_SINGLETON

    // Versión nueva disponible ("" si no hay)
    Q_PROPERTY(QString available READ available NOTIFY changed)
    Q_PROPERTY(bool checking READ checking NOTIFY changed)
    // Error de la última consulta o actualización ("" si fue bien)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    // Esta instalación se puede actualizar desde Mitis
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY changed)
    // Preparando la actualización (descarga en macOS y Linux)
    Q_PROPERTY(bool installing READ installing NOTIFY changed)
    // Avance de la descarga, de 0 a 1 (-1 si no se sabe)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    // El aviso de la versión `available` se cerró («Más tarde»)
    Q_PROPERTY(bool dismissed READ dismissed NOTIFY changed)

public:
    static Updater *instance();
    static Updater *create(QQmlEngine *, QJSEngine *);

    QString available() const { return m_available; }
    bool checking() const { return m_checking; }
    QString error() const { return m_error; }
    bool canInstall() const;
    bool installing() const { return m_installing; }
    double progress() const { return m_progress; }
    bool dismissed() const { return m_dismissed; }

    Q_INVOKABLE void check();
    // Prepara la actualización; al estar lista, readyToRestart
    Q_INVOKABLE void install();
    Q_INVOKABLE void dismiss();

    // <0, 0 o >0: 0.8.1 < 0.8.2; 0.9.0-beta < 0.9.0
    static int compareVersions(const QString &a, const QString &b);

signals:
    void changed();
    void progressChanged();
    // Todo listo: Mitis debe cerrarse ya (lo que sigue espera a que termine)
    void readyToRestart();

private:
    explicit Updater(QObject *parent = nullptr);
    QString server() const;
    // Clave del paquete de este sistema en version.txt ("" si no se actualiza desde Mitis)
    QString packageKey() const;
    // Lo que se reemplaza: Mitis.app (macOS) o el .AppImage (Linux)
    QString target() const;
    void downloadPackage();
    void preparePackage(const QString &file);
    void launchReplacer(const QString &replacement, const QString &folder);
    void fail(const QString &message);
    void removeLeftovers();

    static constexpr int FirstCheckDelay = 15 * 1000;
    static constexpr int CheckInterval = 6 * 60 * 60 * 1000;

    QNetworkAccessManager *m_network = nullptr;
    QTimer m_timer;
    QHash<QString, QString> m_manifest; // version.txt
    QString m_available;
    QString m_error;
    bool m_checking = false;
    bool m_installing = false;
    bool m_dismissed = false;
    double m_progress = -1;
};
