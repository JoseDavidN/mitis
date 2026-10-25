#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Colores del tema según la ventana: `Colors.ink`, `Colors.bgBase`… (propiedad
// adjunta de QML). Theme es uno para todas las ventanas; los colores no: en
// una ventana privada (la que tiene `privateMode: true`) son los de la paleta
// «privado» (negro mate) y en las demás, los del tema elegido. Cada objeto
// que los usa busca su ventana (subiendo por sus padres: un degradado, una
// lista desplegable) y sigue sus cambios. Las paletas las da Theme.qml
// (setPalettes); medidas y duraciones siguen en Theme. En QML es el tipo
// `Colors` del módulo Mitis.Core.
class ThemeColors : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Colors)
    QML_UNCREATABLE("Colors solo se usa como propiedad adjunta: Colors.ink")
    QML_ATTACHED(ThemeColors)

    // La ventana del objeto es privada
    Q_PROPERTY(bool privateWindow READ privateWindow NOTIFY changed)
    // Paleta oscura (logos e iconos claros) o clara
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(QColor backgroundScrim READ backgroundScrim NOTIFY changed)
    Q_PROPERTY(QColor bgBase READ bgBase NOTIFY changed)
    Q_PROPERTY(QColor bgGlow READ bgGlow NOTIFY changed)
    Q_PROPERTY(QColor bgMid READ bgMid NOTIFY changed)
    Q_PROPERTY(QColor brand1 READ brand1 NOTIFY changed)
    Q_PROPERTY(QColor brand2 READ brand2 NOTIFY changed)
    Q_PROPERTY(QColor brandLight1 READ brandLight1 NOTIFY changed)
    Q_PROPERTY(QColor brandLight2 READ brandLight2 NOTIFY changed)
    Q_PROPERTY(QColor controlsEnd READ controlsEnd NOTIFY changed)
    Q_PROPERTY(QColor controlsStart READ controlsStart NOTIFY changed)
    Q_PROPERTY(QColor danger READ danger NOTIFY changed)
    Q_PROPERTY(QColor dangerStrong READ dangerStrong NOTIFY changed)
    Q_PROPERTY(QColor faviconBackdrop READ faviconBackdrop NOTIFY changed)
    Q_PROPERTY(QColor focusRing READ focusRing NOTIFY changed)
    Q_PROPERTY(QColor hairline READ hairline NOTIFY changed)
    Q_PROPERTY(QColor hairlineHover READ hairlineHover NOTIFY changed)
    Q_PROPERTY(QColor hairlineSoft READ hairlineSoft NOTIFY changed)
    Q_PROPERTY(QColor hairlineStrong READ hairlineStrong NOTIFY changed)
    Q_PROPERTY(QColor ink READ ink NOTIFY changed)
    Q_PROPERTY(QColor inkDisabled READ inkDisabled NOTIFY changed)
    Q_PROPERTY(QColor inkFaint READ inkFaint NOTIFY changed)
    Q_PROPERTY(QColor inkMuted READ inkMuted NOTIFY changed)
    Q_PROPERTY(QColor inkSecondary READ inkSecondary NOTIFY changed)
    Q_PROPERTY(QColor inkSoft READ inkSoft NOTIFY changed)
    Q_PROPERTY(QColor inkStrong READ inkStrong NOTIFY changed)
    Q_PROPERTY(QColor line READ line NOTIFY changed)
    Q_PROPERTY(QColor ok READ ok NOTIFY changed)
    Q_PROPERTY(QColor onBrand READ onBrand NOTIFY changed)
    Q_PROPERTY(QColor selectBg READ selectBg NOTIFY changed)
    Q_PROPERTY(QColor selection READ selection NOTIFY changed)
    Q_PROPERTY(QColor surfaceFloat READ surfaceFloat NOTIFY changed)
    Q_PROPERTY(QColor surfacePopup READ surfacePopup NOTIFY changed)
    Q_PROPERTY(QColor tintActive READ tintActive NOTIFY changed)
    Q_PROPERTY(QColor tintHover READ tintHover NOTIFY changed)
    Q_PROPERTY(QColor tintSunken READ tintSunken NOTIFY changed)
    Q_PROPERTY(QColor titleBarEnd READ titleBarEnd NOTIFY changed)
    Q_PROPERTY(QColor titleBarStart READ titleBarStart NOTIFY changed)
    Q_PROPERTY(QColor warn READ warn NOTIFY changed)

