#include "profiles.h"

#include "links.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QQmlEngine>
#include <QRandomGenerator>
#include <QSettings>
#include <QStandardPaths>

#include <iterator>

namespace {

const QString Organization = QStringLiteral("Mitis");
// El principal se pide así en --perfil (sin argumento, abrir Mitis con el
// principal ya abierto crearía uno nuevo)
const QString MainId = QStringLiteral("principal");
const QString ProfileOption = QStringLiteral("--perfil");

QString currentProfile;

QString appNameFor(const QString &id)
{
    return id.isEmpty() ? QStringLiteral("Mitis") : QStringLiteral("Mitis-") + id;
}

// Registro común de todos los perfiles: solo la lista de ids, en orden
const QString Registry = QStringLiteral("perfiles");

QStringList createdIds()
{
    return QSettings(Organization, Registry).value(QStringLiteral("ids")).toStringList();
}

void saveIds(const QStringList &ids)
{
    QSettings registry(Organization, Registry);
    registry.setValue(QStringLiteral("ids"), ids);
    registry.sync();
}

struct Paths {
    QString data;
    QString cache;
    QString config;
};

// Carpetas de un perfil: las de Qt con su nombre de aplicación (cambia la
// ruta en cada sistema; así no hay que repetir sus reglas)
Paths pathsFor(const QString &id)
{
    const QString previous = QCoreApplication::applicationName();
    QCoreApplication::setApplicationName(appNameFor(id));
    Paths paths;
    paths.data = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    paths.cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    paths.config = QSettings(Organization, appNameFor(id)).fileName();
    QCoreApplication::setApplicationName(previous);
    return paths;
}

void use(const QString &id)
{
    currentProfile = id;
    QCoreApplication::setOrganizationName(Organization);
    QCoreApplication::setApplicationName(appNameFor(id));
}

// Colores del avatar (Theme.avatarColors): uno distinto para cada perfil nuevo
const char *const AvatarColors[] = { "violeta", "rosa", "azul", "verde", "naranja", "gris" };

} // namespace

Profiles::Profiles(QObject *parent)
    : QObject(parent)
{
}

Profiles *Profiles::instance()
{
    static Profiles *profiles = new Profiles;
    return profiles;
}

Profiles *Profiles::create(QQmlEngine *, QJSEngine *)
{
    Profiles *profiles = instance();
    QQmlEngine::setObjectOwnership(profiles, QQmlEngine::CppOwnership);
    return profiles;
}

void Profiles::select(const QStringList &arguments)
{
    const qsizetype option = arguments.indexOf(ProfileOption);
    if (option >= 0 && option + 1 < arguments.size()) {
        QString id = arguments.at(option + 1);
        if (id == MainId)
            id.clear();
        // Solo los que existen: un id inventado abriría una carpeta nueva sin registrar
        if (!id.isEmpty() && !createdIds().contains(id))
            id.clear();
        use(id);
        return;
    }
    use(QString());
    // Abrir Mitis otra vez (lanzador, atajo) con el principal ya abierto:
    // un perfil nuevo, en su propia ventana. Con enlaces (navegador
    // predeterminado), en cambio, van al principal (main.cpp los pasa)
    if (Links::fromArguments(arguments).isEmpty() && Links::isRunning(Links::serverName()))
        use(createProfile());
}

QString Profiles::currentId()
{
    return currentProfile;
}

QStringList Profiles::launchArguments()
{
    return { ProfileOption, currentProfile.isEmpty() ? MainId : currentProfile };
}

QString Profiles::createProfile()
{
    QStringList ids = createdIds();
    QString id;
    do {
        id = QString::number(QRandomGenerator::global()->generate() & 0xffffff, 16).rightJustified(6, u'0');
    } while (ids.contains(id) || id == MainId);

    // Nombre «Perfil N» y un color que no tengan los demás
    QStringList names;
    QStringList colors;
    const QStringList existing = QStringList(ids) << QString();
    for (const QString &other : existing) {
        const QSettings settings(Organization, appNameFor(other));
        names.append(settings.value(QStringLiteral("Profile/name")).toString());
        colors.append(settings.value(QStringLiteral("Profile/color"), QStringLiteral("violeta")).toString());
    }
    int number = 2;
    while (names.contains(QStringLiteral("Perfil %1").arg(number)))
        ++number;
    QString color = QString::fromLatin1(AvatarColors[ids.size() % std::size(AvatarColors)]);
    for (const char *candidate : AvatarColors) {
        if (!colors.contains(QLatin1String(candidate))) {
            color = QString::fromLatin1(candidate);
            break;
        }
    }
    QSettings settings(Organization, appNameFor(id));
    settings.setValue(QStringLiteral("Profile/name"), QStringLiteral("Perfil %1").arg(number));
    settings.setValue(QStringLiteral("Profile/color"), color);
    settings.sync();

    ids.append(id);
    saveIds(ids);
    return id;
}

QVariantList Profiles::list() const
{
    QVariantList list;
    for (const QString &id : QStringList(QString()) + createdIds()) {
        const QSettings settings(Organization, appNameFor(id));
        const bool current = id == currentProfile;
        list.append(QVariantMap{
            { QStringLiteral("id"), id },
            { QStringLiteral("name"), settings.value(QStringLiteral("Profile/name")).toString() },
            { QStringLiteral("color"), settings.value(QStringLiteral("Profile/color"), QStringLiteral("violeta")).toString() },
            { QStringLiteral("photo"), settings.value(QStringLiteral("Profile/photo")).toString() },
            { QStringLiteral("current"), current },
            { QStringLiteral("running"), current || Links::isRunning(Links::serverNameFor(pathsFor(id).data)) },
        });
    }
    return list;
}

void Profiles::open(const QString &id) const
{
    // AppImage: el ejecutable vive en una carpeta montada solo mientras corre
    const QString appImage = qEnvironmentVariable("APPIMAGE");
    const QString program = appImage.isEmpty() ? QCoreApplication::applicationFilePath() : appImage;
    QStringList arguments{ ProfileOption, id.isEmpty() ? MainId : id };
    if (QCoreApplication::arguments().contains(QStringLiteral("--dev")))
        arguments.append(QStringLiteral("--dev"));
    if (!QProcess::startDetached(program, arguments))
        qWarning("No se pudo abrir el perfil %s", qPrintable(id));
}

void Profiles::openNew() const
{
    const QString id = createProfile();
    emit const_cast<Profiles *>(this)->changed();
    open(id);
}

bool Profiles::remove(const QString &id)
{
    if (id.isEmpty() || id == currentProfile || !createdIds().contains(id))
        return false;
    const Paths paths = pathsFor(id);
    if (Links::isRunning(Links::serverNameFor(paths.data)))
        return false;
    QDir(paths.data).removeRecursively();
    QDir(paths.cache).removeRecursively();
    QFile::remove(paths.config);
    QStringList ids = createdIds();
    ids.removeAll(id);
    saveIds(ids);
    emit changed();
    return true;
}
