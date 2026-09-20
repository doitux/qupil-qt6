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
            pendingHtml = html
            if (suggestedFileName.length > 0) {
                saveDialog.currentFile = App.suggestedPdfUrl(suggestedFileName)
            } else {
                saveDialog.currentFile = ""
                saveDialog.currentFolder = App.suggestedPdfUrl("")
            }
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
        nameFilters: [qsTr("PDF File (*.pdf)")]
        onAccepted: App.exportDocumentPdf(root.pendingHtml, selectedFile,
                                          root.documentTitle, root.landscape)
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
