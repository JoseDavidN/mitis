#include "hybrid.h"

#include "filterengine.h"

#include <QCborArray>
#include <QCborMap>
#include <QCborStreamReader>
#include <QCborValue>
#include <QCryptographicHash>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDateTime>
#include <QJsonArray>
#include <QMessageAuthenticationCode>
#include <QNetworkProxy>
#include <QRandomGenerator>
#include <QSslSocket>
#include <QTimer>
#include <QtEndian>

#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/params.h>

using ManagedObjects = QMap<QDBusObjectPath, QMap<QString, QVariantMap>>;
Q_DECLARE_METATYPE(ManagedObjects)
using InterfaceMap = QMap<QString, QVariantMap>;
Q_DECLARE_METATYPE(InterfaceMap)

namespace {

const QString BluezService = QStringLiteral("org.bluez");
const QString AdapterInterface = QStringLiteral("org.bluez.Adapter1");
const QString DeviceInterface = QStringLiteral("org.bluez.Device1");
const QString PropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
// Servicio Bluetooth del anuncio caBLE (FIDO y el antiguo de Google)
const QString FidoCableUuid = QStringLiteral("0000fff9-0000-1000-8000-00805f9b34fb");
const QString GoogleCableUuid = QStringLiteral("0000fde2-0000-1000-8000-00805f9b34fb");
// Servidores de túnel conocidos (v2_handshake.cc, kAssignedDomains): el
// primero es el de Google; el segundo, el de Apple (iPhone)
const char *const AssignedDomains[] = { "cable.ua5v.com", "cable.auth.com" };
// Tiempo máximo para todo (el de Chrome, si la página no pide menos)
constexpr int TimeoutMs = 3 * 60 * 1000;

enum DerivedValueType : quint32 { EIDKey = 1, TunnelID = 2, PSK = 3 };
enum MessageType : quint8 { Shutdown = 0, Ctap = 1, Update = 2 };

// ── Cifrado ───────────────────────────────────────────────────────────

QByteArray randomBytes(int size)
{
    QByteArray bytes(size, Qt::Uninitialized);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32 *>(bytes.data()), size / 4);
    return bytes;
}

QByteArray sha256(const QByteArray &data)
{
    return QCryptographicHash::hash(data, QCryptographicHash::Sha256);
}

QByteArray hmac(const QByteArray &key, const QByteArray &data)
{
    return QMessageAuthenticationCode::hash(data, key, QCryptographicHash::Sha256);
}

// HKDF-SHA256 (RFC 5869). Una sal vacía equivale a 32 ceros (HMAC rellena la clave)
QByteArray hkdf(const QByteArray &ikm, const QByteArray &salt, const QByteArray &info, int length)
{
    const QByteArray prk = hmac(salt, ikm);
    QByteArray okm;
    QByteArray block;
    for (quint8 counter = 1; okm.size() < length; ++counter) {
        block = hmac(prk, block + info + char(counter));
        okm += block;
    }
    return okm.left(length);
}

// Derive() de Chromium: HKDF con el tipo (uint32 en little-endian) como info
QByteArray derive(const QByteArray &secret, const QByteArray &nonce, DerivedValueType type, int length)
{
    QByteArray info(4, Qt::Uninitialized);
    qToLittleEndian<quint32>(type, info.data());
    return hkdf(secret, nonce, info, length);
}

EVP_PKEY *newP256Key()
{
    return EVP_PKEY_Q_keygen(nullptr, nullptr, "EC", "P-256");
}

// Pública sin comprimir (0x04 ‖ x ‖ y, 65 bytes)
QByteArray publicKeyOf(EVP_PKEY *key)
{
    QByteArray out(65, Qt::Uninitialized);
    size_t length = 0;
    if (!EVP_PKEY_get_octet_string_param(key, OSSL_PKEY_PARAM_ENCODED_PUBLIC_KEY,
                                         reinterpret_cast<unsigned char *>(out.data()), out.size(), &length)
        || length != 65)
        return {};
    return out;
}

QByteArray compressed(const QByteArray &uncompressed)
{
    QByteArray out;
    out.append(char((quint8(uncompressed.at(64)) & 1) ? 0x03 : 0x02));
    out.append(uncompressed.mid(1, 32));
    return out;
}

// ECDH P-256: la x del punto compartido (32 bytes); vacío si `peer` no es un punto válido
QByteArray ecdh(EVP_PKEY *own, const QByteArray &peer)
{
    QByteArray secret;
    EVP_PKEY_CTX *build = EVP_PKEY_CTX_new_from_name(nullptr, "EC", nullptr);
    EVP_PKEY *peerKey = nullptr;
    char group[] = "P-256";
    OSSL_PARAM params[] = {
        OSSL_PARAM_construct_utf8_string(OSSL_PKEY_PARAM_GROUP_NAME, group, 0),
        OSSL_PARAM_construct_octet_string(OSSL_PKEY_PARAM_PUB_KEY, const_cast<char *>(peer.constData()), size_t(peer.size())),
        OSSL_PARAM_construct_end(),
    };
    if (build && EVP_PKEY_fromdata_init(build) > 0 && EVP_PKEY_fromdata(build, &peerKey, EVP_PKEY_PUBLIC_KEY, params) > 0) {
        EVP_PKEY_CTX *derive = EVP_PKEY_CTX_new(own, nullptr);
        size_t length = 32;
        secret.resize(32);
        if (!derive || EVP_PKEY_derive_init(derive) <= 0 || EVP_PKEY_derive_set_peer(derive, peerKey) <= 0
            || EVP_PKEY_derive(derive, reinterpret_cast<unsigned char *>(secret.data()), &length) <= 0 || length != 32)
            secret.clear();
        EVP_PKEY_CTX_free(derive);
    }
    EVP_PKEY_free(peerKey);
    EVP_PKEY_CTX_free(build);
    return secret;
}

