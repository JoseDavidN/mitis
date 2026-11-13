#include "filterengine.h"

#include <algorithm>
#include <cstdio>

namespace {

// Caracteres de un token: lo que va entre separadores en una dirección
inline bool isTokenChar(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '%';
}

// «^» de las reglas: cualquier cosa que no sea letra, número o _-.%
inline bool isSeparator(char c)
{
    return !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.' || c == '%');
}

quint32 tokenHash(const char *data, qsizetype size)
{
    quint32 hash = 2166136261u;
    for (qsizetype i = 0; i < size; ++i) {
        hash ^= quint8(data[i]);
        hash *= 16777619u;
    }
    return hash;
}

// Tokens tan comunes que indexar por ellos haría probar cientos de filtros
bool isBadToken(const QByteArray &token)
{
    static const QSet<QByteArray> bad = {
        "http", "https", "www", "com", "js", "net", "org", "html", "php",
    };
    return bad.contains(token);
}

// ¿Encaja el patrón (con «*» y «^») empezando justo en url[start]?
bool wildMatch(const QByteArray &url, qsizetype start, const QByteArray &pattern, bool endAnchor)
{
    const qsizetype urlSize = url.size();
    const qsizetype patternSize = pattern.size();
    qsizetype u = start;
    qsizetype p = 0;
    qsizetype starP = -1;
    qsizetype starU = 0;
    while (true) {
        if (p == patternSize) {
            if (!endAnchor || u == urlSize)
                return true;
        } else {
            const char c = pattern.at(p);
            if (c == '*') {
                starP = p++;
                starU = u;
                continue;
            }
            if (u < urlSize && (c == url.at(u) || (c == '^' && isSeparator(url.at(u))))) {
                ++p;
                ++u;
                continue;
            }
            // «^» también encaja con el final de la dirección
            if (c == '^' && u == urlSize) {
                ++p;
                continue;
            }
        }
        // Sin coincidencia: el último «*» se traga un carácter más
        if (starP < 0 || starU >= urlSize)
            return false;
        u = ++starU;
        p = starP + 1;
    }
}

// La página `host` es `domain` o un subdominio suyo
bool isSameOrSubdomain(const QByteArray &host, const QByteArray &domain)
{
    return host.size() == domain.size()
        ? host == domain
        : host.size() > domain.size() && host.endsWith(domain) && host.at(host.size() - domain.size() - 1) == '.';
}

bool matchesAnyDomain(const QByteArray &host, const QList<QByteArray> &domains)
{
    // Sin el sufijo público, para las entidades («kat.*»): «www.kat.» de www.kat.co.uk
    QByteArray withoutSuffix;
    for (const QByteArray &domain : domains) {
        if (domain.endsWith(".*")) {
            if (withoutSuffix.isEmpty()) {
                const QByteArray base = FilterEngine::baseDomain(host);
                const qsizetype dot = base.indexOf('.');
                withoutSuffix = dot > 0 ? host.left(host.size() - (base.size() - dot - 1)) : QByteArray("-");
            }
            if (isSameOrSubdomain(withoutSuffix, domain.chopped(1)))
                return true;
        } else if (isSameOrSubdomain(host, domain)) {
            return true;
        }
    }
    return false;
}

// La regla sin «badfilter» entre sus opciones: la que anula
QByteArray withoutBadFilter(const QByteArray &line)
{
    const qsizetype dollar = line.lastIndexOf('$');
    QList<QByteArray> options = line.mid(dollar + 1).split(',');
    options.removeAll(QByteArrayLiteral("badfilter"));
    const QByteArray rule = line.left(dollar);
    return options.isEmpty() ? rule : rule + '$' + options.join(',');
}

// Pseudoclases de uBlock Origin / Adblock Plus que no son CSS: una sola
// invalidaría la regla, así que esos selectores se descartan
bool isPlainCss(const QByteArray &selector)
{
    static const char *const extended[] = {
        ":-abp-", ":has-text(", ":xpath(", ":upward(", ":remove(", ":style(", ":matches-css",
        ":min-text-length(", ":watch-attr(", ":matches-path(", ":others(", ":if(", ":if-not(",
        ":nth-ancestor(", ":matches-attr(", ":matches-media(", ":matches-prop(", ":spath(",
        ":remove-attr(", ":remove-class(", ":contains(",
    };
    for (const char *pseudo : extended) {
        if (selector.contains(pseudo))
            return false;
    }
    // Llaves: podrían cerrar la regla CSS e inyectar otras
    return !selector.contains('{') && !selector.contains('}');
}

// ── Preprocesado de las listas de uBlock Origin ──────────────────────
// «!#if expresión» / «!#else» / «!#endif», como uBlock Origin en Chromium
// de escritorio (static-filtering-parser.js de uBlock Origin, GPL-3).
// Valor de un término: 1 verdadero, 0 falso, -1 desconocido.
int conditionToken(QByteArray token)
{
    const bool negated = token.startsWith('!');
    if (negated)
        token = token.mid(1);
    static const QSet<QByteArray> trueTokens = {
        "ext_ublock", "env_chromium", "adguard_ext_chromium", "adguard_ext_opera",
    };
    static const QSet<QByteArray> falseTokens = {
        "ext_ubol", "ext_devbuild", "env_brave", "env_edge", "env_firefox", "env_legacy",
        "env_mobile", "env_mv3", "env_safari", "false", "ext_abp", "adguard",
        "adguard_app_android", "adguard_app_cli", "adguard_app_ios", "adguard_app_mac",
        "adguard_app_windows", "adguard_ext_android_cb", "adguard_ext_chromium_mv3",
        "adguard_ext_edge", "adguard_ext_firefox", "adguard_ext_safari",
    };
    bool value;
    if (trueTokens.contains(token))
        value = true;
    // Capacidades que Mitis no tiene (filtrado de HTML, IP…): falsas
    else if (falseTokens.contains(token) || token.startsWith("cap_"))
        value = false;
    else
        return -1;
    return value != negated ? 1 : 0;
}

// De izquierda a derecha, sin precedencia (como uBlock Origin)
int conditionValue(QByteArray expression)
{
    expression = expression.trimmed();
    if (expression.startsWith('(') && expression.endsWith(')'))
        expression = expression.mid(1, expression.size() - 2);
    const QList<QByteArray> parts = expression.simplified().split(' ');
    // Término, y después pares «operador término»
    if (parts.first().isEmpty() || parts.size() % 2 == 0)
        return -1;
    int result = conditionToken(parts.first());
    for (qsizetype i = 1; i < parts.size() && result >= 0; i += 2) {
        const int value = conditionToken(parts.at(i + 1));
        if (value < 0)
            return -1;
        if (parts.at(i) == "||")
            result = result || value;
        else if (parts.at(i) == "&&")
            result = result && value;
        else
            return -1;
    }
    return result;
}

// Llama a `handle` con cada línea (sin espacios en los extremos) que no
// esté en un bloque «!#if» falso. Uno que no se entiende se deja pasar.
template<typename Handler>
void forEachLine(const QByteArray &list, Handler &&handle)
{
    struct Block {
        bool known;
        bool discard;
    };
    std::vector<Block> blocks;
    bool discarding = false;
    const auto update = [&] {
        discarding = std::any_of(blocks.begin(), blocks.end(), [](const Block &b) { return b.known && b.discard; });
    };
    qsizetype start = 0;
    const qsizetype size = list.size();
    while (start < size) {
        qsizetype end = list.indexOf('\n', start);
        if (end < 0)
            end = size;
        const QByteArray line = list.mid(start, end - start).trimmed();
        start = end + 1;
        if (line.startsWith("!#")) {
            if (line.startsWith("!#if ") || line.startsWith("!#if\t")) {
                const int value = conditionValue(line.mid(4));
                blocks.push_back({ value >= 0, value == 0 });
                update();
            } else if (line == "!#else" || line.startsWith("!#else ")) {
                if (!blocks.empty())
                    blocks.back().discard = !blocks.back().discard;
                update();
            } else if (line == "!#endif" || line.startsWith("!#endif ")) {
                if (!blocks.empty())
                    blocks.pop_back();
                update();
            }
            continue;
        }
        if (!discarding)
            handle(line);
    }
}

// ── Scriptlets ───────────────────────────────────────────────────────
// Texto en una cadena JSON (los bytes UTF-8 tal cual)
QByteArray jsonString(const QByteArray &text)
{
    QByteArray out;
    out.reserve(text.size() + 2);
    out += '"';
    for (const char c : text) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (quint8(c) < 0x20) {
                char escaped[8];
                std::snprintf(escaped, sizeof(escaped), "\\u%04x", quint8(c));
                out += escaped;
            } else {
                out += c;
            }
        }
    }
    out += '"';
    return out;
}

