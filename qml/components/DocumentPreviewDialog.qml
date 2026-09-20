// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Dialog {
    id: root
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    title: qsTr("Document Viewer - Qupil")
    standardButtons: Dialog.Close
    width: Math.max(320, Math.min(parent ? parent.width - 32 : 900, 900))
    height: Math.max(420, Math.min(parent ? parent.height - 32 : 700, 700))

    property string html: ""
    property string documentTitle: "Qupil"
    property string suggestedFileName: ""
    property bool landscape: false

    function showDocument(documentHtml, titleText, fileNameSuggestion, landscapeMode) {
        html = documentHtml || ""
        documentTitle = titleText || "Qupil"
        suggestedFileName = fileNameSuggestion || ""
        landscape = !!landscapeMode
        open()
    }

    contentItem: ColumnLayout {
        spacing: 8
        ScrollView {
            id: previewScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            Label {
                width: Math.max(0, previewScroll.availableWidth - 16)
                x: 8
                text: root.html
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: root.palette.text
            }
        }
        DocumentActions {
            Layout.fillWidth: true
            documentTitle: root.documentTitle
            suggestedFileName: root.suggestedFileName
            landscape: root.landscape
            createDocument: function() { return root.html }
        }
    }
}