QByteArray aesEcbDecryptBlock(const QByteArray &key, const QByteArray &block)
{
    QByteArray out(32, Qt::Uninitialized);
    int length = 0;
    int extra = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    const bool ok = EVP_DecryptInit_ex(ctx, EVP_aes_256_ecb(), nullptr, reinterpret_cast<const unsigned char *>(key.constData()), nullptr) > 0
        && EVP_CIPHER_CTX_set_padding(ctx, 0) > 0
        && EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char *>(out.data()), &length,
                             reinterpret_cast<const unsigned char *>(block.constData()), block.size()) > 0
        && EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + length, &extra) > 0;
    EVP_CIPHER_CTX_free(ctx);
    return ok ? out.left(length + extra) : QByteArray();
}

// AES-256-GCM: texto cifrado ‖ etiqueta (16 bytes)
QByteArray gcmSeal(const QByteArray &key, const QByteArray &nonce, const QByteArray &plaintext, const QByteArray &aad)
{
    QByteArray out(plaintext.size() + 16, Qt::Uninitialized);
    int length = 0;
    int extra = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    bool ok = EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                                 reinterpret_cast<const unsigned char *>(key.constData()),
                                 reinterpret_cast<const unsigned char *>(nonce.constData())) > 0;
    if (ok && !aad.isEmpty())
        ok = EVP_EncryptUpdate(ctx, nullptr, &length, reinterpret_cast<const unsigned char *>(aad.constData()), aad.size()) > 0;
    length = 0;
    if (ok && !plaintext.isEmpty())
        ok = EVP_EncryptUpdate(ctx, reinterpret_cast<unsigned char *>(out.data()), &length,
                               reinterpret_cast<const unsigned char *>(plaintext.constData()), plaintext.size()) > 0;
    ok = ok && EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + length, &extra) > 0
        && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, out.data() + plaintext.size()) > 0;
    EVP_CIPHER_CTX_free(ctx);
    return ok ? out : QByteArray();
}

bool gcmOpen(const QByteArray &key, const QByteArray &nonce, const QByteArray &sealed, const QByteArray &aad, QByteArray *plaintext)
{
    if (sealed.size() < 16)
        return false;
    const QByteArray ciphertext = sealed.left(sealed.size() - 16);
    QByteArray tag = sealed.right(16);
    QByteArray out(ciphertext.size() + 16, Qt::Uninitialized);
    int length = 0;
    int extra = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    bool ok = EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                                 reinterpret_cast<const unsigned char *>(key.constData()),
                                 reinterpret_cast<const unsigned char *>(nonce.constData())) > 0;
    if (ok && !aad.isEmpty())
        ok = EVP_DecryptUpdate(ctx, nullptr, &length, reinterpret_cast<const unsigned char *>(aad.constData()), aad.size()) > 0;
    length = 0;
    if (ok && !ciphertext.isEmpty())
        ok = EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char *>(out.data()), &length,
                               reinterpret_cast<const unsigned char *>(ciphertext.constData()), ciphertext.size()) > 0;
    ok = ok && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, tag.data()) > 0
        && EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + length, &extra) > 0;
    EVP_CIPHER_CTX_free(ctx);
    if (ok)
        *plaintext = out.left(length + extra);
    return ok;
}

QByteArray base64url(const QByteArray &bytes)
{
    return bytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
}

QByteArray fromBase64url(const QJsonValue &value)
{
    return QByteArray::fromBase64(value.toString().toLatin1(), QByteArray::Base64UrlEncoding);
}

// Bytes → cifras del QR (v2_handshake.cc, BytesToDigits): 7 bytes → 17 cifras
QString bytesToDigits(const QByteArray &in)
{
    static const int partialDigits[] = { 0, 3, 5, 8, 10, 13, 15 };
    QString out;
    for (qsizetype offset = 0; offset < in.size(); offset += 7) {
        const qsizetype chunk = qMin<qsizetype>(7, in.size() - offset);
        quint64 value = 0;
        for (qsizetype i = 0; i < chunk; ++i)
            value |= quint64(quint8(in.at(offset + i))) << (8 * i);
        out += QStringLiteral("%1").arg(value, chunk == 7 ? 17 : partialDigits[chunk], 10, QLatin1Char('0'));
    }
    return out;
}

// Dominio de un servidor de túnel (tunnelserver::DecodeDomain)
QString decodeDomain(quint16 domain)
{
    if (domain < 256)
        return domain < std::size(AssignedDomains) ? QString::fromLatin1(AssignedDomains[domain]) : QString();
    QByteArray templ("caBLEv2 tunnel server domain\0\0\0", 31);
    qToLittleEndian<quint16>(domain, templ.data() + 28);
    const QByteArray digest = sha256(templ);
    quint64 result = qFromLittleEndian<quint64>(digest.constData());
    static const char base32[] = "abcdefghijklmnopqrstuvwxyz234567";
    static const char *const tlds[] = { "com", "org", "net", "info" };
    const int tld = int(result & 3);
    result >>= 2;
    QString ret = QStringLiteral("cable.");
    while (result != 0) {
        ret += QLatin1Char(base32[result & 31]);
        result >>= 5;
    }
    return ret + u'.' + QLatin1String(tlds[tld]);
}

