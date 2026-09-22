// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property string csvFileString: ""
    property var csvData: ({ headers: [], preview: [], rowCount: 0, delimiter: "," })
    property var fields: []
    property string summaryText: ""
    property var previewLines: []
    property var chooseFileAction: null
    property var backAction: null
    property var importAction: null
    property var doneAction: null

    property alias encoding: encoding
    property alias mappingRepeater: mappingRepeater
    property alias resultPopup: resultPopup
    property alias resultLabel: resultLabel

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            SectionCard {
                title: qsTr("CSV address-book import")
                Layout.fillWidth: true
                Layout.margins: 12
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: qsTr("Choose CSV…"); action: root.chooseFileAction }
                    ComboBox {
                        id: encoding
                        model: ["UTF-8", "Latin-1"]
                    }
                    Label {
                        text: root.summaryText
                        Layout.fillWidth: true
                    }
                }
                Label {
                    text: root.csvFileString.length ? root.csvFileString : qsTr("No file selected")
                    opacity: 0.6
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                }
            }

            SectionCard {
                visible: root.csvData.headers && root.csvData.headers.length > 0
                title: qsTr("Field mapping")
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12

                Repeater {
                    id: mappingRepeater
                    model: root.fields
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        property alias selectorControl: selector
                        Layout.fillWidth: true
                        Label { text: modelData[1]; Layout.preferredWidth: 140 }
                        ComboBox {
                            id: selector
                            Layout.fillWidth: true
                            model: root.csvData.headers.concat([qsTr("Do not import")])
                        }
                    }
                }
            }

            SectionCard {
                visible: root.csvData.preview && root.csvData.preview.length > 0
                title: qsTr("Preview")
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Repeater {
                    model: root.previewLines
                    delegate: Label {
                        required property var modelData
                        text: modelData
                        font.family: "monospace"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.margins: 12
                Button { text: qsTr("Back"); action: root.backAction }
                Button { text: qsTr("Import"); enabled: root.csvData.rowCount > 0; action: root.importAction }
            }
        }
    }

    Popup {
        id: resultPopup
        anchors.centerIn: parent
        ColumnLayout {
            Label { id: resultLabel }
            Button { text: qsTr("Done"); action: root.doneAction }
        }
    }
}
