#!/usr/bin/env python3
"""Mide la RAM de un navegador con las páginas de tools/paginas.txt.

Comparativa de la Fase 5 (docs/rendimiento.md): Mitis frente a Chrome y
Firefox con las mismas páginas, en las mismas condiciones.

  1. Abre el navegador con un perfil nuevo y las 20 páginas.
     Mitis: como sesión restaurada, con las 4 primeras fijadas (nunca se
     suspenden: con la visible, 5 activas) y la 5.ª activa.
  2. Recorre todas las pestañas con Ctrl+Tab (cada una visible unos
     segundos), como alguien que las usa: así todas quedan cargadas.
  3. Al minuto mide la RAM (T1). Con --minutos, vuelve a medir pasado ese
     tiempo sin tocar nada (T2): en Mitis, las 15 no activas se habrán
     suspendido si --minutos supera la suspensión configurada (15 min).

La RAM es la suma del PSS (/proc/<pid>/smaps_rollup) del proceso y todos
sus descendientes, como el panel de memoria de Mitis. Solo Linux, con un
servidor X (Xvnc) en --display y libXtst para simular el teclado.

Ejemplos:
  tools/medir_ram.py mitis build/bin/Mitis --filtros ~/.local/share/Mitis/Mitis/filtros
  tools/medir_ram.py chrome /ruta/chrome-linux64/chrome --minutos 16
  tools/medir_ram.py firefox /ruta/firefox/firefox --minutos 16
"""

import argparse
import ctypes
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
FIJADAS = 4
ACTIVA = 4  # índice de la pestaña visible al empezar (la 5.ª)


def paginas():
    with open(os.path.join(AQUI, "paginas.txt"), encoding="utf-8") as archivo:
        return [l.strip() for l in archivo if l.strip() and not l.startswith("#")]


def descendientes(raiz):
    hijos = {}
    for entrada in os.listdir("/proc"):
        if not entrada.isdigit():
            continue
        try:
            with open(f"/proc/{entrada}/stat") as stat:
                linea = stat.read()
            padre = int(linea[linea.rfind(")") + 2:].split()[1])
            hijos.setdefault(padre, []).append(int(entrada))
        except (OSError, ValueError, IndexError):
            pass
    encontrados, pendientes = [], [raiz]
    while pendientes:
        pid = pendientes.pop()
        encontrados.append(pid)
        pendientes += hijos.get(pid, [])
    return encontrados


def pss_mb(raiz):
    total, procesos = 0, 0
    for pid in descendientes(raiz):
        try:
            with open(f"/proc/{pid}/smaps_rollup") as rollup:
                for linea in rollup:
                    if linea.startswith("Pss:"):
                        total += int(linea.split()[1])
                        procesos += 1
                        break
        except OSError:
            pass
    return round(total / 1024), procesos


class Teclado:
    """Teclado y ratón simulados con XTest (no hace falta xdotool)."""

    def __init__(self, display):
        self.x11 = ctypes.CDLL("libX11.so.6")
        self.xtst = ctypes.CDLL("libXtst.so.6")
        self.x11.XOpenDisplay.restype = ctypes.c_void_p
        self.x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        self.x11.XStringToKeysym.restype = ctypes.c_ulong
        self.d = ctypes.c_void_p(self.x11.XOpenDisplay(display.encode()))
        if not self.d:
            sys.exit(f"No se pudo abrir la pantalla {display}")

    def raton(self, x, y):
        self.xtst.XTestFakeMotionEvent(self.d, -1, x, y, 0)
        self.x11.XFlush(self.d)

    def teclas(self, *nombres):
        codigos = [self.x11.XKeysymToKeycode(self.d, self.x11.XStringToKeysym(n.encode())) for n in nombres]
        for codigo in codigos:
            self.xtst.XTestFakeKeyEvent(self.d, codigo, 1, 0)
        for codigo in reversed(codigos):
            self.xtst.XTestFakeKeyEvent(self.d, codigo, 0, 0)
        self.x11.XFlush(self.d)