// Quita la «\» que escapa a `separator` (una sola de un número impar de
// «\» seguidas; ArglistParser.normalizeArg de uBlock Origin)
QByteArray unescapeArg(const QByteArray &arg, char separator)
{
    QByteArray out;
    out.reserve(arg.size());
    for (qsizetype i = 0; i < arg.size(); ++i) {
        const char c = arg.at(i);
        if (c == '\\') {
            qsizetype run = 0;
            while (i + run < arg.size() && arg.at(i + run) == '\\')
                ++run;
            const bool escapes = i + run < arg.size() && arg.at(i + run) == separator && (run & 1);
            out.append(escapes ? run - 1 : run, '\\');
            i += run - 1;
            continue;
        }
        out += c;
    }
    return out;
}

bool isSpace(char c)
{
    return c == ' ' || c == '\t';
}

// Argumentos de «+js(…)» como los separa uBlock Origin (ArglistParser):
// por comas que no vayan tras «\», recortados, y entre comillas ('…', "…"
// o `…`) si van así; dentro de ellas, la coma no separa
QList<QByteArray> scriptletArgs(const QByteArray &body)
{
    QList<QByteArray> args;
    const qsizetype size = body.size();
    // Siguiente `separator` no escapado desde `from` (o el final)
    const auto nextSeparator = [&](qsizetype from, char separator) {
        for (qsizetype i = from; i < size; ++i) {
            if (body.at(i) != separator)
                continue;
            qsizetype run = 0;
            while (i - run - 1 >= 0 && body.at(i - run - 1) == '\\')
                ++run;
            if (!(run & 1))
                return i;
        }
        return size;
    };
    qsizetype pos = 0;
    while (pos < size) {
        while (pos < size && isSpace(body.at(pos)))
            ++pos;
        if (pos < size) {
            const char quote = body.at(pos);
            if (quote == '"' || quote == '\'' || quote == '`') {
                const qsizetype close = nextSeparator(pos + 1, quote);
                qsizetype after = close + 1;
                while (after < size && isSpace(body.at(after)))
                    ++after;
                if (close < size && (after >= size || body.at(after) == ',')) {
                    args.append(unescapeArg(body.mid(pos + 1, close - pos - 1), quote));
                    pos = after + 1;
                    continue;
                }
            }
        }
        // Sin comillas (o mal cerradas): hasta la coma
        const qsizetype comma = nextSeparator(pos, ',');
        args.append(unescapeArg(body.mid(pos, comma - pos).trimmed(), ','));
        pos = comma + 1;
    }
    return args;
}

