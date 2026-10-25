#pragma once

#include <QObject>
#include <QStringList>
#include <QTemporaryDir>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// Imprimir y guardar como PDF con la ventana propia de Mitis (PrintDialog).
// La página la convierte el motor en un PDF (BrowserTab.printToPdf); aquí se
// guarda en un archivo temporal para la vista previa (QtQuick.Pdf), se copia
// donde el usuario elija o se manda a una impresora del sistema: cada página
// del PDF se dibuja (Qt PDF) sobre la impresora (Qt Print Support), en un
// hilo aparte para no congelar la ventana. En QML es el singleton `Printing`
// del módulo Mitis.Core.
class Printing : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Impresoras del sistema (nombres) y la predeterminada
    Q_PROPERTY(QStringList printers READ printers NOTIFY printersChanged)
    Q_PROPERTY(QString defaultPrinter READ defaultPrinter NOTIFY printersChanged)
    // Imprimiendo: la ventana espera
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Printing(QObject *parent = nullptr);

    QStringList printers() const { return m_printers; }
    QString defaultPrinter() const { return m_defaultPrinter; }
    bool busy() const { return m_busy; }

    // Vuelve a pedir la lista de impresoras al sistema
    Q_INVOKABLE void refreshPrinters();
    // Guarda el PDF de la página y devuelve su dirección para la vista previa.
    // Cada llamada usa un archivo nuevo (la vista previa no recarga el mismo)
    Q_INVOKABLE QUrl setDocument(const QByteArray &pdf);
    // Carpeta donde proponer guardar: Documentos, Descargas o la personal,
    // la primera que exista (el diálogo no puede abrirse en una que no existe)
    Q_INVOKABLE QUrl saveFolder() const;
    // Copia el PDF actual en `file`; falso si no se pudo
    Q_INVOKABLE bool saveDocument(const QUrl &file);
    // Manda el PDF actual a la impresora; termina con printFinished
    Q_INVOKABLE void print(const QString &printer, int copies, bool color, const QString &title);
    // Olvida el PDF actual y borra sus temporales (al cerrar la ventana)
    Q_INVOKABLE void clear();

signals:
    void printersChanged();
    void busyChanged();
    // error: vacío si salió bien; si no, el motivo en español
    void printFinished(const QString &error);

private:
    QStringList m_printers;
    QString m_defaultPrinter;
    // Se borra sola (con lo que tenga) al destruirse
    QTemporaryDir m_dir;
    QString m_current;
    int m_serial = 0;
    bool m_busy = false;
};
