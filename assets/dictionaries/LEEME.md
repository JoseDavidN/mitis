# Diccionario del corrector ortográfico

`es.bdic`: español genérico (todas las variantes) del proyecto RLA-ES
(https://github.com/sbosio/rla-es), versión 2.9, el mismo que usan LibreOffice
y Firefox. Licencia triple a elegir: GPL-3.0 o posterior, LGPL-3.0 o
posterior o MPL-1.1 o posterior; Mitis lo usa bajo la GPL-3.0, como el resto
del programa (ver `licencias/AVISOS.md`).

Se generó a partir de `es.dic` y `es.aff` (dentro de `es.oxt` de esa versión)
con la herramienta de Qt WebEngine:

```bash
qwebengine_convert_dict es.dic es.bdic   # en Arch: /usr/lib/qt6/qwebengine_convert_dict
```

Para actualizarlo, repetir con una versión nueva de RLA-ES. Mitis solo trae
este: no se pueden añadir otros idiomas.
