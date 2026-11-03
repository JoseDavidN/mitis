#include "passwords.h"

#include "monocypher.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlEngine>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <algorithm>
#include <cstdlib>

namespace {

constexpr int FormatVersion = 1;
// Argon2id: 32 MB (bloques de 1 KB) y 3 pasadas, menos de un segundo en un
// equipo normal. Van en el archivo: se pueden subir sin romper los anteriores
constexpr int KdfBlocks = 32768;
constexpr int KdfPasses = 3;
constexpr int SaltSize = 16;
constexpr int KeySize = 32;
constexpr int NonceSize = 24;
constexpr int MacSize = 16;
// Lo que se copia como contraseña se borra del portapapeles a los 30 s
constexpr int ClipboardClearMs = 30000;

const QByteArray AssociatedData = QByteArrayLiteral("mitis-contrasenas-1");

QByteArray randomBytes(int size)
{
    QByteArray bytes(size, Qt::Uninitialized);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32 *>(bytes.data()), size / 4);
    return bytes;
}

void wipe(QByteArray &bytes)
{
    if (!bytes.isEmpty())
        crypto_wipe(bytes.data(), size_t(bytes.size()));
    bytes.clear();
}

// Separa un CSV (RFC 4180: comillas, comas y saltos de línea dentro de un campo)
QList<QStringList> parseCsv(const QString &text)
{
    QList<QStringList> rows;
    QStringList row;
    QString field;
    bool quoted = false;
    bool any = false;
    for (qsizetype i = 0; i < text.size(); ++i) {
        const QChar c = text.at(i);
        if (quoted) {
            if (c == u'"') {
                if (i + 1 < text.size() && text.at(i + 1) == u'"') {
                    field += u'"';
                    ++i;
                } else {
                    quoted = false;
                }
            } else {
                field += c;
            }
            continue;
        }
        if (c == u'"') {
            quoted = true;
            any = true;
        } else if (c == u',') {
            row << field;
            field.clear();
            any = true;
        } else if (c == u'\n' || c == u'\r') {
            if (c == u'\r' && i + 1 < text.size() && text.at(i + 1) == u'\n')
                ++i;
            if (any || !field.isEmpty()) {
                row << field;
                rows << row;
            }
            row.clear();
            field.clear();
            any = false;
        } else {
            field += c;
            any = true;
        }
    }
    if (any || !field.isEmpty()) {
        row << field;
        rows << row;
    }
    return rows;
}

QString csvField(const QString &value)
{
    if (!value.contains(u',') && !value.contains(u'"') && !value.contains(u'\n') && !value.contains(u'\r'))
        return value;
    QString quoted = value;
    quoted.replace(u'"', QStringLiteral("\"\""));
    return u'"' + quoted + u'"';
}

// Columna de `header` con alguno de esos nombres (sin mayúsculas), o -1
int column(const QStringList &header, std::initializer_list<const char *> names)
{
    for (const char *name : names) {
        const int index = header.indexOf(QLatin1String(name));
        if (index >= 0)
            return index;
    }
    return -1;
}

} // namespace

Passwords *Passwords::instance()
{
    static Passwords *passwords = new Passwords(QCoreApplication::instance());
    return passwords;
}

Passwords *Passwords::create(QQmlEngine *, QJSEngine *)
{
    Passwords *passwords = instance();
    // Es de la app, no del motor QML (en --dev hay uno nuevo en cada recarga)
    QQmlEngine::setObjectOwnership(passwords, QQmlEngine::CppOwnership);
    return passwords;
}

Passwords::Passwords(QObject *parent)
    : QObject(parent)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    m_path = dir + QStringLiteral("/contrasenas.mitis");
    readHeader();
}

Passwords::~Passwords()
{
    if (m_thread) {
        m_thread->wait();
        delete m_thread;
    }
    wipe(m_key);
}