// CBOR leído entero (como cbor::Reader de Chromium): falla si sobra algo
bool readWholeCbor(const QByteArray &bytes, QCborValue *value)
{
    QCborStreamReader reader(bytes);
    *value = QCborValue::fromCbor(reader);
    return reader.lastError() == QCborError::NoError && reader.currentOffset() == bytes.size();
}

} // namespace

// ── Noise (noise.cc de Chromium; la cifra lleva el contador en los 4 primeros bytes) ──

struct HybridAuthenticator::Noise {
    QByteArray ck;
    QByteArray h;
    QByteArray key;
    quint32 nonce = 0;

    void init(const QByteArray &name)
    {
        ck = name.leftJustified(32, '\0', true);
        h = ck;
    }
    void mixHash(const QByteArray &in) { h = sha256(h + in); }
    void mixKey(const QByteArray &ikm)
    {
        const QByteArray out = hkdf(ikm, ck, {}, 64);
        ck = out.left(32);
        key = out.mid(32);
        nonce = 0;
    }
    void mixKeyAndHash(const QByteArray &ikm)
    {
        const QByteArray out = hkdf(ikm, ck, {}, 96);
        ck = out.left(32);
        mixHash(out.mid(32, 32));
        key = out.mid(64);
        nonce = 0;
    }
    QByteArray nonceBytes()
    {
        QByteArray bytes(12, '\0');
        qToBigEndian<quint32>(nonce++, bytes.data());
        return bytes;
    }
    QByteArray encryptAndHash(const QByteArray &plaintext)
    {
        const QByteArray ciphertext = gcmSeal(key, nonceBytes(), plaintext, h);
        mixHash(ciphertext);
        return ciphertext;
    }
    bool decryptAndHash(const QByteArray &ciphertext, QByteArray *plaintext)
    {
        if (!gcmOpen(key, nonceBytes(), ciphertext, h, plaintext))
            return false;
        mixHash(ciphertext);
        return true;
    }
    // (escritura, lectura) para quien inicia
    std::pair<QByteArray, QByteArray> trafficKeys() const
    {
        const QByteArray out = hkdf({}, ck, {}, 64);
        return { out.left(32), out.mid(32) };
    }
};

HybridAuthenticator::HybridAuthenticator(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<InterfaceMap>();
    qDBusRegisterMetaType<ManagedObjects>();
}

HybridAuthenticator::~HybridAuthenticator()
{
    stopScan();
    if (m_socket)
        m_socket->abort();
    EVP_PKEY_free(static_cast<EVP_PKEY *>(m_identity));
    delete m_noise;
}

void HybridAuthenticator::setState(const QString &state)
{
    if (!m_done)
        emit stateChanged(state);
}

void HybridAuthenticator::fail(const QString &name, const QString &message)
{
    if (m_done)
        return;
    m_done = true;
    stopScan();
    if (m_socket)
        m_socket->abort();
    qInfo("Llave de acceso con el móvil: %s (%s)", qPrintable(name), qPrintable(message));
    emit finished(QJsonObject{ { QStringLiteral("error"), name }, { QStringLiteral("message"), message } });
}

void HybridAuthenticator::succeed(const QJsonObject &result)
{
    if (m_done)
        return;
    m_done = true;
    stopScan();
    qInfo("Llave de acceso con el móvil: hecho (%s)", qPrintable(m_kind));
    emit finished(result);
}

void HybridAuthenticator::cancel()
{
    fail(QStringLiteral("NotAllowedError"), QStringLiteral("The operation either timed out or was not allowed."));
}

// ── Petición: comprobaciones de WebAuthn, datos del cliente y CTAP2 ──

