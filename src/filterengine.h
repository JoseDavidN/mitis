#pragma once

#include <QByteArray>
#include <QHash>
#include <QList>
#include <QSet>

#include <cstdint>
#include <vector>

// Motor de filtros de anuncios y rastreadores: listas con la sintaxis de
// Adblock Plus / uBlock Origin (EasyList…) o de archivo hosts (Pi-hole),
// compiladas a estructuras rápidas. Se construye una vez (build(), en un
// hilo aparte) y después solo se consulta: es inmutable y no usa el motor web.
//
// Se entiende el subconjunto que cubre casi todas las reglas de red: «||»,
// «|», «*», «^», excepciones «@@», y las opciones de tipo (script, image…),
// first-party/third-party, domain=, important y badfilter. Una regla con
// una opción desconocida o que no se puede cumplir (redirect, csp,
// removeparam…) se descarta entera: aplicarla a medias rompe páginas. De la
// ocultación de elementos («##») solo las reglas de un sitio concreto.
class FilterEngine
{
public:
    enum Type : quint16 {
        Other = 1 << 0,
        Script = 1 << 1,
        Image = 1 << 2,
        Stylesheet = 1 << 3,
        Object = 1 << 4,
        Xhr = 1 << 5,
        Subdocument = 1 << 6,
        Ping = 1 << 7,
        Media = 1 << 8,
        Font = 1 << 9,
        WebSocket = 1 << 10,
        Document = 1 << 11,
        // Lo que afecta una regla sin tipos: todo menos la página entera
        AnyResource = Document - 1,
    };

    struct Request {
        QByteArray url;       // en minúsculas y codificada
        QByteArray host;      // host de la petición, en minúsculas
        QByteArray pageUrl;   // página que la hace (marco principal)
        QByteArray pageHost;
        Type type = Other;
        // De otro sitio que la página (dominio registrable distinto)
        bool thirdParty = false;
    };

    // Compila las listas (el texto de cada una)
    void build(const QList<QByteArray> &lists);

    bool shouldBlock(const Request &request) const;
    // La página tiene una excepción total (@@||sitio^$document): nada se bloquea
    bool documentAllowed(const QByteArray &pageUrl, const QByteArray &pageHost) const;
    // Reglas de ocultación para la página de `host`: CSS listo para inyectar
    // (vacío si no hay ninguna o la página las tiene desactivadas)
    QByteArray cosmeticCss(const QByteArray &pageUrl, const QByteArray &host) const;

    // Reglas aceptadas (de red y de ocultación)
    int ruleCount() const { return m_ruleCount; }

    // Dominio registrable aproximado: "a.b.ejemplo.com.co" → "ejemplo.com.co"
    static QByteArray baseDomain(const QByteArray &host);

private:
    struct Filter {
        QByteArray pattern;           // sin anclas ni opciones
        QList<QByteArray> domains;    // domain=: solo en estas páginas
        QList<QByteArray> notDomains; // domain=~: nunca en estas
        quint16 types = AnyResource;
        quint8 party = 0;             // 0 cualquiera, 1 propia, 2 de terceros
        bool hostAnchor = false;      // ||
        bool startAnchor = false;     // |…
        bool endAnchor = false;       // …|
        bool important = false;
    };
    // Filtros indexados por un token de su patrón (palabra que la dirección
    // debe contener entera): solo se prueban los de los tokens de la URL
    struct FilterSet {
        std::vector<Filter> filters;
        QHash<quint32, std::vector<int>> byToken;
        std::vector<int> untokened;
        void add(Filter &&filter);
        bool matches(const Request &request, const std::vector<quint32> &tokens) const;
    };
    // Dominios bloqueados en bloque (estilo Pi-hole): hashes ordenados
    struct HostSet {
        std::vector<quint64> hashes;
        void add(const QByteArray &host) { hashes.push_back(hostHash(host)); }
        void finish();
        // Sufijo de `host` que está en el conjunto (vacío si ninguno)
        QByteArray match(const QByteArray &host) const;
    };

    void parseLine(QByteArray line, const QSet<QByteArray> &badFilters);
    bool parseNetwork(QByteArray line);
    void parseCosmetic(const QByteArray &domains, const QByteArray &selector, bool exception);
    static quint64 hostHash(const QByteArray &host);
    static bool matchFilter(const Filter &filter, const Request &request);
    static std::vector<quint32> tokenize(const QByteArray &url);

    HostSet m_blockHosts;          // ||dominio^
    HostSet m_blockThirdPartyHosts; // ||dominio^$third-party
    HostSet m_allowHosts;          // @@||dominio^
    FilterSet m_block;
    FilterSet m_blockImportant;    // $important: pueden más que las excepciones
    FilterSet m_allow;
    FilterSet m_allowDocument;     // @@…$document: el sitio entero sin bloqueo
    FilterSet m_allowElemHide;     // @@…$elemhide: sin ocultar elementos
    QHash<QByteArray, QList<QByteArray>> m_cosmetic;          // dominio → selectores
    QHash<QByteArray, QSet<QByteArray>> m_cosmeticExceptions; // dominio → selectores
    int m_ruleCount = 0;
};
