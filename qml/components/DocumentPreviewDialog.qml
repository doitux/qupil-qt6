// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

// QUPIL_DOCUMENT_PREVIEW_PAPER_V1
Dialog {
    id: root
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    title: qsTr("Document Viewer - Qupil")
    standardButtons: Dialog.NoButton
    width: Math.max(360, Math.min(parent ? parent.width - 32 : 960, 960))
    height: Math.max(480, Math.min(parent ? parent.height - 32 : 760, 760))

    property string html: ""
    property string documentTitle: "Qupil"
    property string suggestedFileName: ""
    property bool landscape: false

    readonly property real pageAspect: landscape ? (297 / 210) : (210 / 297)

    function showDocument(documentHtml, titleText, fileNameSuggestion, landscapeMode) {
        html = documentHtml || ""
        documentTitle = titleText || "Qupil"
        suggestedFileName = fileNameSuggestion || ""
        landscape = !!landscapeMode
        open()
    }

    contentItem: ColumnLayout {
        spacing: 0

        ScrollView {
            id: previewScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            contentWidth: width
            contentHeight: paper.height + 32
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Item {
                width: previewScroll.width
                height: previewScroll.contentHeight

                Rectangle {
                    id: paper
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16

                    width: Math.max(300, previewScroll.width - 48)
                    height: Math.max(width / root.pageAspect,
                                     previewText.implicitHeight + 48)

                    color: "#ffffff"
                    border.color: "#b8b8b8"
                    border.width: 1

                    Text {
                        id: previewText
                        anchors.fill: parent
                        anchors.margins: 24

                        text: root.html
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap

                        color: "#202124"
                        linkColor: "#1a5fb4"
                    }
                }
            }
        }

        // QUPIL_DOCUMENT_PREVIEW_FOOTER_V2
        RowLayout {
            id: footerRow
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 10
            Layout.bottomMargin: 12
            spacing: 8

            DocumentActions {
                documentTitle: root.documentTitle
                suggestedFileName: root.suggestedFileName
                landscape: root.landscape
                createDocument: function() { return root.html }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Close")
                onClicked: root.close()
            }
        }
    }
}
