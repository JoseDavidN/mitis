#include "filterengine.h"

#include <algorithm>

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
    for (const QByteArray &domain : domains) {
        if (isSameOrSubdomain(host, domain))
            return true;
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
        for (const QByteArray &raw : list.split('\n')) {
            const QByteArray line = raw.trimmed();
            if (line.contains("badfilter") && line.contains('$') && !line.startsWith('!'))
                badFilters.insert(withoutBadFilter(line));
        }
    }
    for (const QByteArray &list : lists) {
        for (const QByteArray &raw : list.split('\n'))
            parseLine(raw.trimmed(), badFilters);
    }
    m_blockHosts.finish();
    m_blockThirdPartyHosts.finish();
    m_allowHosts.finish();
    m_cosmetic.squeeze();
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
            // Las genéricas (sin dominio) no: costarían memoria en cada página.
            // «+js(…)» y «^…» son de uBlock Origin y no son CSS.
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
                    // «google.*» (entidades de uBlock Origin): no se entienden
                    if (domain.isEmpty() || domain.contains('*') || domain.contains('/'))
                        continue;
                    (exclude ? filter.notDomains : filter.domains).append(domain);
                }
                // Solo había entidades: la regla no se puede cumplir bien
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
        if (domain.isEmpty() || domain.contains('*') || domain.contains('/'))
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
    qsizetype from = 0;
    while (from >= 0 && from < host.size()) {
        const QByteArray suffix = host.mid(from);
        selectors += m_cosmetic.value(suffix);
        exceptions += m_cosmeticExceptions.value(suffix);
        const qsizetype dot = host.indexOf('.', from);
        from = dot < 0 ? -1 : dot + 1;
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
