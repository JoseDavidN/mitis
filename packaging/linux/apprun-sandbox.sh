# Gancho del AppRun del AppImage (apprun-hooks/): el AppRun de linuxdeploy lo
# carga con «source» antes de abrir Mitis. No usar «exit» aquí.
#
# Sandbox de Chromium en un AppImage
# ----------------------------------
# Qt WebEngine aísla cada página con el sandbox de espacios de nombres de usuario
# (user namespaces) + seccomp. No trae el sandbox setuid de Chrome (chrome-sandbox):
# dentro de un AppImage tampoco serviría, porque se monta con «nosuid». Si el
# sistema no deja crear espacios de nombres sin privilegios, Chromium no encuentra
# ningún sandbox utilizable y las páginas no llegan a abrirse. Pasa en:
#   - Ubuntu 23.10 y posteriores: AppArmor los restringe
#     (kernel.apparmor_restrict_unprivileged_userns=1) a los programas con perfil
#     propio, y un AppImage no lo tiene.
#   - Debian antiguo y algunos núcleos endurecidos (kernel.unprivileged_userns_clone=0,
#     user.max_user_namespaces=0).
#
# Decisión: el sandbox se mantiene siempre que funcione y solo se desactiva
# (QTWEBENGINE_DISABLE_SANDBOX=1) cuando el sistema lo impide; se avisa por la salida.
#
# RIESGO de desactivarlo: el proceso de cada página (QtWebEngineProcess) corre con
# todos los permisos del usuario. Un fallo de Chromium aprovechado por una web
# maliciosa podría leer o escribir cualquier archivo del usuario, en lugar de
# quedar encerrado. Es lo mismo que hacen otros navegadores en AppImage
# (--no-sandbox), pero conviene recomendar el paquete de la distribución
# (PKGBUILD en Arch) o permitir los espacios de nombres:
#   sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0
#
# Para decidirlo a mano al lanzar el AppImage:
#   QTWEBENGINE_DISABLE_SANDBOX=1  sin sandbox, sin comprobar nada
#   MITIS_SANDBOX=1                con sandbox siempre (si el sistema no lo
#                                  permite, las páginas no abrirán)
# Qt solo mira si QTWEBENGINE_DISABLE_SANDBOX existe, no su valor: «=0» también
# lo desactiva. Por eso aquí se exporta solo cuando hace falta.

if [ -z "${QTWEBENGINE_DISABLE_SANDBOX+x}" ] && [ "${MITIS_SANDBOX:-}" != 1 ]; then
    mitis_sin_sandbox=0
    if command -v unshare >/dev/null 2>&1; then
        # Prueba real: crear un espacio de nombres de usuario y mapear el uid,
        # lo mismo que necesita Chromium. Con AppArmor restrictivo falla aquí.
        unshare --user --map-root-user true >/dev/null 2>&1 || mitis_sin_sandbox=1
    else
        # Sin unshare (util-linux), se miran los ajustes del núcleo
        for mitis_ajuste in /proc/sys/kernel/apparmor_restrict_unprivileged_userns:1 \
                            /proc/sys/kernel/unprivileged_userns_clone:0 \
                            /proc/sys/user/max_user_namespaces:0; do
            mitis_archivo=${mitis_ajuste%:*}
            if [ -r "$mitis_archivo" ] && [ "$(cat "$mitis_archivo")" = "${mitis_ajuste##*:}" ]; then
                mitis_sin_sandbox=1
            fi
        done
        unset mitis_ajuste mitis_archivo
    fi

    if [ "$mitis_sin_sandbox" = 1 ]; then
        echo "Mitis: el sistema no permite el sandbox de Chromium (espacios de nombres de usuario); se abre sin él." >&2
        export QTWEBENGINE_DISABLE_SANDBOX=1
    fi
    unset mitis_sin_sandbox
fi