// Solo la cabecera (usuario, sal): lo cifrado se lee al desbloquear
void Passwords::readHeader()
{
    m_header.clear();
    m_user.clear();
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject json = QJsonDocument::fromJson(file.readAll()).object();
    if (json.value(u"version").toInt() < 1 || json.value(u"data").toString().isEmpty())
        return;
    m_header = json.toVariantMap();
    m_user = json.value(u"user").toString();
}

QVariantList Passwords::items() const
{
    QList<const Entry *> sorted;
    for (const Entry &entry : m_entries)
        sorted << &entry;
    std::sort(sorted.begin(), sorted.end(), [](const Entry *a, const Entry *b) {
        const int order = QString::localeAwareCompare(a->title.toLower(), b->title.toLower());
        return order != 0 ? order < 0 : a->username < b->username;
    });
    QVariantList list;
    for (const Entry *entry : sorted) {
        list << QVariantMap{
            { QStringLiteral("id"), entry->id },
            { QStringLiteral("title"), entry->title },
            { QStringLiteral("url"), entry->url },
            { QStringLiteral("host"), entry->host },
            { QStringLiteral("username"), entry->username },
            { QStringLiteral("updated"), entry->updated },
        };
    }
    return list;
}

void Passwords::derive(const QString &password, const QByteArray &salt,
                       std::function<void(QByteArray)> done)
{
    if (m_thread)
        return;
    const int blocks = m_header.value(QStringLiteral("blocks"), KdfBlocks).toInt();
    const int passes = m_header.value(QStringLiteral("passes"), KdfPasses).toInt();
    auto *result = new QByteArray;
    m_thread = QThread::create([pass = password.toUtf8(), salt, blocks, passes, result]() mutable {
        void *work = std::malloc(size_t(blocks) * 1024);
        if (work) {
            QByteArray key(KeySize, Qt::Uninitialized);
            crypto_argon2_config config{ CRYPTO_ARGON2_ID, uint32_t(blocks), uint32_t(passes), 1 };
            crypto_argon2_inputs inputs{ reinterpret_cast<const uint8_t *>(pass.constData()),
                                         reinterpret_cast<const uint8_t *>(salt.constData()),
                                         uint32_t(pass.size()), uint32_t(salt.size()) };
            crypto_argon2(reinterpret_cast<uint8_t *>(key.data()), KeySize, work, config, inputs,
                          crypto_argon2_no_extras);
            crypto_wipe(work, size_t(blocks) * 1024);
            std::free(work);
            *result = key;
            wipe(key);
        }
        wipe(pass);
    });
    connect(m_thread, &QThread::finished, this, [this, result, done] {
        m_thread->deleteLater();
        m_thread = nullptr;
        QByteArray key = *result;
        wipe(*result);
        delete result;
        emit busyChanged();
        done(key);
        wipe(key);
    });
    m_thread->start();
    emit busyChanged();
}

void Passwords::createAccount(const QString &user, const QString &password)
{
    if (m_thread || password.isEmpty())
        return;
    const QByteArray salt = randomBytes(SaltSize);
    // Las de antes de crearla (por ejemplo, la que se iba a guardar) se conservan
    derive(password, salt, [this, user, salt](QByteArray key) {
        if (key.isEmpty()) {
            emit unlockFinished(false);
            return;
        }
        m_header = {
            { QStringLiteral("version"), FormatVersion },
            { QStringLiteral("user"), user.trimmed() },
            { QStringLiteral("salt"), QString::fromLatin1(salt.toBase64()) },
            { QStringLiteral("blocks"), KdfBlocks },
            { QStringLiteral("passes"), KdfPasses },
        };
        m_user = user.trimmed();
        m_key = key;
        m_entries.clear();
        const bool ok = write();
        emit stateChanged();
        emit itemsChanged();
        emit unlockFinished(ok);
    });
}

void Passwords::unlock(const QString &password)
{
    if (m_thread || !exists())
        return;
    const QByteArray salt = QByteArray::fromBase64(m_header.value(QStringLiteral("salt")).toByteArray());
    derive(password, salt, [this](QByteArray key) {
        const bool ok = !key.isEmpty() && decrypt(key);
        if (ok) {
            m_key = key;
            emit stateChanged();
            emit itemsChanged();
        }
        emit unlockFinished(ok);
    });
}