// Nombre de los scriptlets que implementa assets/scripts/scriptlets.js, a
// partir del de la regla (sin «.js» ni «ubo-», y con los alias de uBlock
// Origin resueltos). Vacío si Mitis no lo tiene: la regla se descarta.
QByteArray scriptletName(QByteArray name)
{
    if (name.endsWith(".js"))
        name.chop(3);
    if (name.startsWith("ubo-"))
        name = name.mid(4);
    static const QHash<QByteArray, QByteArray> aliases = {
        { "set", "set-constant" },
        { "trusted-set", "trusted-set-constant" },
        { "aopr", "abort-on-property-read" },
        { "aopw", "abort-on-property-write" },
        { "acs", "abort-current-script" },
        { "acis", "abort-current-script" },
        { "abort-current-inline-script", "abort-current-script" },
        { "aost", "abort-on-stack-trace" },
        { "nostif", "prevent-setTimeout" },
        { "no-setTimeout-if", "prevent-setTimeout" },
        { "setTimeout-defuser", "prevent-setTimeout" },
        { "nosiif", "prevent-setInterval" },
        { "no-setInterval-if", "prevent-setInterval" },
        { "setInterval-defuser", "prevent-setInterval" },
        { "norafif", "prevent-requestAnimationFrame" },
        { "no-requestAnimationFrame-if", "prevent-requestAnimationFrame" },
        { "nano-stb", "adjust-setTimeout" },
        { "nano-setTimeout-booster", "adjust-setTimeout" },
        { "nano-sib", "adjust-setInterval" },
        { "nano-setInterval-booster", "adjust-setInterval" },
        { "no-fetch-if", "prevent-fetch" },
        { "no-xhr-if", "prevent-xhr" },
        { "aeld", "prevent-addEventListener" },
        { "addEventListener-defuser", "prevent-addEventListener" },
        { "ra", "remove-attr" },
        { "rc", "remove-class" },
        { "prevent-eval-if", "noeval-if" },
        { "nowoif", "prevent-window-open" },
        { "no-window-open-if", "prevent-window-open" },
        { "window.open-defuser", "prevent-window-open" },
        { "rmnt", "remove-node-text" },
        // replace-node-text solo existe como de confianza
        { "rpnt", "trusted-replace-node-text" },
        { "replace-node-text", "trusted-replace-node-text" },
        { "trusted-rpnt", "trusted-replace-node-text" },
        { "trusted-rpfr", "trusted-replace-fetch-response" },
    };
    static const QSet<QByteArray> implemented = {
        "set-constant", "trusted-set-constant",
        "abort-on-property-read", "abort-on-property-write", "abort-current-script", "abort-on-stack-trace",
        "json-prune", "json-prune-fetch-response", "json-prune-xhr-response",
        "trusted-prune-inbound-object", "trusted-prune-outbound-object",
        "json-edit", "trusted-json-edit", "json-edit-fetch-response", "trusted-json-edit-fetch-response",
        "json-edit-xhr-response", "trusted-json-edit-xhr-response",
        "edit-inbound-object", "trusted-edit-inbound-object",
        "prevent-setTimeout", "prevent-setInterval", "prevent-requestAnimationFrame",
        "adjust-setTimeout", "adjust-setInterval",
        "prevent-fetch", "trusted-prevent-fetch", "prevent-xhr", "trusted-prevent-xhr",
        "prevent-addEventListener", "remove-attr", "remove-class", "noeval-if", "prevent-window-open", "nowebrtc",
        "remove-node-text", "trusted-replace-node-text",
        "trusted-replace-fetch-response", "trusted-replace-xhr-response",
        "trusted-prevent-dom-bypass", "trusted-replace-argument", "trusted-replace-outbound-text",
    };
    name = aliases.value(name, name);
    return implemented.contains(name) ? name : QByteArray();
}

} // namespace

