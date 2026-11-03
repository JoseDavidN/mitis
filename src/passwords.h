#pragma once

#include <QByteArray>
#include <QList>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <functional>

class QQmlEngine;
class QJSEngine;
class QThread;

// Gestor de contraseñas: una cuenta (usuario y contraseña maestra) protege las
// credenciales guardadas, cifradas en un solo archivo (contrasenas.mitis, en
// la carpeta de datos). La contraseña maestra no se guarda: de ella sale la
// clave (Argon2id, en un hilo: tarda un momento y usa 32 MB que se sueltan al
// terminar) y con la clave se cifra todo (XChaCha20-Poly1305), sitios y
// usuarios incluidos. Ambos de Monocypher (third_party/monocypher).
//
// Bloqueado (al abrir Mitis, o al pulsar «Bloquear») no hay nada descifrado en
// memoria; desbloqueado, las credenciales están en memoria hasta bloquearlo o
// cerrar Mitis. Cada cambio vuelve a escribir el archivo entero (son pocas).
//
// En QML es el singleton `Passwords` del módulo Mitis.Core; hay uno para toda
// la app (también entre recargas de --dev).
class Passwords : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Hay una cuenta creada (aunque esté bloqueada)
    Q_PROPERTY(bool exists READ exists NOTIFY stateChanged)
    Q_PROPERTY(bool unlocked READ unlocked NOTIFY stateChanged)
    // Calculando la clave (crear, desbloquear, cambiar la maestra, exportar)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // Nombre de usuario de la cuenta (no es secreto: se ve al desbloquear)
    Q_PROPERTY(QString user READ user NOTIFY stateChanged)
    // Las guardadas, sin la contraseña, por sitio: [{ id, title, url, host, username, updated }]
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    static Passwords *instance();
    static Passwords *create(QQmlEngine *, QJSEngine *);
    ~Passwords() override;

    bool exists() const { return !m_header.isEmpty(); }
    bool unlocked() const { return !m_key.isEmpty(); }
    bool busy() const { return m_thread != nullptr; }
    QString user() const { return m_user; }
    QVariantList items() const;

    // Crea la cuenta (sustituye a la que hubiera); termina con unlockFinished
    Q_INVOKABLE void createAccount(const QString &user, const QString &password);
    // Termina con unlockFinished(ok)
    Q_INVOKABLE void unlock(const QString &password);
    Q_INVOKABLE void lock();
    // Termina con changeFinished(ok); false si `current` no es la maestra
    Q_INVOKABLE void changeMaster(const QString &current, const QString &password);
    // Borra la cuenta y todo lo guardado (contraseña maestra olvidada)
    Q_INVOKABLE void reset();

    // Una entera, con contraseña y notas: { id, title, url, host, username, password, notes }
    Q_INVOKABLE QVariantMap entry(const QString &id) const;
    // Guarda una nueva (id vacío) o cambia la de `id`. Si es nueva y ya hay
    // una del mismo sitio y usuario, se actualiza esa. Devuelve su id
    Q_INVOKABLE QString save(const QString &id, const QString &url, const QString &username,
                             const QString &password, const QString &notes = QString());
    Q_INVOKABLE void remove(const QString &id);
    // Las de una página para autocompletar: las del mismo host primero y luego
    // las de su sitio (`site`, BrowserProfile.siteOf). [{ id, username, title }]
    Q_INVOKABLE QVariantList matches(const QUrl &url, const QString &site) const;
    // Qué pasa si se guarda esta: "new", "update" (otra contraseña) o "same"
    Q_INVOKABLE QString stateFor(const QUrl &url, const QString &username, const QString &password) const;

    // Contraseña segura al azar (generador del sistema), de 8 a 16 caracteres,
    // con minúsculas, mayúsculas, números y símbolos
    Q_INVOKABLE static QString generate(int length);
    // Copia al portapapeles; si es una contraseña, se borra a los 30 s (si
    // sigue siendo lo copiado)
    Q_INVOKABLE void copy(const QString &text, bool secret);

    // Importa un CSV de Chrome, Edge, Firefox, Bitwarden, 1Password… (lee las
    // columnas por su nombre). Devuelve cuántas se añadieron o cambiaron; -1
    // si no se pudo leer o no es una lista de contraseñas
    Q_INVOKABLE int importCsv(const QUrl &file);
    // Exporta en el CSV de Chrome (name,url,username,password,note), el que
    // aceptan todos. Pide otra vez la maestra; termina con exportFinished
    Q_INVOKABLE void exportCsv(const QUrl &file, const QString &password);

signals:
    void stateChanged();
    void busyChanged();
    void itemsChanged();
    void unlockFinished(bool ok);
    void changeFinished(bool ok);
    // `error` vacío si se exportó
    void exportFinished(const QString &error);

private:
    struct Entry {
        QString id, title, url, host, username, password, notes;
        qint64 created = 0, updated = 0;
    };

    explicit Passwords(QObject *parent = nullptr);
    void readHeader();
    bool decrypt(const QByteArray &key);
    bool write();
    // Calcula la clave en un hilo y llama a `done` en este (con la clave o vacía)
    void derive(const QString &password, const QByteArray &salt,
                std::function<void(QByteArray)> done);
    int indexOf(const QString &id) const;
    int indexOf(const QString &host, const QString &username) const;
    static QString hostOf(const QUrl &url);
    static QString normalizedUrl(const QString &url);

    QString m_path;
    QString m_user;
    // Cabecera del archivo (cuenta, sal); vacía si no hay cuenta
    QVariantMap m_header;
    QByteArray m_key;
    QList<Entry> m_entries;
    QThread *m_thread = nullptr;
    QString m_copied;
};