public:
    explicit ThemeColors(QObject *owner = nullptr);

    static ThemeColors *qmlAttachedProperties(QObject *object);

    // Theme.qml: la paleta del tema elegido y la de las ventanas privadas
    // (objetos de Theme.palettes)
    Q_INVOKABLE void setPalettes(const QVariantMap &normal, const QVariantMap &privado);

    bool privateWindow() const { return m_private; }
    bool dark() const;
    QColor backgroundScrim() const { return color(QStringLiteral("backgroundScrim")); }
    QColor bgBase() const { return color(QStringLiteral("bgBase")); }
    QColor bgGlow() const { return color(QStringLiteral("bgGlow")); }
    QColor bgMid() const { return color(QStringLiteral("bgMid")); }
    QColor brand1() const { return color(QStringLiteral("brand1")); }
    QColor brand2() const { return color(QStringLiteral("brand2")); }
    QColor brandLight1() const { return color(QStringLiteral("brandLight1")); }
    QColor brandLight2() const { return color(QStringLiteral("brandLight2")); }
    QColor controlsEnd() const { return color(QStringLiteral("controlsEnd")); }
    QColor controlsStart() const { return color(QStringLiteral("controlsStart")); }
    QColor danger() const { return color(QStringLiteral("danger")); }
    QColor dangerStrong() const { return color(QStringLiteral("dangerStrong")); }
    QColor faviconBackdrop() const { return color(QStringLiteral("faviconBackdrop")); }
    QColor focusRing() const { return color(QStringLiteral("focusRing")); }
    QColor hairline() const { return color(QStringLiteral("hairline")); }
    QColor hairlineHover() const { return color(QStringLiteral("hairlineHover")); }
    QColor hairlineSoft() const { return color(QStringLiteral("hairlineSoft")); }
    QColor hairlineStrong() const { return color(QStringLiteral("hairlineStrong")); }
    QColor ink() const { return color(QStringLiteral("ink")); }
    QColor inkDisabled() const { return color(QStringLiteral("inkDisabled")); }
    QColor inkFaint() const { return color(QStringLiteral("inkFaint")); }
    QColor inkMuted() const { return color(QStringLiteral("inkMuted")); }
    QColor inkSecondary() const { return color(QStringLiteral("inkSecondary")); }
    QColor inkSoft() const { return color(QStringLiteral("inkSoft")); }
    QColor inkStrong() const { return color(QStringLiteral("inkStrong")); }
    QColor line() const { return color(QStringLiteral("line")); }
    QColor ok() const { return color(QStringLiteral("ok")); }
    QColor onBrand() const { return color(QStringLiteral("onBrand")); }
    QColor selectBg() const { return color(QStringLiteral("selectBg")); }
    QColor selection() const { return color(QStringLiteral("selection")); }
    QColor surfaceFloat() const { return color(QStringLiteral("surfaceFloat")); }
    QColor surfacePopup() const { return color(QStringLiteral("surfacePopup")); }
    QColor tintActive() const { return color(QStringLiteral("tintActive")); }
    QColor tintHover() const { return color(QStringLiteral("tintHover")); }
    QColor tintSunken() const { return color(QStringLiteral("tintSunken")); }
    QColor titleBarEnd() const { return color(QStringLiteral("titleBarEnd")); }
    QColor titleBarStart() const { return color(QStringLiteral("titleBarStart")); }
    QColor warn() const { return color(QStringLiteral("warn")); }

signals:
    void changed();

private slots:
    void setWindow(QQuickWindow *window);
    void updatePrivate();

private:
    QColor color(const QString &name) const;
    const QVariantMap &palette() const;
    void findWindow();

    QObject *m_owner = nullptr;
    QPointer<QQuickWindow> m_window;
    bool m_private = false;
};