QByteArray FilterEngine::baseDomain(const QByteArray &host)
{
    // IP: no tiene dominio registrable
    if (host.contains(':') || std::all_of(host.begin(), host.end(), [](char c) { return (c >= '0' && c <= '9') || c == '.'; }))
        return host;
    const QList<QByteArray> labels = host.split('.');
    if (labels.size() <= 2)
        return host;
    // Segundo nivel genérico bajo un país: ejemplo.com.co, ejemplo.co.uk
    static const QSet<QByteArray> secondLevel = {
        "com", "co", "org", "net", "gov", "gob", "edu", "ac", "mil", "nom", "or", "ne", "go", "int", "info", "biz",
    };
    const qsizetype count = labels.size();
    const bool country = labels.at(count - 1).size() == 2;
    const int keep = country && secondLevel.contains(labels.at(count - 2)) ? 3 : 2;
    return labels.mid(count - keep).join('.');
}

quint64 FilterEngine::hostHash(const QByteArray &host)
{
    quint64 hash = 14695981039346656037ull;
    for (const char c : host) {
        hash ^= quint8(c);
        hash *= 1099511628211ull;
    }
    return hash;
}

void FilterEngine::HostSet::finish()
{
    std::sort(hashes.begin(), hashes.end());
    hashes.erase(std::unique(hashes.begin(), hashes.end()), hashes.end());
    hashes.shrink_to_fit();
}

QByteArray FilterEngine::HostSet::match(const QByteArray &host) const
{
    if (hashes.empty())
        return QByteArray();
    // El host y cada dominio por encima: a.b.c, b.c, c
    qsizetype from = 0;
    while (from >= 0 && from < host.size()) {
        const QByteArray suffix = host.mid(from);
        if (std::binary_search(hashes.begin(), hashes.end(), hostHash(suffix)))
            return suffix;
        const qsizetype dot = host.indexOf('.', from);
        from = dot < 0 ? -1 : dot + 1;
    }
    return QByteArray();
}

std::vector<quint32> FilterEngine::tokenize(const QByteArray &url)
{
    std::vector<quint32> tokens;
    const qsizetype size = url.size();
    qsizetype i = 0;
    while (i < size) {
        if (!isTokenChar(url.at(i))) {
            ++i;
            continue;
        }
        const qsizetype start = i;
        while (i < size && isTokenChar(url.at(i)))
            ++i;
        if (i - start >= 2) {
            const quint32 hash = tokenHash(url.constData() + start, i - start);
            if (std::find(tokens.begin(), tokens.end(), hash) == tokens.end())
                tokens.push_back(hash);
        }
    }
    return tokens;
}

void FilterEngine::FilterSet::add(Filter &&filter)
{
    // El token más largo que la dirección deba tener entero: rodeado de
    // separadores (o de un ancla) y nunca pegado a un «*»
    const QByteArray &pattern = filter.pattern;
    const qsizetype size = pattern.size();
    qsizetype bestStart = -1;
    qsizetype bestSize = 0;
    qsizetype i = 0;
    while (i < size) {
        if (!isTokenChar(pattern.at(i))) {
            ++i;
            continue;
        }
        const qsizetype start = i;
        while (i < size && isTokenChar(pattern.at(i)))
            ++i;
        const bool leftSafe = start > 0 ? pattern.at(start - 1) != '*' : (filter.hostAnchor || filter.startAnchor);
        const bool rightSafe = i < size ? pattern.at(i) != '*' : filter.endAnchor;
        const qsizetype length = i - start;
        if (leftSafe && rightSafe && length >= 2 && length > bestSize && !isBadToken(pattern.mid(start, length))) {
            bestStart = start;
            bestSize = length;
        }
    }
    const int index = int(filters.size());
    filters.push_back(std::move(filter));
    if (bestStart < 0)
        untokened.push_back(index);
    else
        byToken[tokenHash(filters.back().pattern.constData() + bestStart, bestSize)].push_back(index);
}

