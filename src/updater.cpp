#include "updater.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QSettings>
#include <QSharedPointer>
#include <QTemporaryDir>
#include <QUrl>

namespace {
// Espera a que Mitis termine, cambia la versión instalada por la nueva y la
// abre. Si algo falla, deja la anterior. Argumentos: pid, lo instalado
// (Mitis.app o el .AppImage), lo nuevo y la carpeta temporal (se borra)
const char ReplacerScript[] = R"sh(#!/bin/sh
pid="$1"; destino="$2"; nuevo="$3"; carpeta="$4"
i=0
while kill -0 "$pid" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -gt 240 ]; then rm -rf "$carpeta"; exit 1; fi
    sleep 0.5
done
if mv "$destino" "$destino.anterior" && mv "$nuevo" "$destino"; then
    rm -rf "$destino.anterior"
elif [ -e "$destino.anterior" ] && [ ! -e "$destino" ]; then
    mv "$destino.anterior" "$destino"
fi
rm -rf "$carpeta"
if [ "$(uname)" = Darwin ]; then
    xattr -dr com.apple.quarantine "$destino" 2>/dev/null
    open "$destino"
else
    nohup "$destino" >/dev/null 2>&1 &
fi
)sh";

const QString LastVersionKey = QStringLiteral("Updates/lastVersion");
const QString DefaultNotesTitle = QStringLiteral("Mitis se ha actualizado");
}

Updater::Updater(QObject *parent)
    : QObject(parent)
{
    // Versión del arranque anterior: si es más antigua, Mitis se ha
    // actualizado (y enseña sus novedades)
    QSettings settings;
    m_previousVersion = settings.value(LastVersionKey).toString();
    settings.setValue(LastVersionKey, QCoreApplication::applicationVersion());

    // La primera, al poco de arrancar (sin estorbar al inicio); luego, cada tanto
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        removeLeftovers();
        check();
        m_timer.start(CheckInterval);
    });
    m_timer.start(FirstCheckDelay);
}

Updater *Updater::instance()
{
    // Hijo de la aplicación: se destruye con ella, no después
    static Updater *updater = new Updater(QCoreApplication::instance());
    return updater;
}

Updater *Updater::create(QQmlEngine *, QJSEngine *)
{
    Updater *updater = instance();
    // Vive toda la app: el motor QML (uno por recarga en --dev) no lo destruye
    QQmlEngine::setObjectOwnership(updater, QQmlEngine::CppOwnership);
    return updater;
}

// Carpetas temporales de actualizaciones anteriores: en Windows queda el
// instalador (no puede borrarse mientras se ejecuta); en macOS y Linux, si
// algo falló a medias. A los 15 s de arrancar, el instalador ya terminó
void Updater::removeLeftovers()
{
    if (m_installing)
        return;
    const QFileInfoList folders = QDir::temp().entryInfoList({QStringLiteral("mitis-actualizacion-*")},
                                                              QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &folder : folders)
        QDir(folder.absoluteFilePath()).removeRecursively();
}

QString Updater::server() const
{
    // MITIS_SERVIDOR en el entorno sustituye al de la compilación (pruebas)
    return qEnvironmentVariable("MITIS_SERVIDOR", QStringLiteral(MITIS_SERVIDOR));
}

QString Updater::packageKey() const
{
#if defined(Q_OS_WIN)
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#elif defined(Q_OS_LINUX)
    return qEnvironmentVariableIsEmpty("APPIMAGE") ? QString() : QStringLiteral("linux");
#else
    return {};
#endif
}

QString Updater::target() const
{
#if defined(Q_OS_MACOS)
    // .../Mitis.app/Contents/MacOS
    const QString app = QDir(QCoreApplication::applicationDirPath() + QStringLiteral("/../..")).canonicalPath();
    return app.endsWith(QLatin1String(".app")) ? app : QString();
#else
    return qEnvironmentVariable("APPIMAGE");
#endif
}

bool Updater::canInstall() const
{
#ifdef Q_OS_WIN
    // El instalador se instala para el usuario: no hace falta nada más
    return m_manifest.contains(packageKey());
#else
    const QString key = packageKey();
    const QString path = target();
    if (key.isEmpty() || path.isEmpty() || !m_manifest.contains(key))
        return false;
    // Se cambia de nombre dentro de su carpeta: hay que poder escribir en ella
    const QFileInfo info(path);
    return info.exists() && QFileInfo(info.absolutePath()).isWritable();
#endif
}

