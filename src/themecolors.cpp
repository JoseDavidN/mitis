#include "themecolors.h"

#include <QMetaProperty>
#include <QQuickItem>
#include <QQuickWindow>

namespace {
QVariantMap s_normal;
QVariantMap s_private;

// Avisa a todos los objetos cuando cambian las paletas (otro tema elegido).
// Nunca se destruye: lo usan objetos hasta el final de la aplicación
ThemeColors *hub()
{
    static ThemeColors *instance = new ThemeColors();
    return instance;
}
}

ThemeColors::ThemeColors(QObject *owner)
    : QObject(owner)
    , m_owner(owner)
{
    if (!owner)
        return;
    connect(hub(), &ThemeColors::changed, this, &ThemeColors::changed);
    findWindow();
}

ThemeColors *ThemeColors::qmlAttachedProperties(QObject *object)
{
    return new ThemeColors(object);
}

void ThemeColors::setPalettes(const QVariantMap &normal, const QVariantMap &privado)
{
    s_normal = normal;
    s_private = privado;
    emit hub()->changed();
}

const QVariantMap &ThemeColors::palette() const
{
    return m_private && !s_private.isEmpty() ? s_private : s_normal;
}

bool ThemeColors::dark() const
{
    return palette().value(QStringLiteral("dark"), true).toBool();
}

QColor ThemeColors::color(const QString &name) const
{
    const QVariant value = palette().value(name);
    // Las paletas mezclan "#rrggbb" (texto) y Qt.rgba() (color)
    if (value.typeId() == QMetaType::QString)
        return QColor::fromString(value.toString());
    return value.value<QColor>();
}

// La ventana del objeto: él mismo, o la del primer elemento visual entre sus
// padres (un GradientStop o un Popup no son elementos visuales)
void ThemeColors::findWindow()
{
    for (QObject *object = m_owner; object; object = object->parent()) {
        if (auto *window = qobject_cast<QQuickWindow *>(object)) {
            setWindow(window);
            return;
        }
        if (auto *item = qobject_cast<QQuickItem *>(object)) {
            connect(item, &QQuickItem::windowChanged, this, &ThemeColors::setWindow);
            setWindow(item->window());
            return;
        }
    }
}

void ThemeColors::setWindow(QQuickWindow *window)
{
    if (m_window == window)
        return;
    if (m_window)
        disconnect(m_window, nullptr, this, nullptr);
    m_window = window;
    // `privateMode` de Main.qml: se mira también si cambia (se pone al crearla)
    if (window) {
        const QMetaObject *meta = window->metaObject();
        const int index = meta->indexOfProperty("privateMode");
        if (index >= 0 && meta->property(index).hasNotifySignal()) {
            connect(window, meta->property(index).notifySignal(), this,
                    metaObject()->method(metaObject()->indexOfSlot("updatePrivate()")));
        }
    }
    updatePrivate();
}

void ThemeColors::updatePrivate()
{
    const bool isPrivate = m_window && m_window->property("privateMode").toBool();
    if (isPrivate == m_private)
        return;
    m_private = isPrivate;
    emit changed();
}