bool FilterEngine::FilterSet::matches(const Request &request, const std::vector<quint32> &tokens) const
{
    for (const quint32 token : tokens) {
        const auto found = byToken.constFind(token);
        if (found == byToken.constEnd())
            continue;
        for (const int index : *found) {
            if (matchFilter(filters[size_t(index)], request))
                return true;
        }
    }
    for (const int index : untokened) {
        if (matchFilter(filters[size_t(index)], request))
            return true;
    }
    return false;
}

bool FilterEngine::matchFilter(const Filter &filter, const Request &request)
{
    if (!(filter.types & request.type))
        return false;
    if ((filter.party == 1 && request.thirdParty) || (filter.party == 2 && !request.thirdParty))
        return false;
    if (!filter.domains.isEmpty() && !matchesAnyDomain(request.pageHost, filter.domains))
        return false;
    if (!filter.notDomains.isEmpty() && matchesAnyDomain(request.pageHost, filter.notDomains))
        return false;

    const QByteArray &url = request.url;
    const QByteArray &pattern = filter.pattern;
    if (pattern.isEmpty())
        return true;
    if (filter.startAnchor)
        return wildMatch(url, 0, pattern, filter.endAnchor);
    if (filter.hostAnchor) {
        // Al principio del host o de cualquiera de sus partes
        const qsizetype scheme = url.indexOf("://");
        if (scheme < 0)
            return false;
        const qsizetype hostStart = scheme + 3;
        qsizetype hostEnd = hostStart;
        while (hostEnd < url.size() && url.at(hostEnd) != '/' && url.at(hostEnd) != '?'
               && url.at(hostEnd) != '#' && url.at(hostEnd) != ':')
            ++hostEnd;
        for (qsizetype i = hostStart; i < hostEnd; ++i) {
            if ((i == hostStart || url.at(i - 1) == '.') && wildMatch(url, i, pattern, filter.endAnchor))
                return true;
        }
        return false;
    }
    // Sin ancla: se busca el primer tramo literal y se prueba desde ahí
    qsizetype literal = 0;
    while (literal < pattern.size() && pattern.at(literal) != '*' && pattern.at(literal) != '^')
        ++literal;
    if (literal == 0) {
        for (qsizetype i = 0; i <= url.size(); ++i) {
            if (wildMatch(url, i, pattern, filter.endAnchor))
                return true;
        }
        return false;
    }
    const QByteArrayView head(pattern.constData(), literal);
    for (qsizetype at = url.indexOf(head); at >= 0; at = url.indexOf(head, at + 1)) {
        if (wildMatch(url, at, pattern, filter.endAnchor))
            return true;
    }
    return false;
}

void FilterEngine::build(const QList<QByteArray> &lists)
{
    // «badfilter» anula una regla de cualquier lista: se recogen antes
    QSet<QByteArray> badFilters;
    for (const QByteArray &list : lists) {
        forEachLine(list, [&badFilters](const QByteArray &line) {
            if (line.contains("badfilter") && line.contains('$') && !line.startsWith('!'))
                badFilters.insert(withoutBadFilter(line));
        });
    }
    for (const QByteArray &list : lists)
        forEachLine(list, [this, &badFilters](const QByteArray &line) { parseLine(line, badFilters); });
    m_blockHosts.finish();
    m_blockThirdPartyHosts.finish();
    m_allowHosts.finish();
    m_cosmetic.squeeze();
    m_scriptlets.squeeze();
    m_scriptletCodes.shrink_to_fit();
    m_scriptletIndex = {};
}

void FilterEngine::parseLine(QByteArray line, const QSet<QByteArray> &badFilters)
{
    if (line.isEmpty() || line.startsWith('!') || line.startsWith('['))
        return;

    // Ocultación de elementos: «dominios##selector», «dominios#@#selector»
    const qsizetype hash = line.indexOf('#');
    if (hash >= 0) {
        const QByteArray rest = line.mid(hash);
        if (rest.startsWith("##") || rest.startsWith("#@#")) {
            const bool exception = rest.startsWith("#@#");
            const QByteArray selector = rest.mid(exception ? 3 : 2).trimmed();
            const QByteArray domains = line.left(hash);
            // Scriptlets de uBlock Origin: «+js(nombre, args…)»
            if (selector.startsWith("+js(")) {
                if (!domains.isEmpty() && selector.endsWith(')'))
                    parseScriptlet(domains, selector.mid(4, selector.size() - 5), exception);
                return;
            }
            // Las genéricas (sin dominio) no: costarían memoria en cada página.
            // «^…» es filtrado de HTML de uBlock Origin y no es CSS.
            if (!domains.isEmpty() && !selector.isEmpty() && !selector.startsWith('+')
                && !selector.startsWith('^') && isPlainCss(selector))
                parseCosmetic(domains, selector, exception);
            return;
        }
        // Otras variantes (#?#, #$#, #%#…) o un comentario de archivo hosts
        if (rest.startsWith("#?#") || rest.startsWith("#$#") || rest.startsWith("#%#")
            || rest.startsWith("#@?#") || rest.startsWith("#@$#") || rest.startsWith("#@%#") || hash == 0)
            return;
    }

    // Archivo hosts (listas de Pi-hole): «0.0.0.0 dominio»
    if (line.startsWith("0.0.0.0 ") || line.startsWith("127.0.0.1 ") || line.startsWith(":: ")) {
        QByteArray domain = line.mid(line.indexOf(' ') + 1).trimmed().toLower();
        const qsizetype comment = domain.indexOf('#');
        if (comment >= 0)
            domain = domain.left(comment).trimmed();
        if (!domain.isEmpty() && domain.contains('.') && !domain.contains(' ')) {
            m_blockHosts.add(domain);
            ++m_ruleCount;
        }
        return;
    }

    if (badFilters.contains(line))
        return;
    if (parseNetwork(line))
        ++m_ruleCount;
}