bool HybridAuthenticator::start(const QString &kind, const QJsonObject &options, const QUrl &page, QString *error)
{
    m_kind = kind;
    const QString host = page.host().toLower();
    const bool localhost = host == QLatin1String("localhost");
    if (host.isEmpty() || (page.scheme() != QLatin1String("https") && !localhost)) {
        *error = QStringLiteral("SecurityError");
        return false;
    }
    m_origin = page.scheme() + QStringLiteral("://") + host + (page.port() != -1 ? u':' + QString::number(page.port()) : QString());

    // Id. del sitio (rpId): el dominio de la página o uno de sus padres, sin
    // pasar del dominio registrable (no «com» ni «co.uk»)
    const QJsonObject rp = options.value(QStringLiteral("rp")).toObject();
    m_rpId = (kind == QLatin1String("create") ? rp.value(QStringLiteral("id")) : options.value(QStringLiteral("rpId"))).toString(host).toLower();
    const QString base = QString::fromLatin1(FilterEngine::baseDomain(host.toLatin1()));
    const bool suffix = m_rpId == host || host.endsWith(u'.' + m_rpId);
    if (!suffix || (!localhost && !m_rpId.endsWith(base)) || (!localhost && m_rpId.size() < base.size())) {
        *error = QStringLiteral("SecurityError");
        return false;
    }

    const QByteArray challenge = fromBase64url(options.value(QStringLiteral("challenge")));
    if (challenge.isEmpty()) {
        *error = QStringLiteral("TypeError");
        return false;
    }
    // collectedClientData, en el orden de Chrome
    m_clientDataJson = "{\"type\":\"" + QByteArray(kind == QLatin1String("create") ? "webauthn.create" : "webauthn.get")
        + "\",\"challenge\":\"" + base64url(challenge) + "\",\"origin\":\"" + m_origin.toUtf8()
        + "\",\"crossOrigin\":false}";
    const QByteArray clientDataHash = sha256(m_clientDataJson);

    const QString verification = kind == QLatin1String("create")
        ? options.value(QStringLiteral("authenticatorSelection")).toObject().value(QStringLiteral("userVerification")).toString()
        : options.value(QStringLiteral("userVerification")).toString();
    const bool uv = verification != QLatin1String("discouraged");

    // Descriptores de credenciales ({ "id", "type" }: CBOR canónico, claves por longitud)
    const auto descriptors = [](const QJsonArray &list) {
        QCborArray array;
        for (const QJsonValue &item : list) {
            const QByteArray id = fromBase64url(item.toObject().value(QStringLiteral("id")));
            if (id.isEmpty())
                continue;
            QCborMap descriptor;
            descriptor.insert(QStringLiteral("id"), id);
            descriptor.insert(QStringLiteral("type"), QStringLiteral("public-key"));
            array.append(descriptor);
        }
        return array;
    };

    QCborMap params;
    quint8 command;
    if (kind == QLatin1String("create")) {
        command = 0x01; // authenticatorMakeCredential
        const QJsonObject user = options.value(QStringLiteral("user")).toObject();
        const QByteArray userId = fromBase64url(user.value(QStringLiteral("id")));
        if (userId.isEmpty() || userId.size() > 64) {
            *error = QStringLiteral("TypeError");
            return false;
        }
        QCborMap rpMap;
        rpMap.insert(QStringLiteral("id"), m_rpId);
        if (rp.contains(QStringLiteral("name")))
            rpMap.insert(QStringLiteral("name"), rp.value(QStringLiteral("name")).toString());
        QCborMap userMap;
        userMap.insert(QStringLiteral("id"), userId);
        userMap.insert(QStringLiteral("name"), user.value(QStringLiteral("name")).toString());
        userMap.insert(QStringLiteral("displayName"), user.value(QStringLiteral("displayName")).toString());
        QCborArray algorithms;
        for (const QJsonValue &item : options.value(QStringLiteral("pubKeyCredParams")).toArray()) {
            QCborMap algorithm;
            algorithm.insert(QStringLiteral("alg"), item.toObject().value(QStringLiteral("alg")).toInteger());
            algorithm.insert(QStringLiteral("type"), QStringLiteral("public-key"));
            algorithms.append(algorithm);
        }
        const QJsonObject selection = options.value(QStringLiteral("authenticatorSelection")).toObject();
        const QString residentKey = selection.value(QStringLiteral("residentKey")).toString();
        const bool rk = residentKey == QLatin1String("required") || residentKey == QLatin1String("preferred")
            || selection.value(QStringLiteral("requireResidentKey")).toBool();
        const QString attestation = options.value(QStringLiteral("attestation")).toString();
        m_attestationNone = attestation != QLatin1String("direct") && attestation != QLatin1String("enterprise")
            && attestation != QLatin1String("indirect");

        params.insert(1, clientDataHash);
        params.insert(2, rpMap);
        params.insert(3, userMap);
        params.insert(4, algorithms);
        const QCborArray exclude = descriptors(options.value(QStringLiteral("excludeCredentials")).toArray());
        if (!exclude.isEmpty())
            params.insert(5, exclude);
        QCborMap flags;
        flags.insert(QStringLiteral("rk"), rk);
        if (uv)
            flags.insert(QStringLiteral("uv"), true);
        params.insert(7, flags);
    } else {
        command = 0x02; // authenticatorGetAssertion
        params.insert(1, m_rpId);
        params.insert(2, clientDataHash);
        const QCborArray allow = descriptors(options.value(QStringLiteral("allowCredentials")).toArray());
        if (!allow.isEmpty())
            params.insert(3, allow);
        if (allow.size() == 1)
            m_singleAllowed = allow.at(0).toMap().value(QStringLiteral("id")).toByteArray();
        if (uv) {
            QCborMap flags;
            flags.insert(QStringLiteral("uv"), true);
            params.insert(5, flags);
        }
    }
    m_ctapRequest = QByteArray(1, char(command)) + params.toCborValue().toCbor();

    // Claves de la sesión y QR (qr::Encode)
    m_qrSecret = randomBytes(16);
    m_identity = newP256Key();
    m_identityPublic = publicKeyOf(static_cast<EVP_PKEY *>(m_identity));
    if (m_identityPublic.isEmpty()) {
        *error = QStringLiteral("NotSupportedError");
        return false;
    }
    m_eidKey = derive(m_qrSecret, {}, EIDKey, 64);
    QCborMap qr;
    qr.insert(0, compressed(m_identityPublic));
    qr.insert(1, m_qrSecret);
    qr.insert(2, qint64(std::size(AssignedDomains)));
    qr.insert(3, QDateTime::currentSecsSinceEpoch());
    qr.insert(4, false); // sin vincular el móvil (Chrome tampoco, en WebAuthn)
    qr.insert(5, kind == QLatin1String("create") ? QStringLiteral("mc") : QStringLiteral("ga"));
    m_qrText = QStringLiteral("FIDO:/") + bytesToDigits(qr.toCborValue().toCbor());

    const int timeout = options.value(QStringLiteral("timeout")).toInt(TimeoutMs);
    m_timeout = new QTimer(this);
    m_timeout->setSingleShot(true);
    connect(m_timeout, &QTimer::timeout, this, [this] { fail(QStringLiteral("NotAllowedError"), QStringLiteral("Timed out")); });
    m_timeout->start(qBound(30000, timeout, TimeoutMs));

    // Bluetooth: después de devolver el QR (los avisos de estado llegan luego)
    QTimer::singleShot(0, this, [this] {
        if (startScan())
            setState(QStringLiteral("scanning"));
    });
    return true;
}

// ── Bluetooth (BlueZ) ─────────────────────────────────────────────────

