// Scriptlets de uBlock Origin: las reglas «sitio##+js(nombre, args…)» de sus
// listas, que cambian el comportamiento de la página para quitar anuncios
// (YouTube) y avisos anti-bloqueador. Van en el mundo de la página y antes
// que sus scripts: BrowserTab lo inyecta al empezar cada carga, solo en los
// sitios que tienen alguno, y EngineBridge::scriptlets() añade la llamada con
// las reglas del sitio: [["nombre", "arg1"…], …], con el nombre ya
// normalizado (alias resueltos) y solo de los que hay aquí.
//
// Adaptado de uBlock Origin (src/js/resources/ y src/js/jsonpath.js,
// https://github.com/gorhill/uBlock), © Raymond Hill y colaboradores, con
// licencia GPL-3.0 como Mitis. Mismo comportamiento, sin el registro de
// depuración. Cada scriptlet corre en su try/catch: uno roto no estropea la
// página ni a los demás.
(function (rules) {
    'use strict';

    // ── Funciones nativas, guardadas antes de que la página las cambie ──
    const safe = {
        Error: self.Error,
        Object: Object,
        RegExp: self.RegExp,
        RegExp_test: Function.prototype.call.bind(self.RegExp.prototype.test),
        RegExp_exec: self.RegExp.prototype.exec,
        Request_clone: self.Request.prototype.clone,
        String: self.String,
        String_fromCharCode: String.fromCharCode,
        String_includes: String.prototype.includes,
        String_split: String.prototype.split,
        Function_toString: Function.prototype.call.bind(self.Function.prototype.toString),
        Math_floor: Math.floor,
        Math_max: Math.max,
        Math_min: Math.min,
        Math_random: Math.random,
        Object_defineProperty: Object.defineProperty.bind(Object),
        Object_defineProperties: Object.defineProperties.bind(Object),
        Object_fromEntries: Object.fromEntries.bind(Object),
        Object_getOwnPropertyDescriptor: Object.getOwnPropertyDescriptor.bind(Object),
        Object_hasOwn: Object.hasOwn.bind(Object),
        Object_toString: Object.prototype.toString,
        JSON_parse: Function.prototype.call.bind(self.JSON.parse, self.JSON),
        JSON_stringify: Function.prototype.call.bind(self.JSON.stringify, self.JSON),
        structuredClone: Function.prototype.call.bind(self.structuredClone, self),
        addEventListener: self.EventTarget.prototype.addEventListener,
        removeEventListener: self.EventTarget.prototype.removeEventListener,
        escapeRegexChars(s) {
            return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        },
        // Texto o /expresión/; con canNegate, «!» delante lo invierte
        initPattern(pattern, options = {}) {
            if (pattern === '')
                return { matchAll: true, expect: true };
            const expect = (options.canNegate !== true || pattern.startsWith('!') === false);
            if (expect === false)
                pattern = pattern.slice(1);
            const match = /^\/(.+)\/([gimsu]*)$/.exec(pattern);
            if (match !== null)
                return { re: new this.RegExp(match[1], match[2] || options.flags), expect };
            if (options.flags !== undefined)
                return { re: new this.RegExp(this.escapeRegexChars(pattern), options.flags), expect };
            return { pattern, expect };
        },
        testPattern(details, haystack) {
            if (details.matchAll)
                return true;
            if (details.re)
                return this.RegExp_test(details.re, haystack) === details.expect;
            return this.String_includes.call(`${haystack}`, details.pattern) === details.expect;
        },
        patternToRegex(pattern, flags = undefined, verbatim = false) {
            if (pattern === '')
                return /^/;
            const match = /^\/(.+)\/([gimsu]*)$/.exec(pattern);
            if (match === null) {
                const reStr = this.escapeRegexChars(pattern);
                return new RegExp(verbatim ? `^${reStr}$` : reStr, flags);
            }
            try {
                return new RegExp(match[1], match[2] || undefined);
            } catch {
            }
            return /^/;
        },
        // Argumentos «nombre, valor» del final: { nombre: valor }
        parseVarargs(varargs) {
            const entries = varargs.reduce((out, v, i, a) => {
                if (i & 1)
                    return out;
                const rawValue = a[i + 1];
                const value = /^\d+$/.test(rawValue) ? parseInt(rawValue, 10) : rawValue;
                out.push([a[i], value]);
                return out;
            }, []);
            return this.Object_fromEntries(entries);
        },
    };

    // ── Utilidades ───────────────────────────────────────────────────
    function runAt(fn, when) {
        const intFromReadyState = state => {
            const targets = {
                'loading': 1, 'asap': 1,
                'interactive': 2, 'end': 2, '2': 2,
                'complete': 3, 'idle': 3, '3': 3,
            };
            const tokens = Array.isArray(state) ? state : [state];
            for (const token of tokens) {
                const prop = `${token}`;
                if (Object.hasOwn(targets, prop) === false)
                    continue;
                return targets[prop];
            }
            return 0;
        };
        const target = intFromReadyState(when);
        if (intFromReadyState(document.readyState) >= target) {
            fn();
            return;
        }
        const onStateChange = () => {
            if (intFromReadyState(document.readyState) < target)
                return;
            fn();
            safe.removeEventListener.apply(document, args);
        };
        const args = ['readystatechange', onStateChange, { capture: true }];
        safe.addEventListener.apply(document, args);
    }

    function runAtHtmlElement(fn) {
        if (document.documentElement) {
            fn();
            return;
        }
        const observer = new MutationObserver(() => {
            observer.disconnect();
            fn();
        });
        observer.observe(document, { childList: true });
    }

    function onIdle(fn, options) {
        if (self.requestIdleCallback)
            return self.requestIdleCallback(fn, options);
        return self.requestAnimationFrame(fn);
    }

    function offIdle(id) {
        if (self.requestIdleCallback)
            return self.cancelIdleCallback(id);
        return self.cancelAnimationFrame(id);
    }

    function getRandomToken() {
        return safe.String_fromCharCode(Date.now() % 26 + 97)
            + safe.Math_floor(safe.Math_random() * 982451653 + 982451653).toString(36);
    }

    // El error que lanzan los «abort-…» no sale en la consola de la página
    function getExceptionToken() {
        const token = getRandomToken();
        const oe = self.onerror;
        self.onerror = function (msg, ...args) {
            if (typeof msg === 'string' && msg.includes(token))
                return true;
            if (oe instanceof Function)
                return oe.call(this, msg, ...args);
        }.bind();
        return token;
    }

    // Varias trampas sobre la misma propiedad (abort-current-script)
    function trapProperty(propChain, handler, options = {}) {
        if (propChain === '')
            return;
        let owner = self;
        let prop = propChain;
        for (;;) {
            const pos = prop.indexOf('.');
            if (pos === -1)
                break;
            owner = owner[prop.slice(0, pos)];
            if (owner instanceof Object === false)
                return;
            prop = prop.slice(pos + 1);
        }
        if (trapProperty.db === undefined) {
            trapProperty.db = new WeakMap();
            trapProperty.entryFromContext = (owner, prop) => trapProperty.db.get(owner)?.get(prop);
            trapProperty.getter = (owner, prop) => {
                const entry = trapProperty.entryFromContext(owner, prop);
                if (entry === undefined)
                    return;
                let r = entry.value;
                for (const desc of entry.stack) {
                    try {
                        r = desc.get();
                    } catch (e) {
                        if (entry.canThrow)
                            throw e;
                    }
                }
                return r;
            };
            trapProperty.setter = (owner, prop, value) => {
                const entry = trapProperty.entryFromContext(owner, prop);
                if (entry === undefined)
                    return;
                entry.value = value;
                for (const desc of entry.stack) {
                    try {
                        desc.set(value);
                    } catch (e) {
                        if (entry.canThrow)
                            throw e;
                    }
                }
            };
        }
        const { db } = trapProperty;
        const handlers = db.get(owner) || new Map();
        if (handlers.size === 0)
            db.set(owner, handlers);
        const entry = handlers.get(prop) || { value: owner[prop], stack: [] };
        entry.stack.push(handler);
        if (entry.stack.length > 1)
            return entry.value;
        Object.assign(entry, options);
        handlers.set(prop, entry);
        const desc = safe.Object_getOwnPropertyDescriptor(owner, prop);
        if (desc instanceof safe.Object && (desc.get || desc.set))
            entry.stack.push(desc);
        try {
            safe.Object_defineProperty(owner, prop, {
                get() {
                    return trapProperty.getter(owner, prop);
                },
                set(value) {
                    trapProperty.setter(owner, prop, value);
                },
            });
        } catch {
        }
        return entry.value;
    }

    // Function.prototype.toString de una función envuelta da el de la
    // original: la página no ve el cambio
    function proxyToString(proxiedFn, nativeFn) {
        if (proxyToString.proxies === undefined) {
            proxyToString.proxies = new WeakMap();
            proxyToString.nativeToString = Function.prototype.toString;
            const proxiedToString = new Proxy(Function.prototype.toString, {
                apply(target, thisArg) {
                    let proxied = thisArg;
                    for (;;) {
                        const fn = proxyToString.proxies.get(proxied);
                        if (fn === undefined)
                            break;
                        proxied = fn;
                    }
                    return proxyToString.nativeToString.call(proxied);
                },
            });
            proxyToString.proxies.set(proxiedToString, proxyToString.nativeToString);
            Function.prototype.toString = proxiedToString;
        }
        proxyToString.proxies.set(proxiedFn, nativeFn);
    }

    // Envuelve la función de `target` («a.b.c»): `handler` recibe el
    // contexto de cada llamada y decide (context.reflect() llama a la original)
    function proxyApply(target = '', handler = '') {
        let context = globalThis;
        let prop = target;
        for (;;) {
            const pos = prop.indexOf('.');
            if (pos === -1)
                break;
            context = context[prop.slice(0, pos)];
            if (context instanceof Object === false)
                return;
            prop = prop.slice(pos + 1);
        }
        const fn = context[prop];
        if (typeof fn !== 'function')
            return;
        if (proxyApply.CtorContext === undefined) {
            proxyApply.ctorContexts = [];
            proxyApply.CtorContext = class {
                constructor(...args) {
                    this.init(...args);
                }
                init(callFn, callArgs) {
                    this.callFn = callFn;
                    this.callArgs = callArgs;
                    return this;
                }
                reflect() {
                    const r = Reflect.construct(this.callFn, this.callArgs);
                    this.callFn = this.callArgs = this.private = undefined;
                    proxyApply.ctorContexts.push(this);
                    return r;
                }
                static factory(...args) {
                    return proxyApply.ctorContexts.length !== 0
                        ? proxyApply.ctorContexts.pop().init(...args)
                        : new proxyApply.CtorContext(...args);
                }
            };
            proxyApply.applyContexts = [];
            proxyApply.ApplyContext = class {
                constructor(...args) {
                    this.init(...args);
                }
                init(callFn, thisArg, callArgs) {
                    this.callFn = callFn;
                    this.thisArg = thisArg;
                    this.callArgs = callArgs;
                    return this;
                }
                reflect() {
                    const r = Reflect.apply(this.callFn, this.thisArg, this.callArgs);
                    this.callFn = this.thisArg = this.callArgs = this.private = undefined;
                    proxyApply.applyContexts.push(this);
                    return r;
                }
                static factory(...args) {
                    return proxyApply.applyContexts.length !== 0
                        ? proxyApply.applyContexts.pop().init(...args)
                        : new proxyApply.ApplyContext(...args);
                }
            };
            proxyApply.isCtor = new Map();
        }
        if (proxyApply.isCtor.has(target) === false)
            proxyApply.isCtor.set(target, fn.prototype?.constructor === fn);
        const proxyDetails = {
            apply(target, thisArg, args) {
                return handler(proxyApply.ApplyContext.factory(target, thisArg, args));
            },
        };
        if (proxyApply.isCtor.get(target)) {
            proxyDetails.construct = function (target, args) {
                return handler(proxyApply.CtorContext.factory(target, args));
            };
        }
        const proxiedTarget = new Proxy(fn, proxyDetails);
        proxyToString(proxiedTarget, fn);
        context[prop] = proxiedTarget;
    }

    // Valores de set-constant y compañía
    function validateConstant(trusted, raw, extraArgs = {}) {
        let value;
        if (raw === 'undefined') {
            value = undefined;
        } else if (raw === 'false') {
            value = false;
        } else if (raw === 'true') {
            value = true;
        } else if (raw === 'null') {
            value = null;
        } else if (raw === "''" || raw === '') {
            value = '';
        } else if (raw === '[]' || raw === 'emptyArr') {
            value = [];
        } else if (raw === '{}' || raw === 'emptyObj') {
            value = {};
        } else if (raw === 'noopFunc') {
            value = function () {};
        } else if (raw === 'trueFunc') {
            value = function () { return true; };
        } else if (raw === 'falseFunc') {
            value = function () { return false; };
        } else if (raw === 'throwFunc') {
            value = function () { throw ''; };
        } else if (/^-?\d+$/.test(raw)) {
            value = parseInt(raw);
            if (isNaN(raw))
                return;
            if (Math.abs(raw) > 0x7FFF)
                return;
        } else if (trusted) {
            if (raw.startsWith('json:')) {
                try {
                    value = safe.JSON_parse(raw.slice(5));
                } catch {
                    return;
                }
            } else if (raw.startsWith('{') && raw.endsWith('}')) {
                try {
                    value = safe.JSON_parse(raw).value;
                } catch {
                    return;
                }
            }
        } else {
            return;
        }
        if (extraArgs.as !== undefined) {
            if (extraArgs.as === 'function')
                return () => value;
            if (extraArgs.as === 'callback')
                return () => (() => value);
            if (extraArgs.as === 'resolved')
                return Promise.resolve(value);
            if (extraArgs.as === 'rejected')
                return Promise.reject(value);
        }
        return value;
    }

    // Propiedades de una petición fetch (dirección, método…) para propsToMatch
    function collateFetchArguments(resource, options) {
        const props = [
            'body', 'cache', 'credentials', 'duplex', 'headers',
            'integrity', 'keepalive', 'method', 'mode', 'priority',
            'redirect', 'referrer', 'referrerPolicy', 'url',
        ];
        const collate = (src, out) => {
            for (const prop of props) {
                if (src[prop] === undefined)
                    continue;
                out[prop] = src[prop];
            }
        };
        const out = {};
        if (typeof resource !== 'object' || safe.Object_toString.call(resource) !== '[object Request]') {
            out.url = `${resource}`;
        } else {
            let clone;
            try {
                clone = safe.Request_clone.call(resource);
            } catch {
            }
            collate(clone || resource, out);
        }
        if (typeof options === 'object' && options !== null)
            collate(options, out);
        return out;
    }

    // «url:patrón method:POST» (o solo el patrón, de la propiedad `implicit`)
    function parsePropertiesToMatch(propsToMatch, implicit = '') {
        const needles = new Map();
        if (propsToMatch === undefined || propsToMatch === '')
            return needles;
        const options = { canNegate: true };
        for (const needle of safe.String_split.call(propsToMatch, /\s+/)) {
            let [prop, pattern] = safe.String_split.call(needle, ':');
            if (prop === '')
                continue;
            if (pattern !== undefined && /[^$\w -]/.test(prop)) {
                prop = `${prop}:${pattern}`;
                pattern = undefined;
            }
            if (pattern !== undefined)
                needles.set(prop, safe.initPattern(pattern, options));
            else if (implicit !== '')
                needles.set(implicit, safe.initPattern(prop, options));
        }
        return needles;
    }

    function matchObjectProperties(propNeedles, ...objs) {
        const matched = [];
        for (const obj of objs) {
            if (obj instanceof Object === false)
                continue;
            for (const [prop, details] of propNeedles) {
                let value = obj[prop];
                if (value === undefined)
                    continue;
                if (typeof value !== 'string') {
                    try {
                        value = safe.JSON_stringify(value);
                    } catch {
                    }
                    if (typeof value !== 'string')
                        continue;
                }
                if (safe.testPattern(details, value) === false)
                    return;
                matched.push(`${prop}: ${value}`);
            }
        }
        return matched;
    }

    // Respuesta falsa de prevent-fetch / prevent-xhr
    function generateContent(trusted, directive) {
        const randomize = len => {
            const chunks = [];
            let textSize = 0;
            do {
                const s = safe.Math_random().toString(36).slice(2);
                chunks.push(s);
                textSize += s.length;
            } while (textSize < len);
            return chunks.join(' ').slice(0, len);
        };
        if (directive === 'true')
            return randomize(10);
        if (directive === 'emptyObj')
            return '{}';
        if (directive === 'emptyArr')
            return '[]';
        if (directive === 'emptyStr')
            return '';
        if (directive.startsWith('length:')) {
            const match = /^length:(\d+)(?:-(\d+))?$/.exec(directive);
            if (match === null)
                return '';
            const min = parseInt(match[1], 10);
            const extent = safe.Math_max(parseInt(match[2], 10) || 0, min) - min;
            const len = safe.Math_min(min + extent * safe.Math_random(), 500000);
            return randomize(len | 0);
        }
        if (directive.startsWith('war:'))
            return '';
        if (directive.startsWith('join:')) {
            const parts = directive.slice(7)
                .split(directive.slice(5, 7))
                .map(a => generateContent(trusted, a));
            return parts.some(a => a instanceof Promise)
                ? Promise.all(parts).then(parts => parts.join(''))
                : parts.join('');
        }
        if (trusted)
            return directive;
        return '';
    }

    // ¿Viene la llamada de un script cuya pila encaja con el patrón?
    function matchesStackTrace(needleDetails) {
        const exceptionToken = getExceptionToken();
        const error = new safe.Error(exceptionToken);
        const docURL = new URL(self.location.href);
        docURL.hash = '';
        const reLine = /(.*?@)?(\S+)(:\d+):\d+\)?$/;
        const lines = [];
        for (let line of safe.String_split.call(error.stack, /[\n\r]+/)) {
            if (line.includes(exceptionToken))
                continue;
            line = line.trim();
            const match = safe.RegExp_exec.call(reLine, line);
            if (match === null)
                continue;
            let url = match[2];
            if (url.startsWith('('))
                url = url.slice(1);
            if (url === docURL.href)
                url = 'inlineScript';
            else if (url.startsWith('<anonymous>'))
                url = 'injectedScript';
            let fn = match[1] !== undefined ? match[1].slice(0, -1) : line.slice(0, match.index).trim();
            if (fn.startsWith('at'))
                fn = fn.slice(2).trim();
            const rowcol = match[3];
            lines.push(' ' + `${fn} ${url}${rowcol}:1`.trim());
        }
        lines[0] = `stackDepth:${lines.length - 1}`;
        const stack = lines.join('\t');
        return needleDetails.matchAll !== true && safe.testPattern(needleDetails, stack);
    }

    // Rutas de json-prune: «a.b», «[]» (todos los elementos), «[-]» (quitar
    // el elemento que la tenga), «{}», «{-}» y «*»
    function objectFindOwner(root, path, prune = false) {
        let owner = root;
        let chain = path;
        for (;;) {
            if (typeof owner !== 'object' || owner === null)
                return false;
            const pos = chain.indexOf('.');
            if (pos === -1) {
                if (prune === false)
                    return safe.Object_hasOwn(owner, chain);
                let modified = false;
                if (chain === '*') {
                    for (const key in owner) {
                        if (safe.Object_hasOwn(owner, key) === false)
                            continue;
                        delete owner[key];
                        modified = true;
                    }
                } else if (safe.Object_hasOwn(owner, chain)) {
                    delete owner[chain];
                    modified = true;
                }
                return modified;
            }
            const prop = chain.slice(0, pos);
            const next = chain.slice(pos + 1);
            let found = false;
            if (prop === '[-]' && Array.isArray(owner)) {
                let i = owner.length;
                while (i--) {
                    if (objectFindOwner(owner[i], next) === false)
                        continue;
                    owner.splice(i, 1);
                    found = true;
                }
                return found;
            }
            if (prop === '{-}' && owner instanceof Object) {
                for (const key of Object.keys(owner)) {
                    if (objectFindOwner(owner[key], next) === false)
                        continue;
                    delete owner[key];
                    found = true;
                }
                return found;
            }
            if ((prop === '[]' && Array.isArray(owner)) || (prop === '{}' && owner instanceof Object)
                || (prop === '*' && owner instanceof Object)) {
                for (const key of Object.keys(owner)) {
                    if (objectFindOwner(owner[key], next, prune) === false)
                        continue;
                    found = true;
                }
                return found;
            }
            if (safe.Object_hasOwn(owner, prop) === false)
                return false;
            owner = owner[prop];
            chain = chain.slice(pos + 1);
        }
    }

    // El objeto podado, o undefined si no cambió
    function objectPrune(obj, rawPrunePaths, rawNeedlePaths, stackNeedleDetails = { matchAll: true }) {
        if (typeof rawPrunePaths !== 'string')
            return;
        const prunePaths = rawPrunePaths !== '' ? safe.String_split.call(rawPrunePaths, / +/) : [];
        const needlePaths = prunePaths.length !== 0 && rawNeedlePaths !== ''
            ? safe.String_split.call(rawNeedlePaths, / +/)
            : [];
        if (stackNeedleDetails.matchAll !== true && matchesStackTrace(stackNeedleDetails) === false)
            return;
        if (prunePaths.length === 0)
            return;
        for (const needlePath of needlePaths) {
            if (objectFindOwner(obj, needlePath) === false)
                return;
        }
        let matched = false;
        for (const path of prunePaths) {
            if (objectFindOwner(obj, path, true))
                matched = true;
        }
        if (matched)
            return obj;
    }

    // Respuesta nueva con otro cuerpo y los datos de la original
    function cloneResponse(responseBefore, responseAfter) {
        Object.defineProperties(responseAfter, {
            ok: { value: responseBefore.ok },
            redirected: { value: responseBefore.redirected },
            type: { value: responseBefore.type },
            url: { value: responseBefore.url },
        });
        return responseAfter;
    }

    // ── set-constant ─────────────────────────────────────────────────
    // Fija una propiedad («a.b.c») a un valor, también si aún no existe:
    // se esperan los objetos de la ruta y se fija al crearse
    function setConstantFn(trusted = false, chain = '', rawValue = '', ...varargs) {
        if (chain === '')
            return;
        const extraArgs = safe.parseVarargs(varargs);
        function setConstant(chain, rawValue) {
            const trappedProp = (() => {
                const pos = chain.lastIndexOf('.');
                if (pos === -1)
                    return chain;
                return chain.slice(pos + 1);
            })();
            const cloakFunc = fn => {
                safe.Object_defineProperty(fn, 'name', { value: trappedProp });
                return new Proxy(fn, {
                    defineProperty(target, prop) {
                        if (prop !== 'toString')
                            return Reflect.defineProperty(...arguments);
                        return true;
                    },
                    deleteProperty(target, prop) {
                        if (prop !== 'toString')
                            return Reflect.deleteProperty(...arguments);
                        return true;
                    },
                    get(target, prop) {
                        if (prop === 'toString') {
                            return function () {
                                return `function ${trappedProp}() { [native code] }`;
                            }.bind(null);
                        }
                        return Reflect.get(...arguments);
                    },
                });
            };
            if (trappedProp === '')
                return;
            const thisScript = document.currentScript;
            let normalValue = validateConstant(trusted, rawValue, extraArgs);
            if (rawValue === 'noopFunc' || rawValue === 'trueFunc' || rawValue === 'falseFunc')
                normalValue = cloakFunc(normalValue);
            let aborted = false;
            // Si la página pone un valor de otro tipo, se la deja
            const mustAbort = function (v) {
                if (trusted)
                    return false;
                if (aborted)
                    return true;
                aborted = (v !== undefined && v !== null)
                    && (normalValue !== undefined && normalValue !== null)
                    && (typeof v !== typeof normalValue);
                return aborted;
            };
            const trapProp = function (owner, prop, configurable, handler) {
                if (handler.init(configurable ? owner[prop] : normalValue) === false)
                    return;
                const odesc = safe.Object_getOwnPropertyDescriptor(owner, prop);
                let prevGetter, prevSetter;
                if (odesc instanceof safe.Object) {
                    owner[prop] = normalValue;
                    if (odesc.get instanceof Function)
                        prevGetter = odesc.get;
                    if (odesc.set instanceof Function)
                        prevSetter = odesc.set;
                }
                try {
                    safe.Object_defineProperty(owner, prop, {
                        configurable,
                        get() {
                            if (prevGetter !== undefined)
                                prevGetter();
                            return handler.getter();
                        },
                        set(a) {
                            if (prevSetter !== undefined)
                                prevSetter(a);
                            handler.setter(a);
                        },
                    });
                } catch {
                }
            };
            const trapChain = function (owner, chain) {
                const pos = chain.indexOf('.');
                if (pos === -1) {
                    trapProp(owner, chain, false, {
                        v: undefined,
                        init: function (v) {
                            if (mustAbort(v))
                                return false;
                            this.v = v;
                            return true;
                        },
                        getter: function () {
                            if (document.currentScript === thisScript)
                                return this.v;
                            return normalValue;
                        },
                        setter: function (a) {
                            if (mustAbort(a) === false)
                                return;
                            normalValue = a;
                        },
                    });
                    return;
                }
                const prop = chain.slice(0, pos);
                const v = owner[prop];
                chain = chain.slice(pos + 1);
                if (v instanceof safe.Object || (typeof v === 'object' && v !== null)) {
                    trapChain(v, chain);
                    return;
                }
                trapProp(owner, prop, true, {
                    v: undefined,
                    init: function (v) {
                        this.v = v;
                        return true;
                    },
                    getter: function () {
                        return this.v;
                    },
                    setter: function (a) {
                        this.v = a;
                        if (a instanceof safe.Object)
                            trapChain(a, chain);
                    },
                });
            };
            trapChain(window, chain);
        }
        runAt(() => {
            setConstant(chain, rawValue);
        }, extraArgs.runAt);
    }

    // ── abort-… ──────────────────────────────────────────────────────
    function abortOnPropertyRead(chain = '') {
        if (typeof chain !== 'string' || chain === '')
            return;
        const exceptionToken = getExceptionToken();
        const abort = function () {
            throw new ReferenceError(exceptionToken);
        };
        const makeProxy = function (owner, chain) {
            const pos = chain.indexOf('.');
            if (pos === -1) {
                const desc = Object.getOwnPropertyDescriptor(owner, chain);
                if (!desc || desc.get !== abort)
                    Object.defineProperty(owner, chain, { get: abort, set: function () {} });
                return;
            }
            const prop = chain.slice(0, pos);
            let v = owner[prop];
            chain = chain.slice(pos + 1);
            if (v) {
                makeProxy(v, chain);
                return;
            }
            const desc = Object.getOwnPropertyDescriptor(owner, prop);
            if (desc && desc.set !== undefined)
                return;
            Object.defineProperty(owner, prop, {
                get: function () { return v; },
                set: function (a) {
                    v = a;
                    if (a instanceof Object)
                        makeProxy(a, chain);
                },
            });
        };
        makeProxy(window, chain);
    }

    function abortOnPropertyWrite(prop = '') {
        if (typeof prop !== 'string' || prop === '')
            return;
        const exceptionToken = getExceptionToken();
        let owner = window;
        for (;;) {
            const pos = prop.indexOf('.');
            if (pos === -1)
                break;
            owner = owner[prop.slice(0, pos)];
            if (owner instanceof Object === false)
                return;
            prop = prop.slice(pos + 1);
        }
        delete owner[prop];
        Object.defineProperty(owner, prop, {
            set: function () {
                throw new ReferenceError(exceptionToken);
            },
        });
    }

    // Corta el script que lee o escribe `target` si su texto (o su
    // dirección, `context`) encaja
    function abortCurrentScriptFn(target = '', needle = '', context = '') {
        if (typeof target !== 'string' || target === '')
            return;
        const reNeedle = safe.patternToRegex(needle);
        const reContext = safe.patternToRegex(context);
        const thisScript = document.currentScript;
        const exceptionToken = getExceptionToken();
        const scriptTexts = new WeakMap();
        const textContentGetter = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent').get;
        const getScriptText = elem => {
            let text = textContentGetter.call(elem);
            if (text.trim() !== '')
                return text;
            if (scriptTexts.has(elem))
                return scriptTexts.get(elem);
            const [, mime, content] = /^data:([^,]*),(.+)$/.exec(elem.src.trim()) || ['', '', ''];
            try {
                text = mime.endsWith(';base64') ? self.atob(content) : self.decodeURIComponent(content);
            } catch {
            }
            scriptTexts.set(elem, text);
            return text;
        };
        const validate = () => {
            const e = document.currentScript;
            if (e instanceof HTMLScriptElement === false)
                return;
            if (e === thisScript)
                return;
            if (context !== '' && reContext.test(e.src) === false)
                return;
            const scriptText = getScriptText(e);
            if (reNeedle.test(scriptText) === false)
                return;
            throw new ReferenceError(exceptionToken);
        };
        let currentValue = trapProperty(target, {
            get: function () {
                validate();
                return currentValue;
            },
            set: function (a) {
                validate();
                currentValue = a;
            },
        }, { canThrow: true });
    }

    function abortCurrentScript(...args) {
        runAtHtmlElement(() => {
            abortCurrentScriptFn(...args);
        });
    }

    function abortOnStackTrace(chain = '', needle = '') {
        if (typeof chain !== 'string')
            return;
        const needleDetails = safe.initPattern(needle, { canNegate: true });
        const makeProxy = function (owner, chain) {
            const pos = chain.indexOf('.');
            if (pos === -1) {
                let v = owner[chain];
                Object.defineProperty(owner, chain, {
                    get: function () {
                        if (matchesStackTrace(needleDetails))
                            throw new ReferenceError(getExceptionToken());
                        return v;
                    },
                    set: function (a) {
                        if (matchesStackTrace(needleDetails))
                            throw new ReferenceError(getExceptionToken());
                        v = a;
                    },
                });
                return;
            }
            const prop = chain.slice(0, pos);
            let v = owner[prop];
            chain = chain.slice(pos + 1);
            if (v) {
                makeProxy(v, chain);
                return;
            }
            const desc = Object.getOwnPropertyDescriptor(owner, prop);
            if (desc && desc.set !== undefined)
                return;
            Object.defineProperty(owner, prop, {
                get: function () { return v; },
                set: function (a) {
                    v = a;
                    if (a instanceof Object)
                        makeProxy(a, chain);
                },
            });
        };
        makeProxy(window, chain);
    }

    // ── json-prune y compañía: quitar propiedades de los datos ───────
    function jsonPrune(rawPrunePaths = '', rawNeedlePaths = '', stackNeedle = '') {
        const stackNeedleDetails = safe.initPattern(stackNeedle, { canNegate: true });
        proxyApply('JSON.parse', function (context) {
            const objBefore = context.reflect();
            const objAfter = objectPrune(objBefore, rawPrunePaths, rawNeedlePaths, stackNeedleDetails);
            return objAfter === undefined ? objBefore : objAfter;
        });
        // También los datos de fetch(…).json(), que no pasan por JSON.parse
        proxyApply('Response.prototype.json', function (context) {
            const promise = context.reflect();
            return promise.then(objBefore => {
                const objAfter = objectPrune(objBefore, rawPrunePaths, rawNeedlePaths, stackNeedleDetails);
                return objAfter === undefined ? objBefore : objAfter;
            });
        });
    }

    function jsonPruneFetchResponse(rawPrunePaths = '', rawNeedlePaths = '', ...varargs) {
        const extraArgs = safe.parseVarargs(varargs);
        const propNeedles = parsePropertiesToMatch(extraArgs.propsToMatch, 'url');
        const stackNeedle = safe.initPattern(extraArgs.stackToMatch || '', { canNegate: true });
        if (rawPrunePaths === '')
            return;
        const applyHandler = function (target, thisArg, args) {
            const fetchPromise = Reflect.apply(target, thisArg, args);
            if (propNeedles.size !== 0) {
                const props = collateFetchArguments(...args);
                if (matchObjectProperties(propNeedles, props) === undefined)
                    return fetchPromise;
            }
            return fetchPromise.then(responseBefore => {
                const response = responseBefore.clone();
                return response.json().then(objBefore => {
                    if (typeof objBefore !== 'object')
                        return responseBefore;
                    const objAfter = objectPrune(objBefore, rawPrunePaths, rawNeedlePaths, stackNeedle);
                    if (typeof objAfter !== 'object')
                        return responseBefore;
                    return cloneResponse(responseBefore, Response.json(objAfter, {
                        status: responseBefore.status,
                        statusText: responseBefore.statusText,
                        headers: responseBefore.headers,
                    }));
                }).catch(() => responseBefore);
            }).catch(() => fetchPromise);
        };
        const fetchProxy = new Proxy(self.fetch, { apply: applyHandler });
        proxyToString(fetchProxy, self.fetch);
        self.fetch = fetchProxy;
    }

    // XMLHttpRequest cuya respuesta pasa por `modify(texto u objeto)`, solo
    // en las peticiones que encajan con propsToMatch
    function trapXhrResponse(propsToMatch, modify) {
        const xhrInstances = new WeakMap();
        const propNeedles = parsePropertiesToMatch(propsToMatch, 'url');
        const NativeXhr = self.XMLHttpRequest;
        const TrappedXhr = class XMLHttpRequest extends NativeXhr {
            open(method, url, ...args) {
                const xhrDetails = { method, url };
                if (propNeedles.size === 0 || matchObjectProperties(propNeedles, xhrDetails) !== undefined)
                    xhrInstances.set(this, xhrDetails);
                return super.open(method, url, ...args);
            }
            get response() {
                const innerResponse = super.response;
                const xhrDetails = xhrInstances.get(this);
                if (xhrDetails === undefined)
                    return innerResponse;
                const responseLength = typeof innerResponse === 'string' ? innerResponse.length : undefined;
                if (xhrDetails.lastResponseLength !== responseLength) {
                    xhrDetails.response = undefined;
                    xhrDetails.lastResponseLength = responseLength;
                }
                if (xhrDetails.response !== undefined)
                    return xhrDetails.response;
                let outer = innerResponse;
                try {
                    outer = modify(innerResponse);
                } catch {
                }
                return (xhrDetails.response = outer);
            }
            get responseText() {
                const response = this.response;
                return typeof response !== 'string' ? super.responseText : response;
            }
        };
        proxyToString(TrappedXhr, NativeXhr);
        proxyToString(TrappedXhr.prototype.open, NativeXhr.prototype.open);
        self.XMLHttpRequest = TrappedXhr;
    }

    function jsonPruneXhrResponse(rawPrunePaths = '', rawNeedlePaths = '', ...varargs) {
        const extraArgs = safe.parseVarargs(varargs);
        const stackNeedle = safe.initPattern(extraArgs.stackToMatch || '', { canNegate: true });
        trapXhrResponse(extraArgs.propsToMatch, innerResponse => {
            let objBefore;
            if (typeof innerResponse === 'object') {
                objBefore = innerResponse;
            } else if (typeof innerResponse === 'string') {
                try {
                    objBefore = safe.JSON_parse(innerResponse);
                } catch {
                }
            }
            if (typeof objBefore !== 'object')
                return innerResponse;
            const objAfter = objectPrune(objBefore, rawPrunePaths, rawNeedlePaths, stackNeedle);
            if (typeof objAfter !== 'object')
                return innerResponse;
            return typeof innerResponse === 'string' ? safe.JSON_stringify(objAfter) : objAfter;
        });
    }

    // Argumento `argPos` (desde 1) de la función `entryPoint`
    function trustedPruneInboundObject(entryPoint = '', argPos = '', rawPrunePaths = '', rawNeedlePaths = '', ...varargs) {
        if (entryPoint === '')
            return;
        let context = globalThis;
        let prop = entryPoint;
        for (;;) {
            const pos = prop.indexOf('.');
            if (pos === -1)
                break;
            context = context[prop.slice(0, pos)];
            if (context instanceof Object === false)
                return;
            prop = prop.slice(pos + 1);
        }
        if (typeof context[prop] !== 'function')
            return;
        const argIndex = parseInt(argPos);
        if (isNaN(argIndex) || argIndex < 1)
            return;
        const extraArgs = safe.parseVarargs(varargs);
        const needlePaths = [];
        if (rawPrunePaths !== '')
            needlePaths.push(...safe.String_split.call(rawPrunePaths, / +/));
        if (rawNeedlePaths !== '')
            needlePaths.push(...safe.String_split.call(rawNeedlePaths, / +/));
        const stackNeedle = safe.initPattern(extraArgs.stackToMatch || '', { canNegate: true });
        const mustProcess = root => {
            for (const needlePath of needlePaths) {
                if (objectFindOwner(root, needlePath) === false)
                    return false;
            }
            return true;
        };
        proxyApply(entryPoint, function (context) {
            const args = context.callArgs;
            const targetArg = argIndex <= args.length ? args[argIndex - 1] : undefined;
            if (targetArg instanceof Object && mustProcess(targetArg)) {
                let objBefore = targetArg;
                if (extraArgs.dontOverwrite) {
                    try {
                        objBefore = safe.JSON_parse(safe.JSON_stringify(targetArg));
                    } catch {
                        objBefore = undefined;
                    }
                }
                if (objBefore !== undefined) {
                    const objAfter = objectPrune(objBefore, rawPrunePaths, rawNeedlePaths, stackNeedle);
                    args[argIndex - 1] = objAfter || objBefore;
                }
            }
            return context.reflect();
        });
    }

    function trustedPruneOutboundObject(propChain = '', rawPrunePaths = '', rawNeedlePaths = '') {
        if (propChain === '')
            return;
        proxyApply(propChain, function (context) {
            const objBefore = context.reflect();
            if (objBefore instanceof Object === false)
                return objBefore;
            return objectPrune(objBefore, rawPrunePaths, rawNeedlePaths) || objBefore;
        });
    }

    // ── json-edit y compañía: consultas JSONPath (clase al final) ────
    // Sin `trusted`, la consulta solo puede quitar (no asignar valores)
    function compileJsonPath(trusted, jsonq) {
        const jsonp = JSONPath.create(jsonq);
        if (jsonp.valid === false || (jsonp.value !== undefined && trusted !== true))
            return;
        return jsonp;
    }

    function jsonEditFn(trusted, jsonq = '', ...varargs) {
        const jsonp = compileJsonPath(trusted, jsonq);
        if (jsonp === undefined)
            return;
        const extraArgs = safe.parseVarargs(varargs);
        const pattern = extraArgs.matches && safe.initPattern(extraArgs.matches);
        proxyApply('JSON.parse', function (context) {
            const json = context.callArgs[0];
            const obj = context.reflect();
            if (pattern && typeof json === 'string' && safe.testPattern(pattern, json) === false)
                return obj;
            const objAfter = jsonp.apply(obj);
            return objAfter === undefined ? obj : objAfter;
        });
    }

    function jsonEditFetchResponseFn(trusted, jsonq = '', ...varargs) {
        const jsonp = compileJsonPath(trusted, jsonq);
        if (jsonp === undefined)
            return;
        const extraArgs = safe.parseVarargs(varargs);
        const propNeedles = parsePropertiesToMatch(extraArgs.propsToMatch, 'url');
        proxyApply('fetch', function (context) {
            const args = context.callArgs;
            const fetchPromise = context.reflect();
            if (propNeedles.size !== 0) {
                const props = collateFetchArguments(...args);
                if (matchObjectProperties(propNeedles, props) === undefined)
                    return fetchPromise;
            }
            return fetchPromise.then(responseBefore => {
                const response = responseBefore.clone();
                return response.json().then(obj => {
                    if (typeof obj !== 'object')
                        return responseBefore;
                    const objAfter = jsonp.apply(obj);
                    if (objAfter === undefined)
                        return responseBefore;
                    return cloneResponse(responseBefore, Response.json(objAfter, {
                        status: responseBefore.status,
                        statusText: responseBefore.statusText,
                        headers: responseBefore.headers,
                    }));
                }).catch(() => responseBefore);
            }).catch(() => fetchPromise);
        });
    }

    function jsonEditXhrResponseFn(trusted, jsonq = '', ...varargs) {
        const jsonp = compileJsonPath(trusted, jsonq);
        if (jsonp === undefined)
            return;
        const extraArgs = safe.parseVarargs(varargs);
        trapXhrResponse(extraArgs.propsToMatch, innerResponse => {
            let obj;
            if (typeof innerResponse === 'object') {
                obj = innerResponse;
            } else if (typeof innerResponse === 'string') {
                try {
                    obj = safe.JSON_parse(innerResponse);
                } catch {
                }
            }
            if (typeof obj !== 'object' || obj === null)
                return innerResponse;
            const objAfter = jsonp.apply(obj);
            if (objAfter === undefined)
                return innerResponse;
            return typeof innerResponse === 'string' ? JSONPath.toJSON(objAfter, safe.JSON_stringify) : objAfter;
        });
    }

    // Edita (una copia de) el argumento `argPosRaw` (desde 0; negativo, desde
    // el final) de la función `propChain`: YouTube, JSON.stringify
    function editInboundObjectFn(trusted, propChain = '', argPosRaw = '', jsonq = '') {
        if (propChain === '')
            return;
        const jsonp = compileJsonPath(trusted, jsonq);
        if (jsonp === undefined)
            return;
        const argPos = parseInt(argPosRaw, 10);
        if (isNaN(argPos))
            return;
        const getArgPos = args => {
            if (Array.isArray(args) === false)
                return;
            if (argPos >= 0)
                return args.length <= argPos ? undefined : argPos;
            return args.length < -argPos ? undefined : args.length + argPos;
        };
        const editObj = obj => {
            let clone;
            try {
                clone = safe.structuredClone(obj);
            } catch {
            }
            if (typeof clone !== 'object' || clone === null)
                return;
            return jsonp.apply(clone);
        };
        proxyApply(propChain, function (context) {
            const i = getArgPos(context.callArgs);
            if (i !== undefined) {
                const objBefore = context.callArgs[i];
                if (typeof objBefore === 'object') {
                    const objAfter = editObj(objBefore);
                    if (objAfter)
                        context.callArgs[i] = objAfter;
                }
            }
            return context.reflect();
        });
    }

    // ── Temporizadores ───────────────────────────────────────────────
    // «100», «100-500», «-500», «100-», con «!» delante para invertir
    class RangeParser {
        constructor(s) {
            this.not = s.charAt(0) === '!';
            if (this.not)
                s = s.slice(1);
            if (s === '')
                return;
            const pos = s.indexOf('-');
            if (pos !== 0)
                this.min = this.max = parseInt(s, 10) || 0;
            if (pos !== -1)
                this.max = parseInt(s.slice(pos + 1), 10) || Number.MAX_SAFE_INTEGER;
        }
        unbound() {
            return this.min === undefined && this.max === undefined;
        }
        test(v) {
            const n = Math.min(Math.max(Number(v) || 0, 0), Number.MAX_SAFE_INTEGER);
            if (this.min === this.max)
                return (this.min === undefined || n === this.min) !== this.not;
            if (this.min === undefined)
                return (n <= this.max) !== this.not;
            if (this.max === undefined)
                return (n >= this.min) !== this.not;
            return (n >= this.min && n <= this.max) !== this.not;
        }
    }

    // La función que se programa no hace nada si su código y su espera encajan
    function preventTimer(timer, needleRaw = '', delayRaw = '') {
        const needleNot = needleRaw.charAt(0) === '!';
        const reNeedle = safe.patternToRegex(needleNot ? needleRaw.slice(1) : needleRaw);
        const range = new RangeParser(delayRaw);
        proxyApply(timer, function (context) {
            const { callArgs } = context;
            const a = callArgs[0] instanceof Function
                ? safe.String(safe.Function_toString(callArgs[0]))
                : safe.String(callArgs[0]);
            const b = callArgs[1];
            if (needleRaw === '' && range.unbound())
                return context.reflect();
            if (reNeedle.test(a) !== needleNot && range.test(b))
                callArgs[0] = function () {};
            return context.reflect();
        });
    }

    function preventRequestAnimationFrame(needleRaw = '') {
        const needleNot = needleRaw.charAt(0) === '!';
        const reNeedle = safe.patternToRegex(needleNot ? needleRaw.slice(1) : needleRaw);
        proxyApply('requestAnimationFrame', function (context) {
            const { callArgs } = context;
            const a = callArgs[0] instanceof Function
                ? safe.String(safe.Function_toString(callArgs[0]))
                : safe.String(callArgs[0]);
            if (needleRaw !== '' && reNeedle.test(a) !== needleNot)
                callArgs[0] = function () {};
            return context.reflect();
        });
    }

    // Acelera (o frena) las esperas cuyo código encaja: cuentas atrás
    function adjustTimer(timer, needleArg = '', delayArg = '', boostArg = '') {
        if (typeof needleArg !== 'string')
            return;
        const reNeedle = safe.patternToRegex(needleArg);
        let delay = delayArg !== '*' ? parseInt(delayArg, 10) : -1;
        if (isNaN(delay) || isFinite(delay) === false)
            delay = 1000;
        let boost = parseFloat(boostArg);
        boost = isNaN(boost) === false && isFinite(boost) ? Math.min(Math.max(boost, 0.001), 50) : 0.05;
        proxyApply(timer, function (context) {
            const { callArgs } = context;
            const [a, b] = callArgs;
            if ((delay === -1 || b === delay) && reNeedle.test(safe.String(a instanceof Function ? safe.Function_toString(a) : a)))
                callArgs[1] = b * boost;
            return context.reflect();
        });
    }

    // ── Peticiones ───────────────────────────────────────────────────
    function preventFetchFn(trusted = false, propsToMatch = '', responseBody = '', responseType = '', ...varargs) {
        const setTimeout = self.setTimeout;
        const extraArgs = safe.parseVarargs(varargs);
        const propNeedles = parsePropertiesToMatch(propsToMatch, 'url');
        const validResponseProps = {
            ok: [false, true],
            status: [403],
            statusText: ['', 'Not Found'],
            type: ['basic', 'cors', 'default', 'error', 'opaque'],
        };
        const responseProps = { statusText: { value: 'OK' } };
        const responseHeaders = {};
        if (/^\{.*\}$/.test(responseType)) {
            try {
                Object.entries(JSON.parse(responseType)).forEach(([p, v]) => {
                    if (p === 'headers' && trusted) {
                        Object.assign(responseHeaders, v);
                        return;
                    }
                    if (validResponseProps[p] === undefined || validResponseProps[p].includes(v) === false)
                        return;
                    responseProps[p] = { value: v };
                });
            } catch {
            }
        } else if (responseType !== '' && validResponseProps.type.includes(responseType)) {
            responseProps.type = { value: responseType };
        }
        proxyApply('fetch', function fetch(context) {
            const { callArgs } = context;
            if (propsToMatch === '' && responseBody === '')
                return context.reflect();
            const details = collateFetchArguments(...callArgs);
            const matched = matchObjectProperties(propNeedles, details);
            if (matched === undefined || matched.length === 0)
                return context.reflect();
            return Promise.resolve(generateContent(trusted, responseBody)).then(text => {
                const headers = Object.assign({}, responseHeaders);
                if (headers['content-length'] === undefined)
                    headers['content-length'] = text.length;
                const response = new Response(text, { headers });
                safe.Object_defineProperties(response, Object.assign({ url: { value: details.url } }, responseProps));
                if (extraArgs.throttle)
                    return new Promise(resolve => setTimeout(() => resolve(response), extraArgs.throttle));
                return response;
            });
        });
    }

    function preventXhrFn(trusted = false, propsToMatch = '', directive = '') {
        if (typeof propsToMatch !== 'string')
            return;
        const xhrInstances = new WeakMap();
        const propNeedles = parsePropertiesToMatch(propsToMatch, 'url');
        const safeDispatchEvent = (xhr, type) => {
            try {
                xhr.dispatchEvent(new Event(type));
            } catch {
            }
        };
        proxyApply('XMLHttpRequest.prototype.open', function (context) {
            const { thisArg, callArgs } = context;
            xhrInstances.delete(thisArg);
            const [method, url, ...args] = callArgs;
            const haystack = { method, url };
            if (propsToMatch === '' && directive === '')
                return context.reflect();
            if (matchObjectProperties(propNeedles, haystack)) {
                xhrInstances.set(thisArg, Object.assign(haystack, {
                    xhr: thisArg,
                    defer: args.length === 0 || !!args[0],
                    directive,
                    headers: { 'date': '', 'content-type': '', 'content-length': '' },
                    url: haystack.url,
                    props: {
                        response: { value: '' },
                        responseText: { value: '' },
                        responseXML: { value: null },
                    },
                }));
            }
            return context.reflect();
        });
        proxyApply('XMLHttpRequest.prototype.send', function (context) {
            const { thisArg } = context;
            const xhrDetails = xhrInstances.get(thisArg);
            if (xhrDetails === undefined)
                return context.reflect();
            xhrDetails.headers['date'] = (new Date()).toUTCString();
            let xhrText = '';
            switch (thisArg.responseType) {
            case 'arraybuffer':
                xhrDetails.props.response.value = new ArrayBuffer(0);
                xhrDetails.headers['content-type'] = 'application/octet-stream';
                break;
            case 'blob':
                xhrDetails.props.response.value = new Blob([]);
                xhrDetails.headers['content-type'] = 'application/octet-stream';
                break;
            case 'document': {
                const doc = new DOMParser().parseFromString('', 'text/html');
                xhrDetails.props.response.value = doc;
                xhrDetails.props.responseXML.value = doc;
                xhrDetails.headers['content-type'] = 'text/html';
                break;
            }
            case 'json':
                xhrDetails.props.response.value = {};
                xhrDetails.props.responseText.value = '{}';
                xhrDetails.headers['content-type'] = 'application/json';
                break;
            default: {
                if (directive === '')
                    break;
                xhrText = generateContent(trusted, xhrDetails.directive);
                if (xhrText instanceof Promise) {
                    xhrText = xhrText.then(text => {
                        xhrDetails.props.response.value = text;
                        xhrDetails.props.responseText.value = text;
                    });
                } else {
                    xhrDetails.props.response.value = xhrText;
                    xhrDetails.props.responseText.value = xhrText;
                }
                xhrDetails.headers['content-type'] = 'text/plain';
                break;
            }
            }
            if (xhrDetails.defer === false) {
                xhrDetails.headers['content-length'] = `${xhrDetails.props.response.value}`.length;
                Object.defineProperties(xhrDetails.xhr, {
                    readyState: { value: 4 },
                    responseURL: { value: xhrDetails.url },
                    status: { value: 200 },
                    statusText: { value: 'OK' },
                });
                Object.defineProperties(xhrDetails.xhr, xhrDetails.props);
                return;
            }
            // Los pasos de una petición de verdad, con sus eventos
            Promise.resolve(xhrText).then(() => xhrDetails).then(details => {
                Object.defineProperties(details.xhr, {
                    readyState: { value: 1, configurable: true },
                    responseURL: { value: xhrDetails.url },
                });
                safeDispatchEvent(details.xhr, 'readystatechange');
                return details;
            }).then(details => {
                xhrDetails.headers['content-length'] = `${details.props.response.value}`.length;
                Object.defineProperties(details.xhr, {
                    readyState: { value: 2, configurable: true },
                    status: { value: 200 },
                    statusText: { value: 'OK' },
                });
                safeDispatchEvent(details.xhr, 'readystatechange');
                return details;
            }).then(details => {
                Object.defineProperties(details.xhr, { readyState: { value: 3, configurable: true } });
                Object.defineProperties(details.xhr, details.props);
                safeDispatchEvent(details.xhr, 'readystatechange');
                return details;
            }).then(details => {
                Object.defineProperties(details.xhr, { readyState: { value: 4 } });
                safeDispatchEvent(details.xhr, 'readystatechange');
                safeDispatchEvent(details.xhr, 'load');
                safeDispatchEvent(details.xhr, 'loadend');
            });
        });
        proxyApply('XMLHttpRequest.prototype.getResponseHeader', function (context) {
            const { thisArg } = context;
            const xhrDetails = xhrInstances.get(thisArg);
            if (xhrDetails === undefined || thisArg.readyState < thisArg.HEADERS_RECEIVED)
                return context.reflect();
            const value = xhrDetails.headers[`${context.callArgs[0]}`.toLowerCase()];
            return value !== undefined && value !== '' ? value : null;
        });
        proxyApply('XMLHttpRequest.prototype.getAllResponseHeaders', function (context) {
            const { thisArg } = context;
            const xhrDetails = xhrInstances.get(thisArg);
            if (xhrDetails === undefined || thisArg.readyState < thisArg.HEADERS_RECEIVED)
                return context.reflect();
            const out = [];
            for (const [name, value] of Object.entries(xhrDetails.headers)) {
                if (value)
                    out.push(`${name}: ${value}`);
            }
            if (out.length !== 0)
                out.push('');
            return out.join('\r\n');
        });
    }

    // Cambia el texto de las respuestas de fetch (expresión o texto → reemplazo)
    function trustedReplaceFetchResponse(pattern = '', replacement = '', propsToMatch = '', ...varargs) {
        if (pattern === '*')
            pattern = '.*';
        if (pattern === '')
            return;
        const rePattern = safe.patternToRegex(pattern);
        const propNeedles = parsePropertiesToMatch(propsToMatch, 'url');
        const extraArgs = safe.parseVarargs(varargs);
        const reIncludes = extraArgs.includes ? safe.patternToRegex(extraArgs.includes) : null;
        const fetchProxy = new Proxy(self.fetch, {
            apply: function (target, thisArg, args) {
                const fetchPromise = Reflect.apply(target, thisArg, args);
                if (propNeedles.size !== 0) {
                    const props = collateFetchArguments(...args);
                    if (matchObjectProperties(propNeedles, props) === undefined)
                        return fetchPromise;
                }
                return fetchPromise.then(responseBefore => {
                    const response = responseBefore.clone();
                    return response.text().then(textBefore => {
                        if (reIncludes && reIncludes.test(textBefore) === false)
                            return responseBefore;
                        const textAfter = textBefore.replace(rePattern, replacement);
                        if (textAfter === textBefore)
                            return responseBefore;
                        return cloneResponse(responseBefore, new Response(textAfter, {
                            status: responseBefore.status,
                            statusText: responseBefore.statusText,
                            headers: responseBefore.headers,
                        }));
                    }).catch(() => responseBefore);
                }).catch(() => fetchPromise);
            },
        });
        proxyToString(fetchProxy, self.fetch);
        self.fetch = fetchProxy;
    }

    function trustedReplaceXhrResponse(pattern = '', replacement = '', propsToMatch = '', ...varargs) {
        if (pattern === '*')
            pattern = '.*';
        const rePattern = safe.patternToRegex(pattern);
        const extraArgs = safe.parseVarargs(varargs);
        const reIncludes = extraArgs.includes ? safe.patternToRegex(extraArgs.includes) : null;
        trapXhrResponse(propsToMatch, innerResponse => {
            if (typeof innerResponse !== 'string')
                return innerResponse;
            if (reIncludes && reIncludes.test(innerResponse) === false)
                return innerResponse;
            return innerResponse.replace(rePattern, replacement);
        });
    }

    // ── Eventos, atributos, clases ───────────────────────────────────
    function preventAddEventListener(type = '', pattern = '', ...varargs) {
        const extraArgs = safe.parseVarargs(varargs);
        const reType = safe.patternToRegex(type, undefined, true);
        const rePattern = safe.patternToRegex(pattern);
        const targetSelector = extraArgs.elements || undefined;
        const elementMatches = elem => {
            if (targetSelector === 'window')
                return elem === window;
            if (targetSelector === 'document')
                return elem === document;
            if (elem && elem.matches && elem.matches(targetSelector))
                return true;
            return Array.from(document.querySelectorAll(targetSelector)).includes(elem);
        };
        const shouldPrevent = (thisArg, type, handler) => {
            const matchesBoth = safe.RegExp_test(reType, type) && safe.RegExp_test(rePattern, handler);
            if (matchesBoth && targetSelector !== undefined && elementMatches(thisArg) === false)
                return false;
            return matchesBoth;
        };
        const proxyFn = function (context) {
            const { callArgs, thisArg } = context;
            let t, h;
            try {
                t = String(callArgs[0]);
                if (typeof callArgs[1] === 'function') {
                    h = String(safe.Function_toString(callArgs[1]));
                } else if (typeof callArgs[1] === 'object' && callArgs[1] !== null) {
                    if (typeof callArgs[1].handleEvent === 'function')
                        h = String(safe.Function_toString(callArgs[1].handleEvent));
                } else {
                    h = String(callArgs[1]);
                }
            } catch {
            }
            if ((type !== '' || pattern !== '') && shouldPrevent(thisArg, t, h))
                return;
            return context.reflect();
        };
        const protect = owner => {
            const { addEventListener } = owner;
            Object.defineProperty(owner, 'addEventListener', {
                set() {},
                get() { return addEventListener; },
            });
        };
        runAt(() => {
            proxyApply('EventTarget.prototype.addEventListener', proxyFn);
            if (extraArgs.protect)
                protect(EventTarget.prototype);
            if (Object.hasOwn(document, 'addEventListener')) {
                proxyApply('document.addEventListener', proxyFn);
                if (extraArgs.protect)
                    protect(document);
            }
            if (Object.hasOwn(window, 'addEventListener')) {
                proxyApply('window.addEventListener', proxyFn);
                if (extraArgs.protect)
                    protect(window);
            }
        }, extraArgs.runAt);
    }

    // Quita atributos («a|b») de los elementos del selector, también de los
    // que aparezcan después
    function removeAttr(rawToken = '', rawSelector = '', behavior = '', ...varargs) {
        if (typeof rawToken !== 'string' || rawToken === '')
            return;
        const tokens = safe.String_split.call(rawToken, /\s*\|\s*/);
        const selector = tokens.map(a => {
            const b = CSS.escape(a);
            return rawSelector.includes(`[${b}]`) ? rawSelector : `${rawSelector}[${b}]`;
        }).join(',');
        const lazily = /\basap\b/.test(behavior) === false;
        const options = safe.parseVarargs(varargs);
        const rmattrFromNode = node => {
            for (const attr of tokens) {
                if (node.hasAttribute(attr))
                    node.removeAttribute(attr);
            }
        };
        const rmattr = nodes => {
            try {
                for (const node of nodes ?? document.querySelectorAll(selector))
                    rmattrFromNode(node);
            } catch {
            }
        };
        const rmAttrLazily = () => {
            if (rmAttrLazily.timer !== undefined)
                return;
            rmAttrLazily.timer = onIdle(() => {
                rmAttrLazily.timer = undefined;
                rmattr();
            }, { timeout: 17 });
        };
        const mutationHandler = mutations => {
            for (const { addedNodes, removedNodes } of mutations) {
                for (const node of addedNodes) {
                    if (node.nodeType !== 1)
                        continue;
                    if (lazily)
                        return rmAttrLazily();
                    if (node.matches(selector))
                        rmattrFromNode(node);
                    if (node.childElementCount)
                        rmattr(node.querySelectorAll(selector));
                }
                if (lazily)
                    return;
                for (const node of removedNodes) {
                    if (node.nodeType === 1 && node.matches(selector))
                        rmattrFromNode(node);
                }
            }
        };
        const stop = () => {
            if (start.observer) {
                start.observer.disconnect();
                start.observer = undefined;
            }
            if (rmAttrLazily.timer) {
                offIdle(rmAttrLazily.timer);
                rmAttrLazily.timer = undefined;
            }
        };
        const start = () => {
            rmattr();
            if (/\bstay\b/.test(behavior) === false && options.quitAfter === undefined)
                return;
            start.observer = new MutationObserver(mutationHandler);
            start.observer.observe(document, {
                attributes: true,
                attributeFilter: tokens,
                childList: true,
                subtree: true,
            });
            if (options.quitAfter)
                runAt(() => self.setTimeout(stop, options.quitAfter * 1000), 'load');
        };
        runAt(() => start(), safe.String_split.call(behavior, /\s+/));
    }

    function removeClass(rawToken = '', rawSelector = '', behavior = '') {
        if (typeof rawToken !== 'string' || rawToken === '')
            return;
        const tokens = safe.String_split.call(rawToken, /\s*\|\s*/);
        const selector = tokens.map(a => `${rawSelector}.${CSS.escape(a)}`).join(',');
        const mustStay = /\bstay\b/.test(behavior);
        let timer;
        const rmclass = () => {
            timer = undefined;
            try {
                for (const node of document.querySelectorAll(selector))
                    node.classList.remove(...tokens);
            } catch {
            }
            if (mustStay || document.readyState !== 'complete')
                return;
            observer.disconnect();
        };
        const mutationHandler = mutations => {
            if (timer !== undefined)
                return;
            let skip = true;
            for (let i = 0; i < mutations.length && skip; i++) {
                const { type, addedNodes, removedNodes } = mutations[i];
                if (type === 'attributes')
                    skip = false;
                for (let j = 0; j < addedNodes.length && skip; j++) {
                    if (addedNodes[j].nodeType === 1)
                        skip = false;
                }
                for (let j = 0; j < removedNodes.length && skip; j++) {
                    if (removedNodes[j].nodeType === 1)
                        skip = false;
                }
            }
            if (skip)
                return;
            timer = onIdle(rmclass, { timeout: 67 });
        };
        const observer = new MutationObserver(mutationHandler);
        runAt(() => {
            rmclass();
            observer.observe(document, {
                attributes: true,
                attributeFilter: ['class'],
                childList: true,
                subtree: true,
            });
        }, /\bcomplete\b/.test(behavior) ? 'idle' : 'loading');
    }

    // ── Otros ────────────────────────────────────────────────────────
    function noEvalIf(needle = '') {
        if (typeof needle !== 'string')
            return;
        const reNeedle = safe.patternToRegex(needle);
        proxyApply('eval', function (context) {
            const { callArgs } = context;
            const a = String(callArgs[0]);
            if (needle !== '' && reNeedle.test(a))
                return;
            return context.reflect();
        });
    }

    // Ventanas emergentes (window.open) cuyo destino encaja; con `delay`, una
    // ventana falsa para que la página crea que se abrió
    function noWindowOpenIf(pattern = '', delay = '', decoy = '') {
        const targetMatchResult = pattern.startsWith('!') === false;
        if (targetMatchResult === false)
            pattern = pattern.slice(1);
        const rePattern = safe.patternToRegex(pattern);
        const autoRemoveAfter = (parseFloat(delay) || 0) * 1000;
        const setTimeout = self.setTimeout;
        const createDecoy = function (tag, urlProp, url) {
            const decoyElem = document.createElement(tag);
            decoyElem[urlProp] = url;
            decoyElem.style.setProperty('height', '1px', 'important');
            decoyElem.style.setProperty('position', 'fixed', 'important');
            decoyElem.style.setProperty('top', '-1px', 'important');
            decoyElem.style.setProperty('width', '1px', 'important');
            document.body.appendChild(decoyElem);
            setTimeout(() => decoyElem.remove(), autoRemoveAfter);
            return decoyElem;
        };
        const noopFunc = function () {};
        proxyApply('open', function open(context) {
            const { callArgs } = context;
            const haystack = callArgs.join(' ');
            if (rePattern.test(haystack) !== targetMatchResult)
                return context.reflect();
            if (delay === '')
                return null;
            if (decoy === 'blank') {
                callArgs[0] = 'about:blank';
                const r = context.reflect();
                setTimeout(() => r.close(), autoRemoveAfter);
                return r;
            }
            const decoyElem = decoy === 'obj'
                ? createDecoy('object', 'data', ...callArgs)
                : createDecoy('iframe', 'src', ...callArgs);
            let popup = decoyElem.contentWindow;
            if (typeof popup === 'object' && popup !== null) {
                Object.defineProperty(popup, 'closed', { value: false });
            } else {
                popup = new Proxy(self, {
                    get: function (target, prop, ...args) {
                        if (prop === 'closed')
                            return false;
                        const r = Reflect.get(target, prop, ...args);
                        return typeof r === 'function' ? noopFunc : r;
                    },
                    set: function (...args) {
                        return Reflect.set(...args);
                    },
                });
            }
            return popup;
        });
    }

    function noWebrtc() {
        const rtcName = window.RTCPeerConnection ? 'RTCPeerConnection'
            : (window.webkitRTCPeerConnection ? 'webkitRTCPeerConnection' : '');
        if (rtcName === '')
            return;
        const pc = function () {};
        const noop = function () {};
        pc.prototype = {
            close: noop,
            createDataChannel: noop,
            createOffer: noop,
            setRemoteDescription: noop,
            toString: function () {
                return '[object RTCPeerConnection]';
            },
        };
        const z = window[rtcName];
        window[rtcName] = pc.bind(window);
        if (z.prototype) {
            z.prototype.createDataChannel = function () {
                return { close: function () {}, send: function () {} };
            }.bind(null);
        }
    }

    // Cambia el texto de los nodos (scripts en línea, sobre todo) que encajan,
    // también los que el analizador añade mientras carga la página
    function replaceNodeTextFn(nodeName = '', pattern = '', replacement = '', ...varargs) {
        const reNodeName = safe.patternToRegex(nodeName, 'i', true);
        const rePattern = safe.patternToRegex(pattern, 'gms');
        const extraArgs = safe.parseVarargs(varargs);
        const reIncludes = extraArgs.includes || extraArgs.condition
            ? safe.patternToRegex(extraArgs.includes || extraArgs.condition, 'ms')
            : null;
        const reExcludes = extraArgs.excludes ? safe.patternToRegex(extraArgs.excludes, 'ms') : null;
        // Con Trusted Types, el texto de un script tiene que ser TrustedScript
        const textContentFactory = (() => {
            const out = { createScript: s => s };
            const { trustedTypes: tt } = self;
            if (tt instanceof Object && typeof tt.getPropertyType === 'function'
                && tt.getPropertyType('script', 'textContent') === 'TrustedScript')
                return tt.createPolicy(getRandomToken(), out);
            return out;
        })();
        let sedCount = extraArgs.sedCount ?? Number.MAX_SAFE_INTEGER;
        const handleNode = node => {
            const before = node.textContent;
            if (reIncludes) {
                reIncludes.lastIndex = 0;
                if (safe.RegExp_test(reIncludes, before) === false)
                    return;
            }
            if (reExcludes) {
                reExcludes.lastIndex = 0;
                if (safe.RegExp_test(reExcludes, before))
                    return;
            }
            rePattern.lastIndex = 0;
            if (safe.RegExp_test(rePattern, before) === false)
                return;
            rePattern.lastIndex = 0;
            const after = pattern !== '' ? before.replace(rePattern, replacement) : replacement;
            node.textContent = node.nodeName === 'SCRIPT' ? textContentFactory.createScript(after) : after;
            sedCount -= 1;
        };
        const handleTree = root => {
            const treeWalker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
            const { currentScript } = document;
            for (;;) {
                const node = treeWalker.nextNode();
                if (node === null)
                    break;
                if (node === currentScript)
                    continue;
                if (reNodeName.test(node.nodeName))
                    handleNode(node);
                else if (node.nodeName === 'TEMPLATE')
                    handleTree(node.content);
                else
                    continue;
                if (sedCount === 0)
                    break;
            }
        };
        if (document.documentElement)
            handleTree(document.documentElement);
        const stay = Boolean(extraArgs.stay);
        if (sedCount === 0 && stay === false)
            return;
        const stop = (takeRecord = true) => {
            const mutations = takeRecord ? observer.takeRecords() : [];
            observer.disconnect();
            handleMutations(mutations);
        };
        const handleMutations = mutations => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (reNodeName.test(node.nodeName))
                        handleNode(node);
                    else if (node.nodeName === 'TEMPLATE')
                        handleTree(node.content);
                    else
                        continue;
                    if (sedCount === 0)
                        return stop(false);
                }
            }
        };
        const observer = new MutationObserver(handleMutations);
        observer.observe(document, { childList: true, subtree: true });
        if (stay)
            return;
        runAt(() => {
            const quitAfter = extraArgs.quitAfter ?? 0;
            if (quitAfter === 0)
                return stop();
            setTimeout(() => stop(), quitAfter);
        }, 'interactive');
    }

    // Un marco nuevo (about:blank) no da a la página las funciones nativas
    // sin envolver (fetch, Request…): se le ponen las de esta ventana
    function trustedPreventDomBypass(methodPath = '', targetProp = '') {
        if (methodPath === '')
            return;
        proxyApply(methodPath, function (context) {
            const elems = new Set(context.callArgs.filter(e => e instanceof HTMLElement));
            const r = context.reflect();
            for (const elem of elems) {
                try {
                    if (`${elem.contentWindow}` !== '[object Window]')
                        continue;
                    if (elem.contentWindow.location.href !== 'about:blank'
                        && elem.contentWindow.location.href !== self.location.href)
                        continue;
                    if (targetProp !== '') {
                        for (let chain of targetProp.split(/\s+/)) {
                            let me = self, it = elem.contentWindow;
                            for (;;) {
                                const pos = chain.indexOf('.');
                                if (pos === -1)
                                    break;
                                const prop = chain.slice(0, pos);
                                me = me[prop];
                                it = it[prop];
                                chain = chain.slice(pos + 1);
                            }
                            it[chain] = me[chain];
                        }
                    } else {
                        Object.defineProperty(elem, 'contentWindow', { value: self });
                    }
                } catch {
                }
            }
            return r;
        });
    }

    // «/patrón/reemplazo/opciones» de trusted-replace-argument (repl:)
    class ArglistParser {
        constructor(separatorChar = ',', mustQuote = false) {
            this.separatorChar = this.actualSeparatorChar = separatorChar;
            this.separatorCode = this.actualSeparatorCode = separatorChar.charCodeAt(0);
            this.mustQuote = mustQuote;
            this.quoteBeg = 0; this.quoteEnd = 0;
            this.argBeg = 0; this.argEnd = 0;
            this.separatorBeg = 0; this.separatorEnd = 0;
            this.transform = false;
            this.failed = false;
            this.reWhitespaceStart = /^\s+/;
            this.reWhitespaceEnd = /(?:^|\S)(\s+)$/;
            this.reOddTrailingEscape = /(?:^|[^\\])(?:\\\\)*\\$/;
            this.reTrailingEscapeChars = /\\+$/;
        }
        nextArg(pattern, beg = 0) {
            const len = pattern.length;
            this.quoteBeg = beg + this.leftWhitespaceCount(pattern.slice(beg));
            this.failed = false;
            const qc = pattern.charCodeAt(this.quoteBeg);
            if (qc === 0x22 || qc === 0x27 || qc === 0x60) {
                this.indexOfNextArgSeparator(pattern, qc);
                if (this.argEnd !== len) {
                    this.quoteEnd = this.argEnd + 1;
                    this.separatorBeg = this.separatorEnd = this.quoteEnd;
                    this.separatorEnd += this.leftWhitespaceCount(pattern.slice(this.quoteEnd));
                    if (this.separatorEnd === len)
                        return this;
                    if (pattern.charCodeAt(this.separatorEnd) === this.separatorCode) {
                        this.separatorEnd += 1;
                        return this;
                    }
                }
            }
            this.indexOfNextArgSeparator(pattern, this.separatorCode);
            this.separatorBeg = this.separatorEnd = this.argEnd;
            if (this.separatorBeg < len)
                this.separatorEnd += 1;
            this.argEnd -= this.rightWhitespaceCount(pattern.slice(0, this.separatorBeg));
            this.quoteEnd = this.argEnd;
            if (this.mustQuote)
                this.failed = true;
            return this;
        }
        normalizeArg(s, char = '') {
            if (char === '')
                char = this.actualSeparatorChar;
            let out = '';
            let pos = 0;
            while ((pos = s.lastIndexOf(char)) !== -1) {
                out = s.slice(pos) + out;
                s = s.slice(0, pos);
                const match = this.reTrailingEscapeChars.exec(s);
                if (match === null)
                    continue;
                const tail = (match[0].length & 1) !== 0 ? match[0].slice(0, -1) : match[0];
                out = tail + out;
                s = s.slice(0, -match[0].length);
            }
            if (out === '')
                return s;
            return s + out;
        }
        leftWhitespaceCount(s) {
            const match = this.reWhitespaceStart.exec(s);
            return match === null ? 0 : match[0].length;
        }
        rightWhitespaceCount(s) {
            const match = this.reWhitespaceEnd.exec(s);
            return match === null ? 0 : match[1].length;
        }
        indexOfNextArgSeparator(pattern, separatorCode) {
            this.argBeg = this.argEnd = separatorCode !== this.separatorCode ? this.quoteBeg + 1 : this.quoteBeg;
            this.transform = false;
            if (separatorCode !== this.actualSeparatorCode) {
                this.actualSeparatorCode = separatorCode;
                this.actualSeparatorChar = String.fromCharCode(separatorCode);
            }
            while (this.argEnd < pattern.length) {
                const pos = pattern.indexOf(this.actualSeparatorChar, this.argEnd);
                if (pos === -1)
                    return (this.argEnd = pattern.length);
                if (this.reOddTrailingEscape.test(pattern.slice(0, pos)) === false)
                    return (this.argEnd = pos);
                this.transform = true;
                this.argEnd = pos + 1;
            }
        }
    }

    function parseReplace(s) {
        if (s.charCodeAt(0) !== 0x2F)
            return;
        const parser = new ArglistParser('/');
        parser.nextArg(s, 1);
        let pattern = s.slice(parser.argBeg, parser.argEnd);
        if (parser.transform)
            pattern = parser.normalizeArg(pattern);
        if (pattern === '')
            return;
        parser.nextArg(s, parser.separatorEnd);
        let replacement = s.slice(parser.argBeg, parser.argEnd);
        if (parser.separatorEnd === parser.separatorBeg)
            return;
        if (parser.transform)
            replacement = parser.normalizeArg(replacement);
        const flags = s.slice(parser.separatorEnd);
        try {
            return { re: new RegExp(pattern, flags), replacement };
        } catch {
        }
    }

    function trustedReplaceArgument(propChain = '', argposRaw = '', argraw = '', ...varargs) {
        if (propChain === '' || argposRaw === '')
            return;
        const argoffset = parseInt(argposRaw, 10) || 0;
        const extraArgs = safe.parseVarargs(varargs);
        let replacer;
        if (argraw.startsWith('repl:/')) {
            const parsed = parseReplace(argraw.slice(5));
            if (parsed === undefined)
                return;
            replacer = arg => `${arg}`.replace(parsed.re, parsed.replacement);
        } else if (argraw.startsWith('add:')) {
            const delta = parseFloat(argraw.slice(4));
            if (isNaN(delta))
                return;
            replacer = arg => Number(arg) + delta;
        } else {
            const value = validateConstant(true, argraw, extraArgs);
            replacer = () => value;
        }
        const reCondition = extraArgs.condition ? safe.patternToRegex(`${extraArgs.condition}`) : /^/;
        const getArg = context => {
            if (argposRaw === 'this')
                return context.thisArg;
            const { callArgs } = context;
            const argpos = argoffset >= 0 ? argoffset : callArgs.length - argoffset;
            if (argpos < 0 || argpos >= callArgs.length)
                return;
            context.private = { argpos };
            return callArgs[argpos];
        };
        const setArg = (context, value) => {
            if (argposRaw === 'this') {
                if (value !== context.thisArg)
                    context.thisArg = value;
            } else if (context.private) {
                context.callArgs[context.private.argpos] = value;
            }
        };
        proxyApply(propChain, function (context) {
            const argBefore = getArg(context);
            if (extraArgs.condition !== undefined && safe.RegExp_test(reCondition, argBefore) === false)
                return context.reflect();
            const argAfter = replacer(argBefore);
            if (argAfter !== argBefore)
                setArg(context, argAfter);
            return context.reflect();
        });
    }

    // Cambia el texto que devuelve una función (JSON.stringify en YouTube)
    function trustedReplaceOutboundText(propChain = '', rawPattern = '', rawReplacement = '', ...varargs) {
        if (propChain === '' || rawPattern === '')
            return;
        const rePattern = safe.patternToRegex(rawPattern);
        const replacement = rawReplacement.startsWith('json:')
            ? safe.JSON_parse(rawReplacement.slice(5))
            : rawReplacement;
        const extraArgs = safe.parseVarargs(varargs);
        const reCondition = safe.patternToRegex(extraArgs.condition || '');
        proxyApply(propChain, function (context) {
            const encodedTextBefore = context.reflect();
            let textBefore = encodedTextBefore;
            if (extraArgs.encoding === 'base64') {
                try {
                    textBefore = self.atob(encodedTextBefore);
                } catch {
                    return encodedTextBefore;
                }
            }
            reCondition.lastIndex = 0;
            if (reCondition.test(textBefore) === false)
                return encodedTextBefore;
            const textAfter = textBefore.replace(rePattern, replacement);
            if (textAfter === textBefore)
                return encodedTextBefore;
            return extraArgs.encoding === 'base64' ? self.btoa(textAfter) : textAfter;
        });
    }

    // ── Los nombres que da C++ (FilterEngine, scriptletName) ─────────
    const scriptlets = {
        'set-constant': (...args) => setConstantFn(false, ...args),
        'trusted-set-constant': (...args) => setConstantFn(true, ...args),
        'abort-on-property-read': abortOnPropertyRead,
        'abort-on-property-write': abortOnPropertyWrite,
        'abort-current-script': abortCurrentScript,
        'abort-on-stack-trace': abortOnStackTrace,
        'json-prune': jsonPrune,
        'json-prune-fetch-response': jsonPruneFetchResponse,
        'json-prune-xhr-response': jsonPruneXhrResponse,
        'trusted-prune-inbound-object': trustedPruneInboundObject,
        'trusted-prune-outbound-object': trustedPruneOutboundObject,
        'json-edit': (...args) => jsonEditFn(false, ...args),
        'trusted-json-edit': (...args) => jsonEditFn(true, ...args),
        'json-edit-fetch-response': (...args) => jsonEditFetchResponseFn(false, ...args),
        'trusted-json-edit-fetch-response': (...args) => jsonEditFetchResponseFn(true, ...args),
        'json-edit-xhr-response': (...args) => jsonEditXhrResponseFn(false, ...args),
        'trusted-json-edit-xhr-response': (...args) => jsonEditXhrResponseFn(true, ...args),
        'edit-inbound-object': (...args) => editInboundObjectFn(false, ...args),
        'trusted-edit-inbound-object': (...args) => editInboundObjectFn(true, ...args),
        'prevent-setTimeout': (...args) => preventTimer('setTimeout', ...args),
        'prevent-setInterval': (...args) => preventTimer('setInterval', ...args),
        'prevent-requestAnimationFrame': preventRequestAnimationFrame,
        'adjust-setTimeout': (...args) => adjustTimer('setTimeout', ...args),
        'adjust-setInterval': (...args) => adjustTimer('setInterval', ...args),
        'prevent-fetch': (...args) => preventFetchFn(false, ...args),
        'trusted-prevent-fetch': (...args) => preventFetchFn(true, ...args),
        'prevent-xhr': (...args) => preventXhrFn(false, ...args),
        'trusted-prevent-xhr': (...args) => preventXhrFn(true, ...args),
        'prevent-addEventListener': preventAddEventListener,
        'remove-attr': removeAttr,
        'remove-class': removeClass,
        'noeval-if': noEvalIf,
        'prevent-window-open': noWindowOpenIf,
        'nowebrtc': noWebrtc,
        'remove-node-text': (nodeName, includes, ...extraArgs) =>
            replaceNodeTextFn(nodeName, '', '', 'includes', includes || '', ...extraArgs),
        'trusted-replace-node-text': replaceNodeTextFn,
        'trusted-replace-fetch-response': trustedReplaceFetchResponse,
        'trusted-replace-xhr-response': trustedReplaceXhrResponse,
        'trusted-prevent-dom-bypass': trustedPreventDomBypass,
        'trusted-replace-argument': trustedReplaceArgument,
        'trusted-replace-outbound-text': trustedReplaceOutboundText,
    };

    // ── JSONPath de uBlock Origin (src/js/jsonpath.js, sin cambios) ──
    // Consultas como «..itemSectionRenderer.contents.*[?.adSlotRenderer]» o
    // «[?.a][?.b*="x"].c+={"d":1}»: sin valor quitan lo que encuentran; con
    // «=valor», «+=objeto» o «=repl(…)» lo cambian.
    class JSONPath {
        static create(query) {
            const jsonp = new JSONPath();
            jsonp.compile(query);
            return jsonp;
        }
        static toJSON(obj, stringifier, ...args) {
            return (stringifier || JSON.stringify)(obj, ...args)
                .replace(/\//g, '\\/');
        }
        static keys = Object.keys;
        static entries = Object.entries;
        static hasOwn = Object.hasOwn;
        static Regex = RegExp;
        get value() {
            return this.#compiled && this.#compiled.rval;
        }
        set value(v) {
            if ( this.#compiled === undefined ) { return; }
            this.#compiled.rval = v;
        }
        get valid() {
            return this.#compiled !== undefined;
        }
        compile(query) {
            this.#compiled = undefined;
            this.v2 = query.startsWith('v2:');
            if ( this.v2 ) { query = query.slice(3); }
            const r = this.#compile(query, 0);
            if ( r === undefined ) { return; }
            if ( r.i !== query.length ) {
                let val;
                if ( query.startsWith('=', r.i) ) {
                    const match = this.#reRval.exec(query.slice(r.i));
                    if ( match ) {
                        r.modify = match[1];
                        val = match[2];
                    } else {
                        val = query.slice(r.i+1);
                    }
                } else if ( query.startsWith('+=', r.i) ) {
                    r.modify = '+';
                    val = query.slice(r.i+2);
                }
                try { r.rval = JSON.parse(val); }
                catch { return; }
            }
            r.v2 = this.v2;
            this.#compiled = r;
        }
        evaluate(root) {
            if ( this.valid === false ) { return []; }
            this.#root = { '$': root };
            const paths = this.#evaluate(this.#compiled.steps, []);
            this.#root = null;
            return paths;
        }
        apply(root) {
            if ( this.valid === false ) { return; }
            const { rval } = this.#compiled;
            this.#root = { '$': root };
            const paths = this.#evaluate(this.#compiled.steps, []);
            let i = paths.length
            if ( i === 0 ) { this.#root = null; return; }
            while ( i-- ) {
                const { obj, key } = this.#resolvePath(paths[i]);
                if ( obj === undefined ) { continue; }
                if ( rval !== undefined ) {
                    this.#modifyVal(obj, key);
                } else if ( Array.isArray(obj) && typeof key === 'number' ) {
                    obj.splice(key, 1);
                } else {
                    delete obj[key];
                }
            }
            const result = this.#root['$'] ?? null;
            this.#root = null;
            return result;
        }
        dump() {
            return JSON.stringify(this.#compiled);
        }
        toJSON(obj, ...args) {
            return JSONPath.toJSON(obj, null, ...args)
        }
        get [Symbol.toStringTag]() {
            return 'JSONPath';
        }
        #UNDEFINED = 0;
        #ROOT = 1;
        #CURRENT = 2;
        #CHILDREN = 3;
        #DESCENDANTS = 4;
        #QUANTIFIER = 5;
        #reUnquotedIdentifier = /^[A-Za-z_][\w]*|^\*/;
        #reExpr = /^\s*([!=^$*]=|[<>]=?)\s*(.+?)\]/;
        #reIndice = /^-?\d+/;
        #reRval = /^=([a-z]+)\((.+)\)$/;
        #reQuantifier = /^\{(\d+|\d+,\d+|\d+,|,\d+)\};\$/;
        #root;
        #compiled;
        #compile(query, i) {
            if ( query.length === 0 ) { return; }
            const steps = [];
            let c = query.charCodeAt(i);
            if ( c === 0x24 ) {
                steps.push({ mv: this.#ROOT });
                i += 1;
            } else if ( c === 0x40 ) {
                steps.push({ mv: this.#CURRENT });
                i += 1;
            } else {
                steps.push({ mv: i === 0 ? this.#ROOT : this.#CURRENT });
            }
            let mv = this.#UNDEFINED;
            for (;;) {
                if ( i === query.length ) { break; }
                c = query.charCodeAt(i);
                if ( c === 0x20 ) {
                    i += 1;
                    continue;
                }
                if ( c === 0x2E ) {
                    if ( mv !== this.#UNDEFINED ) { return; }
                    if ( query.startsWith('..', i) ) {
                        mv = this.#DESCENDANTS;
                        i += 2;
                    } else {
                        mv = this.#CHILDREN;
                        i += 1;
                    }
                    continue;
                }
                if ( c === 0x3B ) {
                    if ( query.startsWith(';$', i) === false ) { return; }
                    steps.push(
                        { mv: this.#QUANTIFIER, min: 1, max: 1e6 },
                        { mv: this.#ROOT }
                    );
                    i += 2;
                    mv = this.#UNDEFINED;
                    continue;
                }
                if ( c === 0x7B ) {
                    const match = this.#reQuantifier.exec(query.slice(i));
                    if ( match === null ) { return; }
                    const comma = match[1].indexOf(',');
                    let min, max;
                    if ( comma === -1 ) {
                        min = max = parseInt(match[1]);
                    } else {
                        min = parseInt(match[1].slice(0, comma)) || 0;
                        max = parseInt(match[1].slice(comma+1)) || 1e6;
                    }
                    steps.push(
                        { mv: this.#QUANTIFIER, min, max },
                        { mv: this.#ROOT }
                    );
                    i += match[0].length;
                    mv = this.#UNDEFINED;
                    continue;
                }
                if ( c !== 0x5B ) {
                    if ( mv === this.#UNDEFINED ) {
                        const step = steps.at(-1);
                        if ( step === undefined ) { return; }
                        const j = this.#compileExpr(query, step, i);
                        if ( j ) { i = j; }
                        break;
                    }
                    const r = this.#consumeUnquotedIdentifier(query, i);
                    if  ( r === undefined ) { return; }
                    steps.push({ mv, k: r.s });
                    i = r.i;
                    mv = this.#UNDEFINED;
                    continue;
                }
                if ( mv === this.#CHILDREN ) { return; }
                if ( query.startsWith('[?', i) ) {
                    const not = query.charCodeAt(i+2) === 0x21 ? 1 : 0;
                    const j = i + 2 + not;
                    const r = this.#compile(query, j);
                    if ( r === undefined ) { return; }
                    if ( query.startsWith(']', r.i) === false ) { return; }
                    if ( not ) { r.steps.at(-1).not = true; }
                    steps.push({ mv: mv || this.#CHILDREN, steps: r.steps });
                    i = r.i + 1;
                    mv = this.#UNDEFINED;
                    continue;
                }
                if ( query.startsWith('[*]', i) ) {
                    mv ||= this.#CHILDREN;
                    steps.push({ mv, k: '*' });
                    i += 3;
                    mv = this.#UNDEFINED;
                    continue;
                }
                const r = this.#consumeIdentifier(query, i+1);
                if ( r === undefined ) { return; }
                mv ||= this.#CHILDREN;
                steps.push({ mv, k: r.s });
                i = r.i + 1;
                mv = this.#UNDEFINED;
            }
            if ( steps.length === 0 ) { return; }
            if ( mv !== this.#UNDEFINED ) { return; }
            return { steps, i };
        }
        #evaluate(steps, pathin) {
            let resultset = [];
            if ( Array.isArray(steps) === false ) { return resultset; }
            for ( const step of steps ) {
                switch ( step.mv ) {
                case this.#ROOT:
                    resultset = [ [ '$' ] ];
                    break;
                case this.#CURRENT:
                    if ( step.op ) {
                        const { obj, key } = this.#resolvePath(pathin);
                        if ( obj === undefined ) { return []; }
                        const outcome = this.#evaluateExpr(step, obj, key);
                        if ( outcome !== true ) { break; }
                    }
                    resultset = [ pathin ];
                    break;
                case this.#CHILDREN:
                case this.#DESCENDANTS: {
                    if ( resultset.length === 0 ) { break; }
                    resultset = this.#getMatches(resultset, step);
                    break;
                }
                case this.#QUANTIFIER: {
                    const { length } = resultset;
                    if ( length < step.min || length > step.max ) { return []; }
                    resultset = [];
                    break;
                }
                default:
                    break;
                }
            }
            return resultset;
        }
        #getMatches(listin, step) {
            const listout = [];
            for ( const pathin of listin ) {
                const { value: owner } = this.#resolvePath(pathin);
                if ( owner === undefined ) { continue; }
                if ( step.steps ) {
                    this.#getMatchesFromExpr(pathin, step, owner, listout);
                    continue;
                }
                const iter = this.#expandKey(owner, step.k);
                if ( iter ) {
                    for ( const k of iter ) {
                        const outcome = this.#evaluateExpr(step, owner, k);
                        if ( outcome !== true ) { continue; }
                        listout.push([ ...pathin, k ]);
                    }
                }
                if ( step.mv !== this.#DESCENDANTS ) { continue; }
                for ( const { obj, key, path } of this.#getDescendants(owner, true) ) {
                    const iter = this.#expandKey(obj[key], step.k);
                    if ( iter === undefined ) { continue; }
                    for ( const k of iter ) {
                        const outcome = this.#evaluateExpr(step, obj[key], k);
                        if ( outcome !== true ) { continue; }
                        listout.push([ ...pathin, ...path, k ]);
                    }
                }
            }
            return listout;
        }
        #expandKey(owner, k) {
            if ( typeof owner !== 'object' || owner === null ) { return; }
            if ( Array.isArray(k) ) {
                const out = [];
                for ( const a of k ) {
                    const iter = this.#expandKey(owner, a);
                    if ( iter === undefined ) { continue; }
                    out.push(...iter);
                }
                return out;
            }
            if ( typeof k === 'number' ) {
                if ( Array.isArray(owner) === false ) { return; }
                return [ k >= 0 ? k : owner.length + k ];
            }
            if ( k === '*' ) {
                if ( Array.isArray(owner) ) { return owner.keys(); }
                return JSONPath.keys(owner);
            }
            if ( k instanceof JSONPath.Regex ) {
                const out = [];
                for ( const key of JSONPath.keys(owner) ) {
                    if ( k.test(key) === false ) { continue; }
                    out.push(key);
                }
                return out;
            }
            return [ k ];
        }
        #getMatchesFromExpr(pathin, step, owner, out) {
            const recursive = step.mv === this.#DESCENDANTS;
            const v2 = this.#compiled.v2 || recursive || Array.isArray(owner);
            for ( const { path } of this.#getDescendants(owner, recursive) ) {
                const q = v2 ? [ ...pathin, ...path ] : pathin;
                const r = this.#evaluate(step.steps, q);
                if ( Boolean(r?.length) === false ) { continue; }
                out.push(q);
                if ( v2 === false ) { break; }
            }
        }
        #getDescendants(v, recursive) {
            const iterator = {
                next() {
                    const n = this.stack.length;
                    if ( n === 0 ) {
                        this.value = undefined;
                        this.done = true;
                        return this;
                    }
                    const details = this.stack[n-1];
                    const entry = details.keys.next();
                    if ( entry.done ) {
                        this.stack.pop();
                        this.path.pop();
                        return this.next();
                    }
                    this.path[n-1] = entry.value;
                    this.value = {
                        obj: details.obj,
                        key: entry.value,
                        path: this.path.slice(),
                    };
                    const v = this.value.obj[this.value.key];
                    if ( recursive && typeof v === 'object' && v !== null && this.seen.has(v) === false ) {
                        if ( Array.isArray(v) ) {
                            this.stack.push({ obj: v, keys: v.keys() });
                        } else {
                            this.stack.push({ obj: v, keys: JSONPath.keys(v).values() });
                        }
                        this.seen.add(v);
                    }
                    return this;
                },
                path: [],
                value: undefined,
                done: false,
                stack: [],
                seen: new WeakSet(),
                [Symbol.iterator]() { return this; },
            };
            if ( Array.isArray(v) ) {
                iterator.stack.push({ obj: v, keys: v.keys() });
            } else if ( typeof v === 'object' && v !== null ) {
                iterator.stack.push({ obj: v, keys: JSONPath.keys(v).values() });
            }
            return iterator;
        }
        #consumeIdentifier(query, i) {
            const keys = [];
            let needIdentifier = true;
            while ( i < query.length ) {
                const c0 = query.charCodeAt(i);
                if ( c0 === 0x5D ) { break; }
                if ( c0 === 0x20 ) {
                    i += 1;
                    continue;
                }
                if ( c0 === 0x2C ) {
                    if ( needIdentifier ) { return; }
                    i += 1;
                    needIdentifier = true;
                    continue;
                }
                if ( c0 === 0x22 || c0 === 0x27 ) {
                    const r = this.#untilChar(query, c0, i+1);
                    if ( r === undefined ) { return; }
                    keys.push(r.s);
                    i = r.i;
                    needIdentifier = false;
                    continue;
                }
                if ( c0 === 0x2D || c0 >= 0x30 && c0 <= 0x39 ) {
                    const match = this.#reIndice.exec(query.slice(i));
                    if ( match === null ) { return; }
                    const indice = parseInt(query.slice(i), 10);
                    keys.push(indice);
                    i += match[0].length;
                    needIdentifier = false;
                    continue;
                }
                if ( this.v2 ) { return; }
                const r = this.#consumeUnquotedIdentifier(query, i);
                if ( r === undefined ) { return; }
                keys.push(r.s);
                i = r.i;
            }
            if ( needIdentifier ) { return; }
            return { s: keys.length === 1 ? keys[0] : keys, i };
        }
        #consumeUnquotedIdentifier(query, i) {
            if ( query.charCodeAt(i) === 0x2F ) {
                const r = this.#untilChar(query, 0x2F, i+1);
                if ( r === undefined ) { return; }
                let re;
                try { re = new JSONPath.Regex(r.s); } catch { return; }
                return { s: re, i: r.i };
            }
            const match = this.#reUnquotedIdentifier.exec(query.slice(i));
            if ( match === null ) { return; }
            return { s: match[0], i: i + match[0].length };
        }
        #untilChar(query, targetCharCode, i) {
            const len = query.length;
            const parts = [];
            let beg = i, end = i;
            for (;;) {
                if ( end === len ) { return; }
                const c = query.charCodeAt(end);
                if ( c === targetCharCode ) {
                    parts.push(query.slice(beg, end));
                    end += 1;
                    break;
                }
                if ( c === 0x5C && (end+1) < len ) {
                    const d = query.charCodeAt(end+1);
                    if ( d === targetCharCode ) {
                        parts.push(query.slice(beg, end));
                        end += 1;
                        beg = end;
                    }
                }
                end += 1;
            }
            return { s: parts.join(''), i: end };
        }
        #compileExpr(query, step, i) {
            if ( query.startsWith('=/', i) ) {
                const r = this.#untilChar(query, 0x2F, i+2);
                if ( r === undefined ) { return i; }
                const match = /^[i]/.exec(query.slice(r.i));
                try {
                    step.rval = new JSONPath.Regex(r.s, match && match[0] || undefined);
                } catch { return; }
                step.op = 're';
                if ( match ) { r.i += match[0].length; }
                return r.i;
            }
            const match = this.#reExpr.exec(query.slice(i));
            if ( match === null ) { return; }
            const op = match[1], rval = match[2];
            if ( rval.charCodeAt(0) === 0x27 ) {
                const r = this.#untilChar(rval, 0x27, 1);
                if ( r === undefined ) { return; }
                step.rval = r.s;
                step.op = op;
            } else {
                try {
                    step.rval = JSON.parse(rval);
                    step.op = op;
                } catch { return; }
            }
            return i + match[0].length - 1;
        }
        #resolvePath(path) {
            if ( path.length === 0 ) { return { value: this.#root }; }
            const key = path.at(-1);
            let obj = this.#root
            for ( let i = 0, n = path.length-1; i < n; i++ ) {
                obj = obj[path[i]];
                if ( obj instanceof Object === false ) { return {}; }
            }
            return { obj, key, value: obj[key] };
        }
        #evaluateExpr(step, owner, k) {
            if ( owner === undefined || owner === null ) { return; }
            const hasOwn = owner[k] !== undefined || JSONPath.hasOwn(owner, k);
            if ( step.op !== undefined && hasOwn === false ) { return; }
            const target = step.not !== true;
            const v = owner[k];
            switch ( step.op ) {
            case '==': return (v === step.rval) === target;
            case '!=': return (v !== step.rval) === target;
            case  '<': return (v < step.rval) === target;
            case '<=': return (v <= step.rval) === target;
            case  '>': return (v > step.rval) === target;
            case '>=': return (v >= step.rval) === target;
            case '^=': return `${v}`.startsWith(step.rval) === target;
            case '$=': return `${v}`.endsWith(step.rval) === target;
            case '*=': return `${v}`.includes(step.rval) === target;
            case 're': return step.rval.test(`${v}`);
            default: break;
            }
            return hasOwn === target;
        }
        #modifyVal(obj, key) {
            let { modify, rval } = this.#compiled;
            if ( typeof rval === 'string' ) {
                rval = rval.replace('${now}', `${Date.now()}`);
            }
            switch ( modify ) {
            case undefined:
                obj[key] = rval;
                break;
            case '+': {
                if ( rval instanceof Object === false ) { return; }
                const lval = obj[key];
                if ( lval instanceof Object === false ) { return; }
                if ( Array.isArray(lval) ) {
                    if ( Array.isArray(rval) ) {
                        lval.push(...rval); break;
                    }
                    lval.push(rval); break;
                }
                for ( const [ k, v ] of JSONPath.entries(rval) ) {
                    lval[k] = v;
                }
                break;
            }
            case 'call': {
                const entries = rval.slice();
                if ( entries.length < 2 ) { break; }
                entries.forEach((a, i, aa) => {
                    if ( a === '${obj}' ) { aa[i] = obj; }
                    else if ( a === '${key}' ) { aa[i] = key; }
                    else if ( a === '${val}' ) { aa[i] = obj[key]; }
                });
                const instance = entries[0] ?? self;
                instance[entries[1]](...entries.slice(2));
                break;
            }
            case 'repl': {
                const lval = obj[key];
                if ( typeof lval !== 'string' ) { return; }
                if ( this.#compiled.re === undefined ) {
                    this.#compiled.re = null;
                    try {
                        this.#compiled.re = rval.regex !== undefined
                            ? new JSONPath.Regex(rval.regex, rval.flags)
                            : new JSONPath.Regex(rval.pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
                    } catch { }
                }
                if ( this.#compiled.re === null ) { return; }
                obj[key] = lval.replace(this.#compiled.re, rval.replacement);
                break;
            }
            default:
                break;
            }
        }
    }

    for (const rule of Array.isArray(rules) ? rules : []) {
        const [name, ...args] = rule;
        const scriptlet = scriptlets[name];
        if (typeof scriptlet !== 'function')
            continue;
        try {
            scriptlet(...args);
        } catch {
        }
    }
})