bool FilterEngine::parseNetwork(QByteArray line)
{
    const bool exception = line.startsWith("@@");
    if (exception)
        line = line.mid(2);

    Filter filter;
    QByteArray pattern = line;
    bool documentOption = false;
    bool elemHide = false;
    const qsizetype dollar = line.lastIndexOf('$');
    if (dollar >= 0) {
        pattern = line.left(dollar);
        quint16 types = 0;
        quint16 notTypes = 0;
        const QList<QByteArray> options = line.mid(dollar + 1).toLower().split(',');
        for (const QByteArray &option : options) {
            const bool negated = option.startsWith('~');
            const QByteArray name = (negated ? option.mid(1) : option).split('=').first();
            quint16 type = 0;
            if (name == "script")
                type = Script;
            else if (name == "image")
                type = Image;
            else if (name == "stylesheet" || name == "css")
                type = Stylesheet;
            else if (name == "object")
                type = Object;
            else if (name == "xmlhttprequest" || name == "xhr")
                type = Xhr;
            else if (name == "subdocument" || name == "frame")
                type = Subdocument;
            else if (name == "ping" || name == "beacon")
                type = Ping;
            else if (name == "media")
                type = Media;
            else if (name == "font")
                type = Font;
            else if (name == "websocket")
                type = WebSocket;
            else if (name == "other")
                type = Other;
            else if (name == "document" || name == "doc") {
                type = Document;
                documentOption = !negated;
            } else if (name == "all") {
                type = AnyResource | Document;
            } else if (name == "third-party" || name == "3p") {
                filter.party = negated ? 1 : 2;
                continue;
            } else if (name == "first-party" || name == "1p") {
                filter.party = negated ? 2 : 1;
                continue;
            } else if (name == "domain" || name == "from") {
                const qsizetype equals = option.indexOf('=');
                for (const QByteArray &entry : option.mid(equals + 1).split('|')) {
                    const bool exclude = entry.startsWith('~');
                    const QByteArray domain = exclude ? entry.mid(1) : entry;
                    // Entidades de uBlock Origin («google.*»: google.com,
                    // google.es…) sí; otros comodines, rutas o expresiones no
                    if (domain.isEmpty() || domain.indexOf('*') != (domain.endsWith(".*") ? domain.size() - 1 : -1)
                        || domain.contains('/')) {
                        // Un sitio de la regla que no se entiende: sin él, la
                        // regla valdría para todos los demás (o para todos, si
                        // solo quedan los excluidos). Mejor descartarla
                        if (!exclude)
                            return false;
                        continue;
                    }
                    (exclude ? filter.notDomains : filter.domains).append(domain);
                }
                if (filter.domains.isEmpty() && filter.notDomains.isEmpty())
                    return false;
                continue;
            } else if (name == "important") {
                filter.important = true;
                continue;
            } else if (name == "match-case") {
                continue;
            } else if ((name == "elemhide" || name == "ehide") && exception) {
                elemHide = true;
                continue;
            } else {
                // popup, redirect, csp, removeparam, generichide…: no se aplica
                return false;
            }
            (negated ? notTypes : types) |= type;
        }
        filter.types = (types ? types : quint16(AnyResource)) & ~notTypes;
        if (!filter.types && !elemHide)
            return false;
    }

    // Expresiones regulares: pocas y caras de evaluar
    if (pattern.size() > 2 && pattern.startsWith('/') && pattern.endsWith('/'))
        return false;

    pattern = pattern.toLower();
    if (pattern.startsWith("||")) {
        filter.hostAnchor = true;
        pattern = pattern.mid(2);
    } else if (pattern.startsWith('|')) {
        filter.startAnchor = true;
        pattern = pattern.mid(1);
    }
    if (pattern.endsWith('|')) {
        filter.endAnchor = true;
        pattern.chop(1);
    }
    // «*» en los extremos no cambia nada
    while (!filter.hostAnchor && !filter.startAnchor && pattern.startsWith('*'))
        pattern = pattern.mid(1);
    while (!filter.endAnchor && pattern.endsWith('*'))
        pattern.chop(1);
    filter.pattern = pattern;

    // Excepciones de página: se miran contra la dirección de la página
    if (exception && (documentOption || elemHide)) {
        filter.types = 0xffff;
        (documentOption ? m_allowDocument : m_allowElemHide).add(std::move(filter));
        return true;
    }

    // Un dominio entero sin más condiciones (como en Pi-hole): a la tabla de hashes
    const bool hostOnly = filter.hostAnchor && !filter.endAnchor && pattern.endsWith('^')
        && std::all_of(pattern.begin(), pattern.end() - 1, [](char c) {
               return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_';
           });
    if (hostOnly && filter.domains.isEmpty() && filter.notDomains.isEmpty()
        && filter.types == quint16(AnyResource) && !filter.important) {
        const QByteArray host = pattern.chopped(1);
        if (exception && filter.party == 0) {
            m_allowHosts.add(host);
            return true;
        }
        if (!exception && filter.party == 0) {
            m_blockHosts.add(host);
            return true;
        }
        if (!exception && filter.party == 2) {
            m_blockThirdPartyHosts.add(host);
            return true;
        }
    }

    if (exception)
        m_allow.add(std::move(filter));
    else if (filter.important)
        m_blockImportant.add(std::move(filter));
    else
        m_block.add(std::move(filter));
    return true;
}