def preparar_mitis(perfil, urls, args):
    config = os.path.join(perfil, "config", "Mitis")
    os.makedirs(config)
    pestanas = [{"url": u, "title": "", "icon": "", "pinned": i < FIJADAS} for i, u in enumerate(urls)]
    sesion = json.dumps({"current": ACTIVA, "tabs": pestanas})
    # Formato INI de QSettings: el texto entre comillas, con \" y \\ escapados
    sesion = '"' + sesion.replace("\\", "\\\\").replace('"', '\\"') + '"'
    with open(os.path.join(config, "Mitis.conf"), "w", encoding="utf-8") as conf:
        conf.write("[Blocker]\nenabled=%s\n\n" % ("false" if args.sin_bloqueador else "true"))
        conf.write("[Performance]\nsuspendAfter=%d\n\n" % args.suspender)
        conf.write("[Session]\ntabs=%s\n\n[Startup]\nmode=restore\n" % sesion)
    if args.filtros:
        shutil.copytree(args.filtros, os.path.join(perfil, "data", "Mitis", "Mitis", "filtros"))
    env = dict(os.environ, HOME=perfil, XDG_CONFIG_HOME=os.path.join(perfil, "config"),
               XDG_DATA_HOME=os.path.join(perfil, "data"), XDG_CACHE_HOME=os.path.join(perfil, "cache"))
    if args.flags is not None:
        env["QTWEBENGINE_CHROMIUM_FLAGS"] = args.flags
    return [args.binario], env


def preparar_chrome(perfil, urls, args):
    orden = [args.binario, f"--user-data-dir={perfil}", "--no-first-run", "--no-default-browser-check",
             "--password-store=basic", "--window-position=0,0", "--window-size=1400,900"]
    return orden + urls, dict(os.environ)


def preparar_firefox(perfil, urls, args):
    prefs = {
        "browser.aboutwelcome.enabled": False,
        "browser.startup.homepage_override.mstone": "ignore",
        "startup.homepage_welcome_url": "",
        "startup.homepage_welcome_url.additional": "",
        "browser.shell.checkDefaultBrowser": False,
        "datareporting.policy.dataSubmissionEnabled": False,
        "toolkit.telemetry.reportingpolicy.firstRun": False,
        "browser.ctrlTab.sortByRecentlyUsed": False,
        "browser.tabs.warnOnClose": False,
    }
    with open(os.path.join(perfil, "user.js"), "w") as user:
        for nombre, valor in prefs.items():
            user.write("user_pref(%s, %s);\n" % (json.dumps(nombre), json.dumps(valor)))
    orden = [args.binario, "-profile", perfil, "-no-remote", "-width", "1400", "-height", "900"]
    return orden + urls, dict(os.environ)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("navegador", choices=["mitis", "chrome", "firefox"])
    parser.add_argument("binario")
    parser.add_argument("--display", default=":7")
    parser.add_argument("--minutos", type=float, default=0, help="medir también pasado este tiempo (T2)")
    parser.add_argument("--espera", type=float, default=6, help="segundos en cada pestaña al recorrerlas")
    parser.add_argument("--filtros", help="Mitis: carpeta con las listas ya descargadas")
    parser.add_argument("--sin-bloqueador", action="store_true", help="Mitis: bloqueador desactivado")
    parser.add_argument("--suspender", type=int, default=15, help="Mitis: minutos para descargar pestañas")
    parser.add_argument("--flags", help="Mitis: QTWEBENGINE_CHROMIUM_FLAGS para esta medición")
    parser.add_argument("--etiqueta", default="")
    args = parser.parse_args()

    urls = paginas()
    perfil = tempfile.mkdtemp(prefix="medir-ram-")
    preparar = {"mitis": preparar_mitis, "chrome": preparar_chrome, "firefox": preparar_firefox}[args.navegador]
    orden, env = preparar(perfil, urls, args)
    env["DISPLAY"] = args.display

    teclado = Teclado(args.display)
    proceso = subprocess.Popen(orden, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               start_new_session=True)
    resultado = {"navegador": args.navegador, "etiqueta": args.etiqueta, "pestanas": len(urls)}
    try:
        time.sleep(45)
        # Sin gestor de ventanas, el teclado va a la ventana bajo el puntero
        teclado.raton(700, 450)
        for _ in range(len(urls)):
            teclado.teclas("Control_L", "Tab")
            time.sleep(args.espera)
        fin_recorrido = time.time()
        time.sleep(60)
        resultado["t1_mb"], resultado["t1_procesos"] = pss_mb(proceso.pid)
        print(json.dumps(resultado), flush=True)
        if args.minutos:
            time.sleep(max(0, fin_recorrido + args.minutos * 60 - time.time()))
            resultado["t2_minutos"] = args.minutos
            resultado["t2_mb"], resultado["t2_procesos"] = pss_mb(proceso.pid)
            print(json.dumps(resultado), flush=True)
    finally:
        try:
            os.killpg(proceso.pid, signal.SIGTERM)
            proceso.wait(timeout=15)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(proceso.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        shutil.rmtree(perfil, ignore_errors=True)


if __name__ == "__main__":
    main()
