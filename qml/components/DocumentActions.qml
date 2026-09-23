// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qupil

RowLayout {
    id: root
    spacing: 8

    property string documentTitle: "Qupil"
    property string suggestedFileName: ""
    property bool landscape: false
    property var createDocument: function() { return "" }
    property string pendingHtml: ""
    property var printerNames: []
    property url pdfFolder: App.suggestedPdfUrl("")
    property string pendingPdfHtml: ""
    property string pendingPdfTitle: ""
    property bool pendingPdfLandscape: false
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"

    function buildDocument() {
        if (!createDocument)
            return ""
        return createDocument() || ""
    }

    function startPdf() {
        const html = buildDocument()
        if (!html.length)
            return
        if (mobilePlatform) {
            const mobileFileName = suggestedFileName.length > 0 ? suggestedFileName : ("Qupil_" + documentTitle)
            App.shareDocumentPdf(html, mobileFileName, documentTitle, landscape)
        } else {
            // QUPIL_NATIVE_SAVE_DIALOG_V1
            if (saveDialog.visible)
                return

            // Keep an immutable snapshot until the asynchronous dialog returns.
            pendingPdfHtml = html
            pendingPdfTitle = documentTitle
            pendingPdfLandscape = landscape
            const baseName = suggestedFileName.length > 0
                             ? suggestedFileName
                             : ("Qupil_" + documentTitle)

            if (!pdfFolder.toString().length)
                pdfFolder = App.suggestedPdfUrl("")
            saveDialog.currentFolder = pdfFolder
            // SaveFile accepts a filename that does not exist yet.
            // Qt's portal helper forwards its basename as current_name.
            saveDialog.selectedFile = App.pdfUrlInFolder(pdfFolder, baseName)
            saveDialog.open()
        }
    }

    function startPrint() {
        pendingHtml = buildDocument()
        if (!pendingHtml.length)
            return
        printerNames = App.availablePrinters()
        if (!printerNames || printerNames.length === 0)
            return
        const preferred = App.defaultPrinterName()
        const preferredIndex = printerNames.indexOf(preferred)
        printerBox.currentIndex = preferredIndex >= 0 ? preferredIndex : 0
        printDialog.open()
    }

    Button {
        visible: !root.mobilePlatform
        text: qsTr("Print")
        enabled: root.printerNames.length > 0 || App.availablePrinters().length > 0
        onClicked: root.startPrint()
    }

    Button {
        text: root.mobilePlatform ? qsTr("Share PDF") : qsTr("Export to PDF")
        onClicked: root.startPdf()
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Export File")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "pdf"
        nameFilters: [qsTr("PDF File (*.pdf)")]
        // Standardoptionen beibehalten:
        // Der native Plattformdialog bleibt erlaubt und die
        // Ueberschreibbestaetigung bleibt aktiv.

        onAccepted: {
            const destination = selectedFile
            if (!destination.toString().length)
                return

            // Only an accepted dialog may trigger an actual PDF write.
            if (App.exportDocumentPdf(root.pendingPdfHtml, destination,
                                      root.pendingPdfTitle, root.pendingPdfLandscape))
                root.pdfFolder = currentFolder
            root.pendingPdfHtml = ""
        }
        onRejected: root.pendingPdfHtml = ""
    }

    Dialog {
        id: printDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        title: qsTr("Print")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: App.printDocument(root.pendingHtml, printerBox.currentText,
                                      root.documentTitle, root.landscape)

        ColumnLayout {
            width: 320
            Label { text: qsTr("Printer"); font.bold: true }
            ComboBox {
                id: printerBox
                Layout.fillWidth: true
                model: root.printerNames
            }
        }
    }
}