void Passwords::lock()
{
    if (!unlocked())
        return;
    wipe(m_key);
    m_entries.clear();
    emit stateChanged();
    emit itemsChanged();
}

void Passwords::changeMaster(const QString &current, const QString &password)
{
    if (m_thread || !unlocked() || password.isEmpty())
        return;
    const QByteArray salt = QByteArray::fromBase64(m_header.value(QStringLiteral("salt")).toByteArray());
    derive(current, salt, [this, password](QByteArray key) {
        if (key.isEmpty() || crypto_verify32(reinterpret_cast<const uint8_t *>(key.constData()),
                                             reinterpret_cast<const uint8_t *>(m_key.constData())) != 0) {
            emit changeFinished(false);
            return;
        }
        // Sal nueva: la clave anterior deja de servir
        const QByteArray salt = randomBytes(SaltSize);
        derive(password, salt, [this, salt](QByteArray key) {
            if (key.isEmpty()) {
                emit changeFinished(false);
                return;
            }
            m_header[QStringLiteral("salt")] = QString::fromLatin1(salt.toBase64());
            m_header[QStringLiteral("blocks")] = KdfBlocks;
            m_header[QStringLiteral("passes")] = KdfPasses;
            wipe(m_key);
            m_key = key;
            emit changeFinished(write());
        });
    });
}

void Passwords::reset()
{
    if (m_thread)
        return;
    QFile::remove(m_path);
    wipe(m_key);
    m_entries.clear();
    m_header.clear();
    m_user.clear();
    emit stateChanged();
    emit itemsChanged();
}

bool Passwords::decrypt(const QByteArray &key)
{
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QJsonObject json = QJsonDocument::fromJson(file.readAll()).object();
    const QByteArray nonce = QByteArray::fromBase64(json.value(u"nonce").toString().toLatin1());
    const QByteArray mac = QByteArray::fromBase64(json.value(u"mac").toString().toLatin1());
    const QByteArray cipher = QByteArray::fromBase64(json.value(u"data").toString().toLatin1());
    if (nonce.size() != NonceSize || mac.size() != MacSize)
        return false;
    QByteArray plain(cipher.size(), Qt::Uninitialized);
    // El usuario de la cuenta va como dato asociado: cambiarlo en el archivo
    // lo invalida
    const QByteArray ad = AssociatedData + json.value(u"user").toString().toUtf8();
    if (crypto_aead_unlock(reinterpret_cast<uint8_t *>(plain.data()),
                           reinterpret_cast<const uint8_t *>(mac.constData()),
                           reinterpret_cast<const uint8_t *>(key.constData()),
                           reinterpret_cast<const uint8_t *>(nonce.constData()),
                           reinterpret_cast<const uint8_t *>(ad.constData()), size_t(ad.size()),
                           reinterpret_cast<const uint8_t *>(cipher.constData()), size_t(cipher.size())) != 0) {
        return false;
    }
    const QJsonArray entries = QJsonDocument::fromJson(plain).object().value(u"entries").toArray();
    wipe(plain);
    m_entries.clear();
    for (const QJsonValue &value : entries) {
        const QJsonObject object = value.toObject();
        Entry entry;
        entry.id = object.value(u"id").toString();
        entry.title = object.value(u"title").toString();
        entry.url = object.value(u"url").toString();
        entry.host = object.value(u"host").toString();
        entry.username = object.value(u"username").toString();
        entry.password = object.value(u"password").toString();
        entry.notes = object.value(u"notes").toString();
        entry.created = object.value(u"created").toInteger();
        entry.updated = object.value(u"updated").toInteger();
        m_entries << entry;
    }
    return true;
}

