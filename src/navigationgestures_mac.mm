// Ajuste del sistema para deslizar entre páginas en macOS (ver navigationgestures.h)

#include "navigationgestures.h"

#import <AppKit/AppKit.h>

// Verdadero si en Ajustes del Sistema «Deslizar entre páginas» es con dos
// dedos (panel táctil) o está activado en el Magic Mouse. Con «tres dedos»
// llega como gesto propio (NativeGesture) y no por el desplazamiento.
// Se lee en cada gesto: el usuario puede cambiarlo con Mitis abierto
bool NavigationGestures::swipeFromScrollEnabled()
{
    return [NSEvent isSwipeTrackingFromScrollEventsEnabled];
}