bool HybridAuthenticator::startScan()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    QDBusMessage call = QDBusMessage::createMethodCall(BluezService, QStringLiteral("/"),
                                                       QStringLiteral("org.freedesktop.DBus.ObjectManager"),
                                                       QStringLiteral("GetManagedObjects"));
    const QDBusReply<ManagedObjects> objects = bus.call(call, QDBus::Block, 3000);
    if (!objects.isValid()) {
        setState(QStringLiteral("noBluetooth"));
        return false;
    }
    m_adapterPath.clear();
    bool powered = false;
    for (auto it = objects.value().cbegin(); it != objects.value().cend(); ++it) {
        if (it.value().contains(AdapterInterface)) {
            m_adapterPath = it.key().path();
            powered = it.value().value(AdapterInterface).value(QStringLiteral("Powered")).toBool();
            break;
        }
    }
    if (m_adapterPath.isEmpty()) {
        setState(QStringLiteral("noBluetooth"));
        return false;
    }
    if (!powered) {
        setState(QStringLiteral("bluetoothOff"));
        return false;
    }
    bus.connect(BluezService, QString(), PropertiesInterface, QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString,QVariantMap,QStringList,QDBusMessage)));
    bus.connect(BluezService, QStringLiteral("/"), QStringLiteral("org.freedesktop.DBus.ObjectManager"),
                QStringLiteral("InterfacesAdded"), this, SLOT(onInterfacesAdded(QDBusMessage)));
    // Solo Bluetooth LE, avisando de cada anuncio aunque se repita
    QDBusMessage filter = QDBusMessage::createMethodCall(BluezService, m_adapterPath, AdapterInterface,
                                                         QStringLiteral("SetDiscoveryFilter"));
    filter << QVariantMap{ { QStringLiteral("Transport"), QStringLiteral("le") },
                           { QStringLiteral("DuplicateData"), true } };
    bus.call(filter, QDBus::Block, 3000);
    const QDBusMessage started = bus.call(QDBusMessage::createMethodCall(BluezService, m_adapterPath, AdapterInterface,
                                                                         QStringLiteral("StartDiscovery")),
                                          QDBus::Block, 3000);
    if (started.type() == QDBusMessage::ErrorMessage
        && started.errorName() != QLatin1String("org.bluez.Error.InProgress")) {
        qWarning("Llave de acceso con el móvil: no se pudo buscar por Bluetooth (%s)", qPrintable(started.errorMessage()));
        setState(QStringLiteral("noBluetooth"));
        return false;
    }
    m_scanning = true;
    qInfo("Llave de acceso con el móvil: buscando el anuncio por Bluetooth (%s)", qPrintable(m_adapterPath));
    // Los dispositivos que BlueZ ya conocía: su último anuncio
    for (auto it = objects.value().cbegin(); it != objects.value().cend(); ++it) {
        if (it.value().contains(DeviceInterface))
            handleServiceData(it.value().value(DeviceInterface).value(QStringLiteral("ServiceData")));
    }
    return true;
}

void HybridAuthenticator::stopScan()
{
    if (!m_scanning)
        return;
    m_scanning = false;
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.disconnect(BluezService, QString(), PropertiesInterface, QStringLiteral("PropertiesChanged"), this,
                   SLOT(onPropertiesChanged(QString,QVariantMap,QStringList,QDBusMessage)));
    bus.disconnect(BluezService, QStringLiteral("/"), QStringLiteral("org.freedesktop.DBus.ObjectManager"),
                   QStringLiteral("InterfacesAdded"), this, SLOT(onInterfacesAdded(QDBusMessage)));
    bus.asyncCall(QDBusMessage::createMethodCall(BluezService, m_adapterPath, AdapterInterface, QStringLiteral("StopDiscovery")));
}

void HybridAuthenticator::powerOnBluetooth()
{
    if (m_adapterPath.isEmpty() || m_done)
        return;
    QDBusMessage set = QDBusMessage::createMethodCall(BluezService, m_adapterPath, PropertiesInterface, QStringLiteral("Set"));
    set << AdapterInterface << QStringLiteral("Powered") << QVariant::fromValue(QDBusVariant(true));
    const QDBusMessage reply = QDBusConnection::systemBus().call(set, QDBus::Block, 5000);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning("Llave de acceso con el móvil: no se pudo encender el Bluetooth (%s)", qPrintable(reply.errorMessage()));
        return;
    }
    // El adaptador tarda un momento en estar listo
    QTimer::singleShot(1500, this, [this] {
        if (!m_done && startScan())
            setState(QStringLiteral("scanning"));
    });
}

void HybridAuthenticator::onPropertiesChanged(const QString &interface, const QVariantMap &changed,
                                              const QStringList &, const QDBusMessage &)
{
    if (interface == DeviceInterface && changed.contains(QStringLiteral("ServiceData")))
        handleServiceData(changed.value(QStringLiteral("ServiceData")));
}

void HybridAuthenticator::onInterfacesAdded(const QDBusMessage &message)
{
    if (message.arguments().size() < 2)
        return;
    InterfaceMap interfaces;
    message.arguments().at(1).value<QDBusArgument>() >> interfaces;
    if (interfaces.contains(DeviceInterface))
        handleServiceData(interfaces.value(DeviceInterface).value(QStringLiteral("ServiceData")));
}

void HybridAuthenticator::handleServiceData(const QVariant &value)
{
    if (!m_scanning || m_advertSeen || !value.isValid())
        return;
    QVariantMap serviceData;
    if (value.canConvert<QDBusArgument>())
        value.value<QDBusArgument>() >> serviceData;
    else
        serviceData = value.toMap();
    for (const QString &uuid : { FidoCableUuid, GoogleCableUuid }) {
        QVariant data = serviceData.value(uuid);
        if (data.canConvert<QDBusVariant>())
            data = data.value<QDBusVariant>().variant();
        const QByteArray advert = data.toByteArray();
        if (advert.size() == 20)
            handleAdvert(advert);
    }
}