bool Passwords::write()
{
    if (!unlocked())
        return false;
    QJsonArray entries;
    for (const Entry &entry : std::as_const(m_entries)) {
        entries.append(QJsonObject{
            { QStringLiteral("id"), entry.id },
            { QStringLiteral("title"), entry.title },
            { QStringLiteral("url"), entry.url },
            { QStringLiteral("host"), entry.host },
            { QStringLiteral("username"), entry.username },
            { QStringLiteral("password"), entry.password },
            { QStringLiteral("notes"), entry.notes },
            { QStringLiteral("created"), entry.created },
            { QStringLiteral("updated"), entry.updated },
        });
    }
    QByteArray plain = QJsonDocument(QJsonObject{ { QStringLiteral("entries"), entries } })
                           .toJson(QJsonDocument::Compact);
    // Un nonce nuevo en cada escritura (24 bytes al azar: no se repiten)
    const QByteArray nonce = randomBytes(NonceSize);
    QByteArray mac(MacSize, Qt::Uninitialized);
    QByteArray cipher(plain.size(), Qt::Uninitialized);
    const QByteArray ad = AssociatedData + m_user.toUtf8();
    crypto_aead_lock(reinterpret_cast<uint8_t *>(cipher.data()), reinterpret_cast<uint8_t *>(mac.data()),
                     reinterpret_cast<const uint8_t *>(m_key.constData()),
                     reinterpret_cast<const uint8_t *>(nonce.constData()),
                     reinterpret_cast<const uint8_t *>(ad.constData()), size_t(ad.size()),
                     reinterpret_cast<const uint8_t *>(plain.constData()), size_t(plain.size()));
    wipe(plain);

    QJsonObject json = QJsonObject::fromVariantMap(m_header);
    json[QStringLiteral("nonce")] = QString::fromLatin1(nonce.toBase64());
    json[QStringLiteral("mac")] = QString::fromLatin1(mac.toBase64());
    json[QStringLiteral("data")] = QString::fromLatin1(cipher.toBase64());

    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    // Solo el usuario puede leerlo (en Windows no cambia nada)
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    file.write(QJsonDocument(json).toJson(QJsonDocument::Indented));
    if (!file.commit())
        return false;
    m_header = json.toVariantMap();
    return true;
}

int Passwords::indexOf(const QString &id) const
{
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).id == id)
            return i;
    }
    return -1;
}

int Passwords::indexOf(const QString &host, const QString &username) const
{
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).host == host && m_entries.at(i).username == username)
            return i;
    }
    return -1;
}

// Host sin «www.», el que se compara al autocompletar
QString Passwords::hostOf(const QUrl &url)
{
    QString host = url.host().toLower();
    if (host.startsWith(QLatin1String("www.")))
        host = host.mid(4);
    return host;
}

// Dirección escrita a mano («github.com») → https://github.com
QString Passwords::normalizedUrl(const QString &url)
{
    const QString trimmed = url.trimmed();
    if (trimmed.isEmpty() || trimmed.contains(QLatin1String("://")))
        return trimmed;
    return QStringLiteral("https://") + trimmed;
}

QVariantMap Passwords::entry(const QString &id) const
{
    const int index = indexOf(id);
    if (index < 0)
        return {};
    const Entry &entry = m_entries.at(index);
    return {
        { QStringLiteral("id"), entry.id },
        { QStringLiteral("title"), entry.title },
        { QStringLiteral("url"), entry.url },
        { QStringLiteral("host"), entry.host },
        { QStringLiteral("username"), entry.username },
        { QStringLiteral("password"), entry.password },
        { QStringLiteral("notes"), entry.notes },
    };
}

