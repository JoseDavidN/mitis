// Llaves de acceso en Linux (src/hybrid.*, BrowserTab). Qt WebEngine solo
// atiende llaves físicas (USB/NFC): las del móvil («usar un teléfono») no
// existen en el motor. Las peticiones de la página (navigator.credentials con
// publicKey) las atiende Mitis: pregunta con su ventana (QR para el móvil o
// llave física) por un aviso de consola y responde con
// __mitisWebAuthn.answer(). Con «llave física», la petición sigue por el
// motor como siempre. Las de autorrelleno (mediation: "conditional") van
// siempre al motor. Solo en el marco principal (BrowserProfile).
(() => {
    if (!window.PublicKeyCredential || !window.CredentialsContainer)
        return
    const container = CredentialsContainer.prototype
    const nativeGet = container.get
    const nativeCreate = container.create
    const pending = new Map()
    let lastId = 0

    const bytesOf = source => source instanceof ArrayBuffer
        ? new Uint8Array(source)
        : new Uint8Array(source.buffer, source.byteOffset, source.byteLength)
    const toBase64url = source => {
        let text = ""
        for (const byte of bytesOf(source))
            text += String.fromCharCode(byte)
        return btoa(text).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
    }
    const fromBase64url = text => {
        const binary = atob(text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4))
        const bytes = new Uint8Array(binary.length)
        for (let i = 0; i < binary.length; i++)
            bytes[i] = binary.charCodeAt(i)
        return bytes.buffer
    }
    // Las opciones como JSON: los binarios (challenge, ids…) en base64url
    const toJson = value => value instanceof ArrayBuffer || ArrayBuffer.isView(value)
        ? toBase64url(value)
        : Array.isArray(value) ? value.map(toJson)
        : value && typeof value === "object"
          ? Object.fromEntries(Object.entries(value).map(([key, item]) => [key, toJson(item)]))
          : value

    // Una credencial como las del motor: con sus prototipos (instanceof) y
    // los datos como propiedades propias
    function credential(kind, answer, publicKey) {
        const define = (object, name, value) => Object.defineProperty(object, name, { value, enumerable: true })
        const extensions = {}
        if (kind === "create" && publicKey.extensions && publicKey.extensions.credProps)
            extensions.credProps = { rk: true }
        const response = Object.create(kind === "get" ? AuthenticatorAssertionResponse.prototype
                                                      : AuthenticatorAttestationResponse.prototype)
        const json = { clientDataJSON: answer.clientDataJSON }
        define(response, "clientDataJSON", fromBase64url(answer.clientDataJSON))
        if (kind === "get") {
            define(response, "authenticatorData", fromBase64url(answer.authenticatorData))
            define(response, "signature", fromBase64url(answer.signature))
            define(response, "userHandle", answer.userHandle ? fromBase64url(answer.userHandle) : null)
            Object.assign(json, { authenticatorData: answer.authenticatorData, signature: answer.signature,
                                  userHandle: answer.userHandle || undefined })
        } else {
            define(response, "attestationObject", fromBase64url(answer.attestationObject))
            define(response, "getTransports", () => ["hybrid", "internal"])
            define(response, "getAuthenticatorData", () => fromBase64url(answer.authenticatorData))
            define(response, "getPublicKey", () => answer.publicKey ? fromBase64url(answer.publicKey) : null)
            define(response, "getPublicKeyAlgorithm", () => answer.publicKeyAlgorithm)
            Object.assign(json, { attestationObject: answer.attestationObject, transports: ["hybrid", "internal"],
                                  authenticatorData: answer.authenticatorData, publicKey: answer.publicKey || undefined,
                                  publicKeyAlgorithm: answer.publicKeyAlgorithm })
        }
        define(response, "toJSON", () => json)
        const result = Object.create(PublicKeyCredential.prototype)
        define(result, "id", answer.rawId)
        define(result, "rawId", fromBase64url(answer.rawId))
        define(result, "type", "public-key")
        define(result, "authenticatorAttachment", "cross-platform")
        define(result, "response", response)
        define(result, "getClientExtensionResults", () => extensions)
        define(result, "toJSON", () => ({ id: answer.rawId, rawId: answer.rawId, type: "public-key",
                                          authenticatorAttachment: "cross-platform",
                                          clientExtensionResults: extensions, response: json }))
        return result
    }

    function viaMitis(kind, options, container, native) {
        if (!options || !options.publicKey || options.mediation === "conditional")
            return native.call(container, options)
        const signal = options.signal
        const aborted = () => signal.reason ?? new DOMException("The operation was aborted.", "AbortError")
        if (signal && signal.aborted)
            return Promise.reject(aborted())
        return new Promise((resolve, reject) => {
            const id = ++lastId
            pending.set(id, { kind, options, container, native, resolve, reject })
            if (signal) {
                signal.addEventListener("abort", () => {
                    if (pending.delete(id)) {
                        console.log("mitis:webauthn:cancel " + id)
                        reject(aborted())
                    }
                })
            }
            console.log("mitis:webauthn:request " + id + " " + kind + " " + JSON.stringify(toJson(options.publicKey)))
        })
    }

    // Mitis responde aquí (BrowserTab, runJavaScript): no se puede sustituir
    Object.defineProperty(window, "__mitisWebAuthn", {
        value: Object.freeze({
            answer(id, answer) {
                const request = pending.get(id)
                if (!request)
                    return
                // Llave física: la petición sigue por el motor; Mitis puede
                // cancelarla (sin llave conectada, el motor no deja hacerlo)
                if (answer.cancel) {
                    pending.delete(id)
                    // Que el motor también la olvide: si no, la siguiente
                    // petición chocaría con ella («ya hay una en curso»)
                    if (request.controller)
                        request.controller.abort()
                    request.reject(new DOMException("The operation either timed out or was not allowed.", "NotAllowedError"))
                    return
                }
                if (answer.native) {
                    const done = () => {
                        pending.delete(id)
                        console.log("mitis:webauthn:done " + id)
                    }
                    request.controller = new AbortController()
                    const signal = request.options.signal
                        ? AbortSignal.any([request.options.signal, request.controller.signal])
                        : request.controller.signal
                    const options = Object.assign({}, request.options, { signal })
                    request.native.call(request.container, options).then(result => {
                        if (pending.has(id))
                            request.resolve(result)
                        done()
                    }, error => {
                        if (pending.has(id))
                            request.reject(error)
                        done()
                    })
                    return
                }
                pending.delete(id)
                if (answer.error === "TypeError")
                    request.reject(new TypeError(answer.message || "Invalid options"))
                else if (answer.error)
                    request.reject(new DOMException(answer.message || "The operation either timed out or was not allowed.", answer.error))
                else
                    request.resolve(credential(request.kind, answer, request.options.publicKey))
            }
        })
    })

    container.get = function get(options) {
        return viaMitis("get", options, this, nativeGet)
    }
    container.create = function create(options) {
        return viaMitis("create", options, this, nativeCreate)
    }
    // Las páginas que preguntan qué admite el navegador: el móvil, sí
    if (PublicKeyCredential.getClientCapabilities) {
        const capabilities = PublicKeyCredential.getClientCapabilities.bind(PublicKeyCredential)
        PublicKeyCredential.getClientCapabilities = () => capabilities().then(found => Object.assign({}, found, { hybridTransport: true }))
    }
})()