// Anuncio del móvil: 16 bytes cifrados (AES-256) y 4 de HMAC (eid::Decrypt)
void HybridAuthenticator::handleAdvert(const QByteArray &advert)
{
    if (hmac(m_eidKey.mid(32), advert.left(16)).left(4) != advert.mid(16))
        return; // de otro dispositivo o de otro QR
    const QByteArray plaintext = aesEcbDecryptBlock(m_eidKey.left(32), advert.left(16));
    if (plaintext.size() != 16 || plaintext.at(0) != 0)
        return;
    const quint16 domainId = qFromLittleEndian<quint16>(plaintext.constData() + 14);
    const QString domain = decodeDomain(domainId);
    if (domain.isEmpty())
        return;
    m_advertSeen = true;
    m_eidPlaintext = plaintext;
    qInfo("Llave de acceso con el móvil: anuncio Bluetooth recibido; túnel %s", qPrintable(domain));
    stopScan();
    setState(QStringLiteral("connecting"));
    openTunnel(domain, plaintext.mid(11, 3));
}

// ── Túnel: WebSocket sobre TLS ─────────────────────────────────────────

void HybridAuthenticator::openTunnel(const QString &domain, const QByteArray &routingId)
{
    const QByteArray tunnelId = derive(m_qrSecret, {}, TunnelID, 16);
    const QByteArray path = "/cable/connect/" + routingId.toHex().toUpper() + '/' + tunnelId.toHex().toUpper();
    m_socket = new QSslSocket(this);
    // Como la red de la interfaz: sin el proxy de las páginas
    m_socket->setProxy(QNetworkProxy::NoProxy);
    connect(m_socket, &QSslSocket::encrypted, this, [this, domain, path] {
        const QByteArray key = randomBytes(16).toBase64();
        m_socket->write("GET " + path + " HTTP/1.1\r\nHost: " + domain.toLatin1()
                        + "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: " + key
                        + "\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: fido.cable\r\n\r\n");
    });
    connect(m_socket, &QSslSocket::readyRead, this, &HybridAuthenticator::onSocketReadable);
    connect(m_socket, &QSslSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        if (m_step != Step::Done)
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Tunnel error: ") + m_socket->errorString());
    });
    m_socket->connectToHostEncrypted(domain, 443);
}

void HybridAuthenticator::onSocketReadable()
{
    m_buffer += m_socket->readAll();
    if (!m_upgraded) {
        const qsizetype end = m_buffer.indexOf("\r\n\r\n");
        if (end < 0)
            return;
        const QByteArray head = m_buffer.left(end).toLower();
        m_buffer.remove(0, end + 4);
        if (!head.startsWith("http/1.1 101") || !head.contains("sec-websocket-protocol: fido.cable")) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Tunnel server refused: ")
                 + QString::fromLatin1(head.left(head.indexOf('\r'))));
            return;
        }
        m_upgraded = true;
        qInfo("Llave de acceso con el móvil: túnel abierto");
        // Primer mensaje del apretón de manos (HandshakeInitiator::BuildInitialMessage, KNpsk0)
        m_noise = new Noise;
        m_noise->init("Noise_KNpsk0_P256_AESGCM_SHA256");
        m_noise->mixHash(QByteArray(1, '\x01'));
        m_noise->mixHash(m_identityPublic);
        m_noise->mixKeyAndHash(derive(m_qrSecret, m_eidPlaintext, PSK, 32));
        EVP_PKEY *ephemeral = newP256Key();
        const QByteArray ephemeralPublic = publicKeyOf(ephemeral);
        m_noise->mixHash(ephemeralPublic);
        m_noise->mixKey(ephemeralPublic);
        const QByteArray ciphertext = m_noise->encryptAndHash({});
        // La efímera se guarda en la propia sesión hasta la respuesta
        setProperty("ephemeral", QVariant::fromValue(static_cast<void *>(ephemeral)));
        sendFrame(ephemeralPublic + ciphertext);
    }
    // Tramas del servidor (sin máscara)
    while (m_buffer.size() >= 2) {
        const quint8 b0 = quint8(m_buffer.at(0));
        const quint8 b1 = quint8(m_buffer.at(1));
        quint64 length = b1 & 0x7f;
        qsizetype offset = 2;
        if (length == 126) {
            if (m_buffer.size() < 4)
                return;
            length = qFromBigEndian<quint16>(m_buffer.constData() + 2);
            offset = 4;
        } else if (length == 127) {
            if (m_buffer.size() < 10)
                return;
            length = qFromBigEndian<quint64>(m_buffer.constData() + 2);
            offset = 10;
        }
        QByteArray mask;
        if (b1 & 0x80) {
            if (m_buffer.size() < offset + 4)
                return;
            mask = m_buffer.mid(offset, 4);
            offset += 4;
        }
        if (length > 1 << 20) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Tunnel frame too large"));
            return;
        }
        if (quint64(m_buffer.size() - offset) < length)
            return;
        QByteArray payload = m_buffer.mid(offset, qsizetype(length));
        m_buffer.remove(0, offset + qsizetype(length));
        if (!mask.isEmpty()) {
            for (qsizetype i = 0; i < payload.size(); ++i)
                payload[i] = char(payload.at(i) ^ mask.at(i % 4));
        }
        const bool fin = b0 & 0x80;
        switch (b0 & 0x0f) {
        case 0x0: // continuación
            m_fragment += payload;
            if (fin) {
                onTunnelMessage(m_fragment);
                m_fragment.clear();
            }
            break;
        case 0x1:
        case 0x2:
            if (fin)
                onTunnelMessage(payload);
            else
                m_fragment = payload;
            break;
        case 0x8: // cierre
            if (m_step != Step::Done)
                fail(QStringLiteral("NotAllowedError"), QStringLiteral("The phone closed the connection"));
            return;
        case 0x9: // ping
            sendFrame(payload, 0xA);
            break;
        default:
            break;
        }
        if (m_done)
            return;
    }
}