void Updater::check()
{
    if (m_checking || m_installing)
        return;
    if (!m_network)
        m_network = new QNetworkAccessManager(this);
    m_checking = true;
    emit changed();

    QNetworkRequest request(QUrl(server() + QStringLiteral("/version.txt")));
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setTransferTimeout(15000);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_checking = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_error = QStringLiteral("No se pudo conectar con el servidor de Mitis.");
            qInfo("[Mitis] Actualizaciones: %s", qPrintable(reply->errorString()));
            emit changed();
            return;
        }
        // version.txt: una clave por línea («version=0.8.2-beta»)
        m_manifest.clear();
        const QStringList lines = QString::fromUtf8(reply->read(64 * 1024)).split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const qsizetype equals = line.indexOf(QLatin1Char('='));
            if (equals > 0)
                m_manifest.insert(line.left(equals).trimmed(), line.mid(equals + 1).trimmed());
        }
        const QString version = m_manifest.value(QStringLiteral("version"));
        m_error = version.isEmpty() ? QStringLiteral("El servidor de Mitis respondió algo inesperado.") : QString();
        const QString available =
            compareVersions(version, QCoreApplication::applicationVersion()) > 0 ? version : QString();
        if (available != m_available) {
            m_available = available;
            m_dismissed = false;
            if (!available.isEmpty())
                qInfo("[Mitis] Hay una versión nueva: %s", qPrintable(available));
        }
        emit changed();
    });
}

void Updater::install()
{
    if (!canInstall() || m_available.isEmpty() || m_installing)
        return;
    qInfo("[Mitis] Actualizando a %s", qPrintable(m_available));
    downloadPackage();
}

// El paquete de este sistema a una carpeta temporal, comprobando su SHA-256
void Updater::downloadPackage()
{
    const QString key = packageKey();
    const QString name = m_manifest.value(key);
    const QString expected = m_manifest.value(key + QStringLiteral("_sha256")).toLower();
    if (name.isEmpty() || name.contains(QLatin1Char('/')) || expected.size() != 64) {
        fail(QStringLiteral("El servidor de Mitis respondió algo inesperado."));
        return;
    }
    QTemporaryDir folder(QDir::temp().filePath(QStringLiteral("mitis-actualizacion-XXXXXX")));
    if (!folder.isValid()) {
        fail(QStringLiteral("No se pudo preparar la actualización (carpeta temporal)."));
        return;
    }
    // La borra el script al terminar (o aquí, si algo sale mal)
    folder.setAutoRemove(false);
    const QString path = folder.filePath(name);
    auto file = QSharedPointer<QFile>::create(path);
    if (!file->open(QIODevice::WriteOnly)) {
        QDir(folder.path()).removeRecursively();
        fail(QStringLiteral("No se pudo preparar la actualización (carpeta temporal)."));
        return;
    }

    m_installing = true;
    m_progress = 0;
    m_error.clear();
    emit changed();
    emit progressChanged();

    QNetworkRequest request(QUrl(server() + QLatin1Char('/') + name));
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    // Sin datos durante un minuto: cortada
    request.setTransferTimeout(60000);
    QNetworkReply *reply = m_network->get(request);
    auto hash = QSharedPointer<QCryptographicHash>::create(QCryptographicHash::Sha256);
    connect(reply, &QNetworkReply::readyRead, this, [reply, file, hash] {
        const QByteArray data = reply->readAll();
        hash->addData(data);
        file->write(data);
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
        m_progress = total > 0 ? double(received) / double(total) : -1;
        emit progressChanged();
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, file, hash, expected, path, folder = folder.path()] {
        reply->deleteLater();
        const QByteArray rest = reply->readAll();
        hash->addData(rest);
        file->write(rest);
        const bool written = file->flush() && file->error() == QFileDevice::NoError;
        file->close();
        if (reply->error() != QNetworkReply::NoError || !written) {
            QDir(folder).removeRecursively();
            fail(QStringLiteral("Se cortó la descarga de la actualización. Vuelve a intentarlo."));
            return;
        }
        if (QString::fromLatin1(hash->result().toHex()) != expected) {
            QDir(folder).removeRecursively();
            fail(QStringLiteral("La actualización llegó dañada. Vuelve a intentarlo."));
            return;
        }
        preparePackage(path);
    });
}

void Updater::preparePackage(const QString &file)
{
    const QString folder = QFileInfo(file).absolutePath();
#if defined(Q_OS_WIN)
    // El instalador completo de la versión nueva: espera a que Mitis se
    // cierre, instala sin preguntar y lo vuelve a abrir. Se queda en la
    // carpeta temporal (está en marcha); la borra removeLeftovers()
    const bool started = QProcess::startDetached(
        file, {QStringLiteral("--actualizar"), QString::number(QCoreApplication::applicationPid())}, folder);
    if (!started) {
        QDir(folder).removeRecursively();
        fail(QStringLiteral("No se pudo abrir el instalador de Mitis."));
        return;
    }
    m_progress = 1;
    emit progressChanged();
    emit readyToRestart();
#elif defined(Q_OS_MACOS)
    // Mitis.app viene en un ZIP hecho con ditto (conserva enlaces, permisos y
    // la firma): se descomprime igual
    auto *ditto = new QProcess(this);
    connect(ditto, &QProcess::finished, this, [this, ditto, file, folder](int code, QProcess::ExitStatus status) {
        ditto->deleteLater();
        QFile::remove(file);
        const QString app = QDir(folder).filePath(QStringLiteral("Mitis.app"));
        if (status != QProcess::NormalExit || code != 0 || !QFileInfo(app).isDir()) {
            QDir(folder).removeRecursively();
            fail(QStringLiteral("No se pudo descomprimir la actualización."));
            return;
        }
        launchReplacer(app, folder);
    });
    ditto->start(QStringLiteral("/usr/bin/ditto"), {QStringLiteral("-x"), QStringLiteral("-k"), file, folder});
#else
    // El .AppImage se usa tal cual: solo hace falta que sea ejecutable
    QFile::setPermissions(file, QFile::permissions(file) | QFileDevice::ExeOwner | QFileDevice::ExeUser
                                    | QFileDevice::ExeGroup | QFileDevice::ExeOther);
    launchReplacer(file, folder);
#endif
}

