#pragma once

#include <QByteArray>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QUrl>

class QSslSocket;
class QTimer;
class QDBusMessage;

// Llaves de acceso del móvil en Linux («usar un teléfono o tableta»), como
// en Chrome: el protocolo híbrido de FIDO (caBLE v2). Qt WebEngine solo trae
// llaves físicas (USB/NFC); esto lo hace Mitis por su cuenta, siguiendo el
// código de Chromium 140 (device/fido/cable: v2_handshake.cc, noise.cc,
// fido_tunnel_device.cc):
//   1. QR «FIDO:/<cifras>» con una clave pública P-256 de Mitis y un secreto.
//   2. El móvil lo escanea, se conecta al servidor de túnel y emite un
//      anuncio Bluetooth cifrado con ese secreto (BlueZ, por D-Bus).
//   3. Mitis lo descifra, abre el túnel (WebSocket, wss://<servidor>/cable/
//      connect/…) y hace el apretón de manos Noise KNpsk0 (P-256, AES-GCM).
//   4. Por el túnel cifrado: la petición CTAP2 (getAssertion/makeCredential)
//      y la respuesta, que se entrega a la página (assets/scripts/webauthn.js).
// Una petición por objeto; lo crea y destruye EngineBridge.
class HybridAuthenticator : public QObject
{
    Q_OBJECT

public:
    explicit HybridAuthenticator(QObject *parent = nullptr);
    ~HybridAuthenticator() override;

    // `kind`: "get" o "create"; `options`: publicKey de la página, con los
    // binarios en base64url; `page`: la dirección de la pestaña (el origen lo
    // pone Mitis, no la página). Falso con `error` («SecurityError»…) si la
    // petición no es válida para ese sitio.
    bool start(const QString &kind, const QJsonObject &options, const QUrl &page, QString *error);
    // «FIDO:/…» para el QR
    QString qrText() const { return m_qrText; }
    QString relyingParty() const { return m_rpId; }
    void cancel();
    // Enciende el Bluetooth (si estaba apagado) y vuelve a buscar
    void powerOnBluetooth();

signals:
    // "scanning" (QR a la vista), "bluetoothOff", "noBluetooth",
    // "connecting" (llegó el anuncio del móvil), "confirm" (túnel listo:
    // confirma en el móvil)
    void stateChanged(const QString &state);
    // { ok: true, … } o { error: "NotAllowedError", message }
    void finished(const QJsonObject &result);

private slots:
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated,
                             const QDBusMessage &message);
    void onInterfacesAdded(const QDBusMessage &message);

private:
    struct Noise;

    void setState(const QString &state);
    void fail(const QString &name, const QString &message);
    void succeed(const QJsonObject &result);
    // Bluetooth
    bool startScan();
    void stopScan();
    void handleServiceData(const QVariant &serviceData);
    void handleAdvert(const QByteArray &advert);
    // Túnel
    void openTunnel(const QString &domain, const QByteArray &routingId);
    void onSocketReadable();
    void sendFrame(const QByteArray &payload, quint8 opcode = 2);
    void onTunnelMessage(const QByteArray &message);
    QByteArray encrypt(const QByteArray &plaintext);
    bool decrypt(const QByteArray &ciphertext, QByteArray *plaintext);
    void sendRequest();
    void handleResponse(const QByteArray &response);

    // Petición
    QString m_kind;
    QString m_rpId;
    QString m_origin;
    QByteArray m_clientDataJson;
    QByteArray m_ctapRequest;   // comando CTAP + parámetros CBOR
    QByteArray m_singleAllowed; // getAssertion con una sola credencial permitida
    bool m_attestationNone = true;
    QString m_qrText;

    // Claves de la sesión
    QByteArray m_qrSecret;
    void *m_identity = nullptr; // EVP_PKEY P-256 (su pública va en el QR)
    QByteArray m_identityPublic; // sin comprimir, 65 bytes
    QByteArray m_eidKey;
    QByteArray m_eidPlaintext;
    Noise *m_noise = nullptr;
    QByteArray m_readKey;
    QByteArray m_writeKey;
    quint32 m_readCounter = 0;
    quint32 m_writeCounter = 0;

    // Bluetooth (BlueZ)
    QString m_adapterPath;
    bool m_scanning = false;
    bool m_advertSeen = false;

    // Túnel
    QSslSocket *m_socket = nullptr;
    QByteArray m_buffer;
    bool m_upgraded = false;
    QByteArray m_fragment;
    enum class Step { Handshake, PostHandshake, Request, Done } m_step = Step::Handshake;
    QTimer *m_timeout = nullptr;
    bool m_done = false;
};
