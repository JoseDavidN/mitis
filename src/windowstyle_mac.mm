// setWindowRoundedCorners en macOS (ver windowstyle.h)

#include "windowstyle.h"

#include <QWindow>

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

namespace {
// El radio de las ventanas de macOS
constexpr CGFloat Radius = 10;
}

void setWindowRoundedCorners(QWindow *window, bool rounded)
{
    if (!window)
        return;
    // Con ARC, el WId (un número) pasa a NSView * por void * con __bridge: sin
    // cambiar quién es dueño de la vista (sigue siendo de Qt)
    NSView *view = (__bridge NSView *)reinterpret_cast<void *>(window->winId());
    NSWindow *nsWindow = view.window;
    if (!view || !nsWindow)
        return;
    // Lo de fuera de las esquinas, transparente: la ventana no es opaca
    nsWindow.opaque = !rounded;
    nsWindow.backgroundColor = rounded ? NSColor.clearColor : NSColor.windowBackgroundColor;
    nsWindow.hasShadow = YES;
    view.wantsLayer = YES;
    view.layer.cornerRadius = rounded ? Radius : 0;
    view.layer.masksToBounds = rounded;
    if (@available(macOS 10.15, *))
        view.layer.cornerCurve = kCACornerCurveContinuous;
    // La sombra se recalcula con la nueva forma
    [nsWindow invalidateShadow];
}