void Updater::launchReplacer(const QString &replacement, const QString &folder)
{
    const QString script = QDir(folder).filePath(QStringLiteral("actualizar.sh"));
    QFile out(script);
    if (!out.open(QIODevice::WriteOnly) || out.write(ReplacerScript) < 0) {
        QDir(folder).removeRecursively();
        fail(QStringLiteral("No se pudo preparar la actualización."));
        return;
    }
    out.close();
    const bool started = QProcess::startDetached(
        QStringLiteral("/bin/sh"),
        {script, QString::number(QCoreApplication::applicationPid()), target(), replacement, folder},
        QDir::tempPath());
    if (!started) {
        QDir(folder).removeRecursively();
        fail(QStringLiteral("No se pudo preparar la actualización."));
        return;
    }
    m_progress = 1;
    emit progressChanged();
    emit readyToRestart();
}

void Updater::fail(const QString &message)
{
    qInfo("[Mitis] Actualización: %s", qPrintable(message));
    m_installing = false;
    m_progress = -1;
    m_error = message;
    emit changed();
    emit progressChanged();
}

void Updater::dismiss()
{
    m_dismissed = true;
    emit changed();
}

QVariantMap Updater::takeReleaseNotes(bool updated)
{
    const QString current = QCoreApplication::applicationVersion();
    const bool newer = m_previousVersion.isEmpty() ? updated
                                                   : compareVersions(current, m_previousVersion) > 0;
    if (m_notesTaken || !newer)
        return {};
    m_notesTaken = true;

    QFile file(QStringLiteral(":/CHANGELOG.md"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    const QStringList lines = QString::fromUtf8(file.readAll()).split(u'\n');

    // La sección de esta versión («## [0.9.1] - fecha», sin la etapa -beta)
    // o, en una compilación sin publicar, «## [Sin publicar]»
    const auto find = [&lines](const QString &name) {
        const QString heading = QStringLiteral("## [") + name + u']';
        for (qsizetype i = 0; i < lines.size(); ++i) {
            if (lines[i].startsWith(heading))
                return i;
        }
        return qsizetype(-1);
    };
    qsizetype start = find(current.section(u'-', 0, 0));
    if (start < 0)
        start = find(QStringLiteral("Sin publicar"));
    if (start < 0)
        return {};

    // «> Título» bajo el encabezado (opcional), «### Grupo» y «- cambio»
    // (un cambio puede seguir en las líneas sangradas de debajo)
    QString title;
    QVariantList groups;
    QString group;
    QStringList items;
    const auto flush = [&] {
        if (!items.isEmpty())
            groups.append(QVariantMap{ { QStringLiteral("name"), group }, { QStringLiteral("items"), items } });
        items.clear();
    };
    for (qsizetype i = start + 1; i < lines.size(); ++i) {
        const QString line = lines[i].trimmed();
        if (lines[i].startsWith(QLatin1String("## ")))
            break;
        if (line.startsWith(QLatin1String("### "))) {
            flush();
            group = line.mid(4).trimmed();
        } else if (line.startsWith(QLatin1String("> ")) && title.isEmpty() && group.isEmpty()) {
            title = line.mid(2).trimmed();
        } else if (line.startsWith(QLatin1String("- "))) {
            items.append(line.mid(2).trimmed());
        } else if (!line.isEmpty() && !items.isEmpty() && lines[i].startsWith(u' ')) {
            items.last() += u' ' + line;
        }
    }
    flush();
    if (groups.isEmpty())
        return {};
    return { { QStringLiteral("title"), title.isEmpty() ? DefaultNotesTitle : title },
             { QStringLiteral("version"), current },
             { QStringLiteral("groups"), groups } };
}

int Updater::compareVersions(const QString &a, const QString &b)
{
    static const QRegularExpression pattern(QStringLiteral("^(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?(-.*)?$"));
    const QRegularExpressionMatch ma = pattern.match(a.trimmed());
    const QRegularExpressionMatch mb = pattern.match(b.trimmed());
    if (!ma.hasMatch() || !mb.hasMatch())
        return 0;
    for (int i = 1; i <= 3; ++i) {
        const int na = ma.captured(i).toInt();
        const int nb = mb.captured(i).toInt();
        if (na != nb)
            return na < nb ? -1 : 1;
    }
    // Con los mismos números, la beta va antes que la final
    const bool pa = !ma.captured(4).isEmpty();
    const bool pb = !mb.captured(4).isEmpty();
    if (pa != pb)
        return pa ? -1 : 1;
    return 0;
}