void FilterEngine::parseCosmetic(const QByteArray &domains, const QByteArray &selector, bool exception)
{
    bool added = false;
    for (QByteArray domain : domains.toLower().split(',')) {
        domain = domain.trimmed();
        const bool negated = domain.startsWith('~');
        if (negated)
            domain = domain.mid(1);
        // Entidades («google.*»: google.com, google.es…) sí; otros comodines no
        if (domain.isEmpty() || domain.indexOf('*') != (domain.endsWith(".*") ? domain.size() - 1 : -1)
            || domain.contains('/'))
            continue;
        // «~sub.ejemplo.com» en una regla: allí no se aplica
        if (exception || negated)
            m_cosmeticExceptions[domain].insert(selector);
        else
            m_cosmetic[domain].append(selector);
        added = true;
    }
    if (added)
        ++m_ruleCount;
}

bool FilterEngine::documentAllowed(const QByteArray &pageUrl, const QByteArray &pageHost) const
{
    if (pageUrl.isEmpty())
        return false;
    Request page;
    page.url = pageUrl;
    page.host = pageHost;
    page.pageUrl = pageUrl;
    page.pageHost = pageHost;
    page.type = Document;
    return m_allowDocument.matches(page, tokenize(pageUrl));
}

bool FilterEngine::shouldBlock(const Request &request) const
{
    const std::vector<quint32> tokens = tokenize(request.url);
    // «important» puede más que las excepciones
    if (m_blockImportant.matches(request, tokens))
        return true;

    bool blocked = false;
    QByteArray domain = m_blockHosts.match(request.host);
    if (domain.isEmpty() && request.thirdParty)
        domain = m_blockThirdPartyHosts.match(request.host);
    // Si el usuario visita ese mismo dominio, sus recursos no se bloquean:
    // la página es lo que ha pedido (y sin ellos se rompería)
    if (!domain.isEmpty() && !isSameOrSubdomain(request.pageHost, domain))
        blocked = true;
    if (!blocked)
        blocked = m_block.matches(request, tokens);
    if (!blocked)
        return false;
    if (!m_allowHosts.match(request.host).isEmpty())
        return false;
    return !m_allow.matches(request, tokens);
}

QByteArray FilterEngine::cosmeticCss(const QByteArray &pageUrl, const QByteArray &host) const
{
    if (m_cosmetic.isEmpty() || host.isEmpty())
        return QByteArray();
    QList<QByteArray> selectors;
    QSet<QByteArray> exceptions;
    for (const QByteArray &key : hostKeys(host)) {
        selectors += m_cosmetic.value(key);
        exceptions += m_cosmeticExceptions.value(key);
    }
    if (selectors.isEmpty())
        return QByteArray();
    Request page;
    page.url = pageUrl;
    page.host = host;
    page.pageUrl = pageUrl;
    page.pageHost = host;
    page.type = Document;
    const std::vector<quint32> tokens = tokenize(pageUrl);
    if (m_allowDocument.matches(page, tokens) || m_allowElemHide.matches(page, tokens))
        return QByteArray();
    // Una regla por selector: si uno no es válido, solo se pierde ese
    QByteArray css;
    QSet<QByteArray> seen;
    for (const QByteArray &selector : std::as_const(selectors)) {
        if (exceptions.contains(selector) || seen.contains(selector))
            continue;
        seen.insert(selector);
        css += selector + "{display:none!important}\n";
    }
    return css;
}