QString Passwords::save(const QString &id, const QString &url, const QString &username,
                        const QString &password, const QString &notes)
{
    if (!unlocked())
        return {};
    const QString address = normalizedUrl(url);
    const QUrl parsed(address);
    const QString host = hostOf(parsed);
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    int index = id.isEmpty() ? indexOf(host, username) : indexOf(id);
    if (index < 0) {
        Entry entry;
        entry.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        entry.created = now;
        m_entries << entry;
        index = int(m_entries.size()) - 1;
    }
    Entry &entry = m_entries[index];
    // Se guarda el origen (sin ruta ni parámetros: pueden llevar datos de la sesión)
    entry.url = parsed.isValid() && !host.isEmpty()
        ? parsed.adjusted(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::RemoveUserInfo).toString()
        : address;
    entry.host = host.isEmpty() ? address : host;
    entry.title = entry.host;
    entry.username = username;
    entry.password = password;
    entry.notes = notes;
    entry.updated = now;
    write();
    emit itemsChanged();
    return entry.id;
}

void Passwords::remove(const QString &id)
{
    const int index = indexOf(id);
    if (index < 0)
        return;
    m_entries.removeAt(index);
    write();
    emit itemsChanged();
}

QVariantList Passwords::matches(const QUrl &url, const QString &site) const
{
    const QString host = hostOf(url);
    if (host.isEmpty())
        return {};
    QString siteHost = site.toLower();
    if (siteHost.startsWith(QLatin1String("www.")))
        siteHost = siteHost.mid(4);
    QList<const Entry *> exact, related;
    for (const Entry &entry : m_entries) {
        if (entry.host == host)
            exact << &entry;
        else if (!siteHost.isEmpty() && (entry.host == siteHost || entry.host.endsWith(u'.' + siteHost)))
            related << &entry;
    }
    const auto newest = [](const Entry *a, const Entry *b) { return a->updated > b->updated; };
    std::sort(exact.begin(), exact.end(), newest);
    std::sort(related.begin(), related.end(), newest);
    QVariantList list;
    for (const Entry *entry : exact + related) {
        list << QVariantMap{
            { QStringLiteral("id"), entry->id },
            { QStringLiteral("username"), entry->username },
            { QStringLiteral("title"), entry->title },
        };
    }
    return list;
}

QString Passwords::stateFor(const QUrl &url, const QString &username, const QString &password) const
{
    const int index = indexOf(hostOf(url), username);
    if (index < 0)
        return QStringLiteral("new");
    return m_entries.at(index).password == password ? QStringLiteral("same") : QStringLiteral("update");
}

QString Passwords::generate(int length)
{
    length = std::clamp(length, 8, 16);
    // Sin los que se confunden al leerlos (0/O, 1/l/I) y con símbolos que
    // aceptan casi todos los sitios
    static const QString groups[] = {
        QStringLiteral("abcdefghijkmnopqrstuvwxyz"),
        QStringLiteral("ABCDEFGHJKLMNPQRSTUVWXYZ"),
        QStringLiteral("23456789"),
        QStringLiteral("!@#$%&*-_+=?"),
    };
    QRandomGenerator *random = QRandomGenerator::system();
    const QString all = groups[0] + groups[1] + groups[2] + groups[3];
    QString password;
    // Uno de cada grupo, el resto de cualquiera, y se baraja
    for (const QString &group : groups)
        password += group.at(random->bounded(int(group.size())));
    while (password.size() < length)
        password += all.at(random->bounded(int(all.size())));
    for (qsizetype i = password.size() - 1; i > 0; --i)
        std::swap(password[i], password[random->bounded(int(i + 1))]);
    return password;
}

void Passwords::copy(const QString &text, bool secret)
{
    QGuiApplication::clipboard()->setText(text);
    if (!secret)
        return;
    m_copied = text;
    QTimer::singleShot(ClipboardClearMs, this, [this, text] {
        QClipboard *clipboard = QGuiApplication::clipboard();
        if (m_copied == text && clipboard->text() == text)
            clipboard->clear();
        if (m_copied == text)
            m_copied.clear();
    });
}

