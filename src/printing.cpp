#include "printing.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QPdfDocument>
#include <QPrinter>
#include <QPrinterInfo>
#include <QStandardPaths>
#include <QThread>

#include <algorithm>
#include <memory>

namespace {
// Resolución a la que se dibujan las páginas para la impresora: más no se
// nota en papel y cada página ocuparía mucha más memoria mientras se imprime
constexpr int MaxPrintDpi = 300;
}

Printing::Printing(QObject *parent)
    : QObject(parent)
{
    refreshPrinters();
}

void Printing::refreshPrinters()
{
    QStringList printers = QPrinterInfo::availablePrinterNames();
    printers.sort(Qt::CaseInsensitive);
    const QString defaultPrinter = QPrinterInfo::defaultPrinterName();
    if (printers == m_printers && defaultPrinter == m_defaultPrinter)
        return;
    m_printers = printers;
    m_defaultPrinter = defaultPrinter;
    emit printersChanged();
}

QUrl Printing::setDocument(const QByteArray &pdf)
{
    if (!m_dir.isValid() || pdf.isEmpty())
        return {};
    const QString previous = m_current;
    const QString path = m_dir.filePath(QStringLiteral("pagina-%1.pdf").arg(++m_serial));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(pdf) != pdf.size())
        return {};
    file.close();
    m_current = path;
    // Mientras se imprime, el hilo aún lee el anterior
    if (!previous.isEmpty() && !m_busy)
        QFile::remove(previous);
    return QUrl::fromLocalFile(path);
}

QUrl Printing::saveFolder() const
{
    for (const auto location : { QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation }) {
        const QString dir = QStandardPaths::writableLocation(location);
        if (!dir.isEmpty() && QFileInfo(dir).isDir())
            return QUrl::fromLocalFile(dir);
    }
    return QUrl::fromLocalFile(QDir::homePath());
}

bool Printing::saveDocument(const QUrl &file)
{
    const QString target = file.toLocalFile();
    if (m_current.isEmpty() || target.isEmpty())
        return false;
    // QFile::copy no sobrescribe: el diálogo del sistema ya preguntó
    if (QFile::exists(target) && !QFile::remove(target))
        return false;
    return QFile::copy(m_current, target);
}

void Printing::print(const QString &printer, int copies, bool color, const QString &title)
{
    if (m_busy || m_current.isEmpty())
        return;
    m_busy = true;
    emit busyChanged();

    const QString path = m_current;
    auto error = std::make_shared<QString>();
    QThread *thread = QThread::create([path, printer, copies, color, title, error] {
        QPdfDocument document;
        document.load(path);
        if (document.status() != QPdfDocument::Status::Ready || document.pageCount() == 0) {
            *error = QStringLiteral("No se pudo preparar la página para imprimir.");
            return;
        }
        QPrinter device(QPrinter::HighResolution);
        device.setPrinterName(printer);
        if (!device.isValid()) {
            *error = QStringLiteral("La impresora «%1» no está disponible.").arg(printer);
            return;
        }
        device.setCopyCount(std::max(1, copies));
        device.setColorMode(color ? QPrinter::Color : QPrinter::GrayScale);
        device.setDocName(title);
        // Las páginas ya traen sus márgenes: el PDF ocupa la hoja entera
        device.setFullPage(true);
        const QSizeF firstPage = document.pagePointSize(0);
        device.setPageSize(QPageSize(firstPage, QPageSize::Point));
        device.setPageOrientation(firstPage.width() > firstPage.height() ? QPageLayout::Landscape
                                                                         : QPageLayout::Portrait);
        QPainter painter;
        if (!painter.begin(&device)) {
            *error = QStringLiteral("No se pudo empezar a imprimir en «%1».").arg(printer);
            return;
        }
        const int dpi = std::min(device.resolution(), MaxPrintDpi);
        for (int i = 0; i < document.pageCount(); ++i) {
            if (i > 0 && !device.newPage()) {
                *error = QStringLiteral("La impresión se interrumpió.");
                break;
            }
            const QSizeF points = document.pagePointSize(i);
            const QSize pixels = (points * dpi / 72.0).toSize();
            const QImage page = document.render(i, pixels);
            // La hoja entera, a la resolución de la impresora
            painter.drawImage(QRectF(QPointF(0, 0), device.pageLayout().fullRectPixels(device.resolution()).size()),
                              page);
        }
        painter.end();
    });
    // Con la conexión a `this`, si Printing desaparece antes (recarga de
    // --dev) no se avisa a nadie
    connect(thread, &QThread::finished, this, [this, error] {
        m_busy = false;
        emit busyChanged();
        emit printFinished(*error);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void Printing::clear()
{
    if (!m_current.isEmpty() && !m_busy)
        QFile::remove(m_current);
    if (!m_busy)
        m_current.clear();
}
