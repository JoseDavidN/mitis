// Gestor de contraseñas en las páginas (BrowserProfile lo inyecta en el mundo
// de Mitis, ApplicationWorld, solo en el marco principal: la página no lo ve).
// Avisa a Mitis por consola («mitis:pw:<clave> <tipo> <datos>»; la clave la
// pone otro script del mismo mundo, así la página no puede fingir avisos):
//   focus  {kind, rect}  el foco entra en un campo de usuario o contraseña
//                        (kind: "username", "password" o "new-password", el de
//                        un registro), con su rectángulo en la ventana
//   move   {rect}        el campo se movió (desplazar, redimensionar)
//   filter {text}        lo escrito en el campo de usuario, para filtrar
//   key    {key}         flechas, Enter o Esc con la lista abierta
//   none                 el foco salió de esos campos
//   submit {username, password}  se envió un inicio de sesión o registro
// Mitis rellena con window.__mitisPasswords.fill() y fillNew().
(function () {
    "use strict";
    if (window.__mitisPasswords || !window.__mitisPwToken)
        return;
    const token = window.__mitisPwToken;

    const UserWords = /user|e-?mail|login|correo|usuario|account|cuenta|identifier|nick|phone|tel[eé]fono|documento/i;
    const SignupWords = /regist|sign.?up|crea|create|join|nueva cuenta|new account|únete|unete/i;
    const UserTypes = ["text", "email", "tel", ""];

    let current = null;     // campo con el foco
    let currentKind = "";
    let open = false;       // Mitis muestra su lista
    let filling = false;    // rellenando: el foco que se mueve no avisa
    let lastUsername = "";  // inicios de sesión en dos pasos (usuario y luego contraseña)
    let lastSent = "";
    let lastSentAt = 0;
    let moveFrame = 0;

    function send(type, data) {
        console.debug("mitis:pw:" + token + " " + type + " " + JSON.stringify(data || {}));
    }

    function visible(el) {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && getComputedStyle(el).visibility !== "hidden";
    }
    function editable(el) {
        return !el.disabled && !el.readOnly;
    }
    function isPassword(el) {
        return el instanceof HTMLInputElement && el.type === "password";
    }
    function isTextInput(el) {
        return el instanceof HTMLInputElement && UserTypes.includes(el.getAttribute("type") === null ? "" : el.type)
            && editable(el);
    }
    function scopeOf(el) {
        return el.form || document;
    }
    function passwordsIn(scope) {
        return Array.from(scope.querySelectorAll("input[type=password]")).filter(el => visible(el) && editable(el));
    }
    // El campo de usuario de una contraseña: el último de texto antes de ella
    function usernameFor(password) {
        const scope = scopeOf(password);
        let best = null;
        for (const input of scope.querySelectorAll("input")) {
            if (input === password)
                break;
            if (isTextInput(input) && visible(input))
                best = input;
        }
        if (best)
            return best;
        // Oculto, como el de los inicios de sesión en dos pasos
        return scope.querySelector("input[autocomplete~=username], input[type=email]");
    }
    function looksLikeUsername(el) {
        if (!isTextInput(el) || !visible(el))
            return false;
        const autocomplete = (el.getAttribute("autocomplete") || "").toLowerCase();
        if (/one-time-code|search|off|new-password|cc-/.test(autocomplete) || el.type === "search")
            return false;
        if (/username|email/.test(autocomplete) || el.type === "email")
            return true;
        const passwords = passwordsIn(scopeOf(el));
        if (passwords.length > 0)
            return usernameFor(passwords[0]) === el;
        // Primer paso de un inicio de sesión (aún sin contraseña)
        const words = [el.name, el.id, el.placeholder, el.getAttribute("aria-label")].join(" ");
        return UserWords.test(words) && el.form !== null;
    }
    // Registro (o cambio de contraseña): contraseña nueva
    function isSignup(password) {
        const autocomplete = (password.getAttribute("autocomplete") || "").toLowerCase();
        if (autocomplete.includes("new-password"))
            return true;
        if (autocomplete.includes("current-password"))
            return false;
        const scope = scopeOf(password);
        if (passwordsIn(scope).length >= 2)
            return true;
        const form = password.form;
        const text = [location.pathname, form ? form.action : "", form ? form.id : "", form ? form.className : ""].join(" ");
        return SignupWords.test(text);
    }
    function kindOf(el) {
        if (isPassword(el) && editable(el))
            return isSignup(el) ? "new-password" : "password";
        if (looksLikeUsername(el))
            return "username";
        return "";
    }
    function rectOf(el) {
        const rect = el.getBoundingClientRect();
        return { x: rect.left, y: rect.top, width: rect.width, height: rect.height };
    }

    function focusField(el) {
        if (filling)
            return;
        const kind = el ? kindOf(el) : "";
        if (!kind) {
            if (current) {
                current = null;
                currentKind = "";
                send("none");
            }
            return;
        }
        current = el;
        currentKind = kind;
        send("focus", { kind: kind, rect: rectOf(el), text: kind === "username" ? el.value : "" });
    }

    document.addEventListener("focusin", event => focusField(event.target), true);
    // Pulsar el campo que ya tiene el foco vuelve a mostrar la lista
    document.addEventListener("pointerdown", event => {
        if (event.target === current)
            send("focus", { kind: currentKind, rect: rectOf(current), text: currentKind === "username" ? current.value : "" });
        else if (current && kindOf(event.target) === "")
            send("none");
    }, true);
    document.addEventListener("input", event => {
        if (event.target !== current || filling)
            return;
        if (currentKind === "username") {
            lastUsername = current.value;
            send("filter", { text: current.value });
        } else if (currentKind === "password" && current.value !== "") {
            send("none");
        }
    }, true);
    document.addEventListener("keydown", event => {
        const target = event.target;
        if (target === current && open) {
            const keys = { ArrowDown: "down", ArrowUp: "up", Enter: "enter", Escape: "escape" };
            const key = keys[event.key];
            if (key) {
                event.preventDefault();
                event.stopImmediatePropagation();
                send("key", { key: key });
                return;
            }
        }
        if (event.key === "Enter" && target instanceof HTMLInputElement && (isPassword(target) || target === current))
            capture(scopeOf(target));
    }, true);
    function follow() {
        if (!current || moveFrame)
            return;
        moveFrame = requestAnimationFrame(() => {
            moveFrame = 0;
            if (current && current.isConnected)
                send("move", { rect: rectOf(current) });
        });
    }
    window.addEventListener("scroll", follow, { capture: true, passive: true });
    window.addEventListener("resize", follow, { passive: true });

    // Envío del formulario: Enter, botón o submit
    function capture(scope) {
        const passwords = passwordsIn(scope).filter(el => el.value !== "");
        if (passwords.length === 0) {
            // Primer paso: solo el usuario
            const user = Array.from(scope.querySelectorAll("input")).find(el => looksLikeUsername(el) && el.value !== "");
            if (user)
                lastUsername = user.value;
            return;
        }
        let password = passwords[passwords.length - 1].value;
        // Cambio de contraseña (actual, nueva y repetida): la nueva
        if (passwords.length >= 3)
            password = passwords[1].value;
        const userField = usernameFor(passwords[0]);
        const username = ((userField && userField.value) || lastUsername || "").trim();
        const key = username + "\n" + password;
        if (key === lastSent && Date.now() - lastSentAt < 3000)
            return;
        lastSent = key;
        lastSentAt = Date.now();
        send("submit", { username: username, password: password });
    }
    document.addEventListener("submit", event => capture(scopeOf(event.target)), true);
    document.addEventListener("click", event => {
        const button = event.target instanceof Element
            ? event.target.closest("button, input[type=submit], input[type=button], input[type=image], [role=button]")
            : null;
        if (!button)
            return;
        // Un botón que no envía (mostrar la contraseña) también llega aquí:
        // Mitis se queda con el último aviso
        capture(button.form || button.closest("form") || document);
    }, true);

    function setValue(el, value) {
        el.focus();
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
        setter.call(el, value);
        // Como al escribir: los formularios de React, Vue… lo ven
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
    }

    window.__mitisPasswords = {
        setOpen(value) {
            open = value;
        },
        fill(username, password) {
            const el = current && current.isConnected ? current : document.activeElement;
            if (!(el instanceof HTMLInputElement))
                return false;
            filling = true;
            const scope = scopeOf(el);
            const passwordField = isPassword(el) ? el : passwordsIn(scope)[0];
            const userField = isPassword(el) ? usernameFor(el) : el;
            if (userField && username && userField !== passwordField)
                setValue(userField, username);
            if (passwordField && password)
                setValue(passwordField, password);
            lastUsername = username;
            filling = false;
            open = false;
            return true;
        },
        // Contraseña generada: en todos los de contraseña nueva (y repetirla)
        fillNew(password) {
            const el = current && current.isConnected ? current : document.activeElement;
            if (!isPassword(el))
                return false;
            filling = true;
            for (const field of passwordsIn(scopeOf(el))) {
                if (!(field.getAttribute("autocomplete") || "").includes("current-password"))
                    setValue(field, password);
            }
            el.focus();
            filling = false;
            open = false;
            return true;
        }
    };

    // Un campo con el foco desde que se cargó la página (autofocus)
    if (document.activeElement && document.activeElement !== document.body)
        focusField(document.activeElement);
})();