QList<QByteArray> FilterEngine::hostKeys(const QByteArray &host)
{
    QList<QByteArray> keys;
    qsizetype from = 0;
    while (from >= 0 && from < host.size()) {
        keys.append(host.mid(from));
        const qsizetype dot = host.indexOf('.', from);
        from = dot < 0 ? -1 : dot + 1;
    }
    // Entidades: lo que va antes del sufijo público (com, com.co…) con «*»
    // («www.google.com.co» → «www.google.*», «google.*»). No en las IP.
    const QByteArray base = baseDomain(host);
    const qsizetype dot = base.indexOf('.');
    if (dot > 0 && !(host.back() >= '0' && host.back() <= '9') && !host.contains(':')) {
        const qsizetype suffixSize = base.size() - dot - 1;
        const qsizetype count = keys.size();
        for (qsizetype i = 0; i < count; ++i) {
            const QByteArray &key = keys.at(i);
            if (key.size() > suffixSize + 1)
                keys.append(key.left(key.size() - suffixSize) + '*');
        }
    }
    return keys;
}

void FilterEngine::parseScriptlet(const QByteArray &domains, const QByteArray &body, bool exception)
{
    int index = -1;
    if (!body.trimmed().isEmpty()) {
        const QList<QByteArray> args = scriptletArgs(body);
        if (args.isEmpty())
            return;
        const QByteArray name = scriptletName(args.first());
        if (name.isEmpty())
            return;
        // Nombre y argumentos en JSON: la entrada de scriptlets.js
        QByteArray code = '[' + jsonString(name);
        for (qsizetype i = 1; i < args.size(); ++i)
            code += ',' + jsonString(args.at(i));
        code += ']';
        const auto found = m_scriptletIndex.constFind(code);
        if (found != m_scriptletIndex.constEnd()) {
            index = *found;
        } else {
            index = int(m_scriptletCodes.size());
            m_scriptletCodes.push_back(code);
            m_scriptletIndex.insert(code, index);
        }
    } else if (!exception) {
        return;
    }
    // «#@#+js()»: ningún scriptlet en esos dominios
    QList<QByteArray> positive;
    QList<QByteArray> negative;
    for (QByteArray domain : domains.toLower().split(',')) {
        domain = domain.trimmed();
        const bool negated = domain.startsWith('~');
        if (negated)
            domain = domain.mid(1);
        if (domain.isEmpty() || domain.indexOf('*') != (domain.endsWith(".*") ? domain.size() - 1 : -1)
            || domain.contains('/'))
            continue;
        (negated ? negative : positive).append(domain);
    }
    if (exception) {
        for (const QByteArray &domain : std::as_const(positive))
            m_scriptletExceptions[domain].push_back(index);
        if (!positive.isEmpty())
            ++m_ruleCount;
        return;
    }
    // Solo con «~dominio»: sería genérica
    if (positive.isEmpty())
        return;
    for (const QByteArray &domain : std::as_const(positive))
        m_scriptlets[domain].push_back(index);
    for (const QByteArray &domain : std::as_const(negative))
        m_scriptletExceptions[domain].push_back(index);
    ++m_ruleCount;
}

QByteArray FilterEngine::scriptlets(const QByteArray &pageUrl, const QByteArray &host) const
{
    if (m_scriptlets.isEmpty() || host.isEmpty())
        return QByteArray();
    std::vector<int> found;
    std::vector<int> exceptions;
    for (const QByteArray &key : hostKeys(host)) {
        const auto rules = m_scriptlets.constFind(key);
        if (rules != m_scriptlets.constEnd())
            found.insert(found.end(), rules->begin(), rules->end());
        const auto except = m_scriptletExceptions.constFind(key);
        if (except != m_scriptletExceptions.constEnd())
            exceptions.insert(exceptions.end(), except->begin(), except->end());
    }
    if (found.empty() || std::find(exceptions.begin(), exceptions.end(), -1) != exceptions.end())
        return QByteArray();
    if (documentAllowed(pageUrl, host))
        return QByteArray();
    QByteArray json = "[";
    std::vector<int> seen;
    for (const int index : found) {
        if (std::find(exceptions.begin(), exceptions.end(), index) != exceptions.end()
            || std::find(seen.begin(), seen.end(), index) != seen.end())
            continue;
        seen.push_back(index);
        if (json.size() > 1)
            json += ',';
        json += m_scriptletCodes[size_t(index)];
    }
    if (seen.empty())
        return QByteArray();
    return json + ']';
}