int Passwords::importCsv(const QUrl &file)
{
    if (!unlocked())
        return -1;
    QFile source(file.isLocalFile() ? file.toLocalFile() : file.toString());
    if (!source.open(QIODevice::ReadOnly))
        return -1;
    QString text = QString::fromUtf8(source.readAll());
    if (text.startsWith(QChar(0xFEFF)))
        text.remove(0, 1);
    const QList<QStringList> rows = parseCsv(text);
    if (rows.size() < 1)
        return -1;
    QStringList header;
    for (const QString &name : rows.first())
        header << name.trimmed().toLower();
    // Chrome/Edge: name,url,username,password,note · Firefox: url,username,password,…
    // Bitwarden: …,name,notes,…,login_uri,login_username,login_password · 1Password: Title,Url,Username,Password,Notes
    // Proton Pass: type,name,url,email,username,password,note,…
    const int url = column(header, { "url", "login_uri", "website", "web site", "uri", "login url" });
    const int username = column(header, { "username", "login_username", "login", "user", "email", "user name" });
    const int password = column(header, { "password", "login_password" });
    const int notes = column(header, { "note", "notes", "extra", "comments" });
    const int type = column(header, { "type" });
    // Proton Pass trae usuario y correo aparte (a veces solo uno)
    const int email = column(header, { "email" });
    if (url < 0 || password < 0)
        return -1;

    int count = 0;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (qsizetype r = 1; r < rows.size(); ++r) {
        const QStringList &row = rows.at(r);
        const auto at = [&row](int index) { return index >= 0 && index < row.size() ? row.at(index) : QString(); };
        // Bitwarden también exporta notas y tarjetas: solo los inicios de sesión
        if (type >= 0 && !at(type).isEmpty() && at(type).toLower() != QLatin1String("login"))
            continue;
        const QString address = normalizedUrl(at(url));
        const QString secret = at(password);
        if (address.isEmpty() || secret.isEmpty())
            continue;
        const QUrl parsed(address);
        const QString host = hostOf(parsed);
        if (host.isEmpty())
            continue;
        const QString user = at(username).isEmpty() ? at(email) : at(username);
        int index = indexOf(host, user);
        if (index >= 0 && m_entries.at(index).password == secret)
            continue;
        if (index < 0) {
            Entry entry;
            entry.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            entry.created = now;
            m_entries << entry;
            index = int(m_entries.size()) - 1;
        }
        Entry &entry = m_entries[index];
        entry.url = parsed.adjusted(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::RemoveUserInfo).toString();
        entry.host = host;
        entry.title = host;
        entry.username = user;
        entry.password = secret;
        if (!at(notes).isEmpty())
            entry.notes = at(notes);
        entry.updated = now;
        ++count;
    }
    if (count > 0) {
        write();
        emit itemsChanged();
    }
    return count;
}

void Passwords::exportCsv(const QUrl &file, const QString &password)
{
    if (m_thread || !unlocked())
        return;
    QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    if (!path.endsWith(QLatin1String(".csv"), Qt::CaseInsensitive))
        path += QStringLiteral(".csv");
    const QByteArray salt = QByteArray::fromBase64(m_header.value(QStringLiteral("salt")).toByteArray());
    derive(password, salt, [this, path](QByteArray key) {
        if (key.isEmpty() || !unlocked()
            || crypto_verify32(reinterpret_cast<const uint8_t *>(key.constData()),
                               reinterpret_cast<const uint8_t *>(m_key.constData())) != 0) {
            emit exportFinished(QStringLiteral("La contraseña no es correcta."));
            return;
        }
        QString text = QStringLiteral("name,url,username,password,note\n");
        for (const Entry &entry : std::as_const(m_entries)) {
            text += QStringList{ csvField(entry.title), csvField(entry.url), csvField(entry.username),
                                 csvField(entry.password), csvField(entry.notes) }
                        .join(u',')
                    + u'\n';
        }
        QSaveFile out(path);
        if (!out.open(QIODevice::WriteOnly)) {
            emit exportFinished(QStringLiteral("No se pudo escribir el archivo."));
            return;
        }
        out.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        QByteArray bytes = text.toUtf8();
        out.write(bytes);
        wipe(bytes);
        emit exportFinished(out.commit() ? QString() : QStringLiteral("No se pudo escribir el archivo."));
    });
}