void HybridAuthenticator::sendFrame(const QByteArray &payload, quint8 opcode)
{
    QByteArray frame;
    frame.append(char(0x80 | opcode));
    if (payload.size() < 126) {
        frame.append(char(0x80 | payload.size()));
    } else if (payload.size() <= 0xffff) {
        frame.append(char(0x80 | 126));
        QByteArray length(2, Qt::Uninitialized);
        qToBigEndian<quint16>(quint16(payload.size()), length.data());
        frame.append(length);
    } else {
        frame.append(char(0x80 | 127));
        QByteArray length(8, Qt::Uninitialized);
        qToBigEndian<quint64>(quint64(payload.size()), length.data());
        frame.append(length);
    }
    // El cliente siempre enmascara (RFC 6455)
    const QByteArray mask = randomBytes(4);
    frame.append(mask);
    QByteArray masked = payload;
    for (qsizetype i = 0; i < masked.size(); ++i)
        masked[i] = char(masked.at(i) ^ mask.at(i % 4));
    frame.append(masked);
    m_socket->write(frame);
}

// Cifrado tras el apretón de manos (Crypter): relleno a múltiplos de 32 y
// contador en los 4 últimos bytes del nonce
QByteArray HybridAuthenticator::encrypt(const QByteArray &plaintext)
{
    const qsizetype padded = (plaintext.size() + 1 + 31) & ~qsizetype(31);
    QByteArray message = plaintext;
    message.append(QByteArray(padded - plaintext.size() - 1, '\0'));
    message.append(char(padded - plaintext.size() - 1));
    QByteArray nonce(12, '\0');
    qToBigEndian<quint32>(m_writeCounter++, nonce.data() + 8);
    return gcmSeal(m_writeKey, nonce, message, {});
}

bool HybridAuthenticator::decrypt(const QByteArray &ciphertext, QByteArray *plaintext)
{
    QByteArray nonce(12, '\0');
    qToBigEndian<quint32>(m_readCounter, nonce.data() + 8);
    QByteArray padded;
    if (!gcmOpen(m_readKey, nonce, ciphertext, {}, &padded) || padded.isEmpty())
        return false;
    ++m_readCounter;
    const int padding = quint8(padded.back());
    if (padding + 1 > padded.size())
        return false;
    *plaintext = padded.left(padded.size() - padding - 1);
    return true;
}

void HybridAuthenticator::onTunnelMessage(const QByteArray &message)
{
    switch (m_step) {
    case Step::Handshake: {
        // Respuesta: efímera del móvil (65 bytes) y 16 de etiqueta (ProcessResponse)
        auto *ephemeral = static_cast<EVP_PKEY *>(property("ephemeral").value<void *>());
        setProperty("ephemeral", QVariant());
        const QByteArray peer = message.left(65);
        const QByteArray ee = message.size() == 81 ? ecdh(ephemeral, peer) : QByteArray();
        const QByteArray se = ee.isEmpty() ? QByteArray() : ecdh(static_cast<EVP_PKEY *>(m_identity), peer);
        EVP_PKEY_free(ephemeral);
        QByteArray empty;
        if (se.isEmpty()) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Bad handshake response"));
            return;
        }
        m_noise->mixHash(peer);
        m_noise->mixKey(peer);
        m_noise->mixKey(ee);
        m_noise->mixKey(se);
        if (!m_noise->decryptAndHash(message.mid(65), &empty) || !empty.isEmpty()) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Handshake failed"));
            return;
        }
        std::tie(m_writeKey, m_readKey) = m_noise->trafficKeys();
        m_step = Step::PostHandshake;
        qInfo("Llave de acceso con el móvil: apretón de manos hecho");
        break;
    }
    case Step::PostHandshake: {
        QByteArray plaintext;
        if (!decrypt(message, &plaintext)) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Could not decrypt the phone's first message"));
            return;
        }
        // Versión 1: CBOR tal cual; versión 0 (antigua): con relleno al final
        QCborValue payload;
        int revision = 1;
        if (!readWholeCbor(plaintext, &payload)) {
            revision = 0;
            if (plaintext.size() >= 2) {
                const quint16 padding = qFromLittleEndian<quint16>(plaintext.constData() + plaintext.size() - 2);
                if (padding + 2 <= plaintext.size())
                    readWholeCbor(plaintext.left(plaintext.size() - padding - 2), &payload);
            }
        }
        if (!payload.isMap() || !payload.toMap().value(1).isByteArray()) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("The phone did not offer CTAP"));
            return;
        }
        setProperty("revision", revision);
        qInfo("Llave de acceso con el móvil: conectado (protocolo %d); esperando la confirmación", revision);
        setState(QStringLiteral("confirm"));
        sendRequest();
        break;
    }
    case Step::Request: {
        QByteArray plaintext;
        if (!decrypt(message, &plaintext)) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Could not decrypt the phone's answer"));
            return;
        }
        if (property("revision").toInt() >= 1) {
            if (plaintext.isEmpty())
                return;
            const quint8 type = quint8(plaintext.at(0));
            if (type == Update)
                return; // datos de vinculación: no se usan
            if (type != Ctap) {
                fail(QStringLiteral("NotAllowedError"), QStringLiteral("Unexpected message from the phone"));
                return;
            }
            plaintext.remove(0, 1);
        }
        handleResponse(plaintext);
        break;
    }
    case Step::Done:
        break;
    }
}

