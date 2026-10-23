#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Informes de cierres inesperados. Todo queda en el equipo (carpeta de datos,
// `informes/`); nada se envía.
//
// - Registro de la sesión (`sesion.log`): versión, sistema y los mensajes de
//   Qt y de la interfaz (qDebug, console.log…). Al cerrar bien, termina con
//   una línea de cierre normal.
// - Caída: un manejador de señales (Linux, macOS) o de excepciones (Windows)
//   añade al registro el motivo y la pila (módulo + desplazamiento: con los
//   símbolos de esa compilación, PDB o dSYM, se ve la función). En Windows,
//   además, un minidump (`sesion.dmp`).
// - Al arrancar, un registro sin la línea de cierre normal es un cierre
//   inesperado (caída, cuelgue que se cerró a la fuerza, falta de memoria…):
//   pasa a `cierre-AAAAMMDD-HHMMSS.txt` (y `.dmp`) y la interfaz avisa. Se
//   guardan los últimos `MaxReports`.
//
// En QML es el singleton `CrashReports` del módulo Mitis.Core.
class CrashReporter : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(CrashReports)
    QML_SINGLETON

    // Informe del cierre inesperado de la sesión anterior, sin ver aún
    // (ruta del .txt; vacío si no hay)
    Q_PROPERTY(QString pending READ pending NOTIFY changed)
    // Informes guardados, del más reciente al más antiguo: {path, date, kind}
    // (kind: "caida" con pila o "cierre" sin ella)
    Q_PROPERTY(QVariantList reports READ reports NOTIFY changed)
    Q_PROPERTY(QString folder READ folder CONSTANT)

public:
    static CrashReporter *instance();
    static CrashReporter *create(QQmlEngine *, QJSEngine *);

    // Antes de crear la interfaz (y después de saber que este proceso se
    // queda: el que pasa sus enlaces a otro Mitis no debe tocar el registro)
    void install();
    // Al salir sin fallos: marca la sesión como cerrada bien
    void finish();

    QString pending() const { return m_pending; }
    QVariantList reports() const;
    QString folder() const { return m_folder; }

    Q_INVOKABLE QString read(const QString &path) const;
    // Copia el informe al portapapeles (para mandarlo o pegarlo)
    Q_INVOKABLE void copy(const QString &path) const;
    Q_INVOKABLE void openFolder() const;
    // El aviso ya se vio
    Q_INVOKABLE void dismiss();
    Q_INVOKABLE void clear();

signals:
    void changed();

private:
    explicit CrashReporter(QObject *parent = nullptr);
    void collectPrevious();
    void prune();

    static constexpr int MaxReports = 10;
    QString m_folder;
    QString m_pending;
};