void HybridAuthenticator::sendRequest()
{
    QByteArray message = m_ctapRequest;
    if (property("revision").toInt() >= 1)
        message.prepend(char(Ctap));
    m_step = Step::Request;
    sendFrame(encrypt(message));
}

void HybridAuthenticator::handleResponse(const QByteArray &response)
{
    m_step = Step::Done;
    // Cierre ordenado del túnel (mensaje de cierre y fin de la conexión)
    if (property("revision").toInt() >= 1)
        sendFrame(encrypt(QByteArray(1, char(Shutdown))));
    m_socket->disconnectFromHost();

    if (response.isEmpty()) {
        fail(QStringLiteral("NotAllowedError"), QStringLiteral("Empty answer"));
        return;
    }
    const quint8 status = quint8(response.at(0));
    if (status != 0) {
        // CTAP2_ERR_CREDENTIAL_EXCLUDED: ya hay una llave para esta cuenta en el móvil
        if (status == 0x19)
            fail(QStringLiteral("InvalidStateError"), QStringLiteral("The authenticator was previously registered"));
        else
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("The phone answered with error 0x%1").arg(status, 2, 16, QLatin1Char('0')));
        return;
    }
    QCborValue value;
    readWholeCbor(response.mid(1), &value);
    if (!value.isMap()) {
        value = QCborValue::fromCbor(response.mid(1));
        if (!value.isMap()) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Invalid answer"));
            return;
        }
    }
    const QCborMap map = value.toMap();
    QJsonObject result{ { QStringLiteral("ok"), true },
                        { QStringLiteral("clientDataJSON"), QString::fromLatin1(base64url(m_clientDataJson)) } };

    if (m_kind == QLatin1String("get")) {
        QByteArray credentialId = map.value(1).toMap().value(QStringLiteral("id")).toByteArray();
        if (credentialId.isEmpty())
            credentialId = m_singleAllowed;
        const QByteArray authData = map.value(2).toByteArray();
        const QByteArray signature = map.value(3).toByteArray();
        if (credentialId.isEmpty() || authData.size() < 37 || signature.isEmpty()) {
            fail(QStringLiteral("NotAllowedError"), QStringLiteral("Incomplete assertion"));
            return;
        }
        const QByteArray userHandle = map.value(4).toMap().value(QStringLiteral("id")).toByteArray();
        result.insert(QStringLiteral("rawId"), QString::fromLatin1(base64url(credentialId)));
        result.insert(QStringLiteral("authenticatorData"), QString::fromLatin1(base64url(authData)));
        result.insert(QStringLiteral("signature"), QString::fromLatin1(base64url(signature)));
        result.insert(QStringLiteral("userHandle"), userHandle.isEmpty() ? QJsonValue() : QString::fromLatin1(base64url(userHandle)));
        succeed(result);
        return;
    }

    // makeCredential: { 1: fmt, 2: authData, 3: attStmt }
    QString format = map.value(1).toString();
    const QByteArray authData = map.value(2).toByteArray();
    QCborMap statement = map.value(3).toMap();
    // authData: rpIdHash(32) flags(1) signCount(4) aaguid(16) idLen(2) id clave(COSE)
    if (authData.size() < 55 || !(quint8(authData.at(32)) & 0x40)) {
        fail(QStringLiteral("NotAllowedError"), QStringLiteral("Incomplete attestation"));
        return;
    }
    const quint16 idLength = qFromBigEndian<quint16>(authData.constData() + 53);
    if (authData.size() < 55 + idLength) {
        fail(QStringLiteral("NotAllowedError"), QStringLiteral("Incomplete attestation"));
        return;
    }
    const QByteArray credentialId = authData.mid(55, idLength);
    if (m_attestationNone) {
        format = QStringLiteral("none");
        statement = QCborMap();
    }
    QCborMap attestation;
    attestation.insert(QStringLiteral("fmt"), format);
    attestation.insert(QStringLiteral("attStmt"), statement);
    attestation.insert(QStringLiteral("authData"), authData);

    // Clave pública en SPKI (getPublicKey()), solo ES256 (P-256)
    QJsonValue publicKey;
    qint64 algorithm = 0;
    const QByteArray coseBytes = authData.mid(55 + idLength);
    QCborStreamReader keyReader(coseBytes);
    const QCborMap cose = QCborValue::fromCbor(keyReader).toMap();
    algorithm = cose.value(3).toInteger();
    if (cose.value(1).toInteger() == 2 && cose.value(-1).toInteger() == 1 && algorithm == -7) {
        const QByteArray x = cose.value(-2).toByteArray();
        const QByteArray y = cose.value(-3).toByteArray();
        if (x.size() == 32 && y.size() == 32)
            publicKey = QString::fromLatin1(base64url(
                QByteArray::fromHex("3059301306072a8648ce3d020106082a8648ce3d030107034200") + char(0x04) + x + y));
    }
    result.insert(QStringLiteral("rawId"), QString::fromLatin1(base64url(credentialId)));
    result.insert(QStringLiteral("attestationObject"), QString::fromLatin1(base64url(attestation.toCborValue().toCbor())));
    result.insert(QStringLiteral("authenticatorData"), QString::fromLatin1(base64url(authData)));
    result.insert(QStringLiteral("publicKey"), publicKey);
    result.insert(QStringLiteral("publicKeyAlgorithm"), algorithm);
    succeed(result);
}
