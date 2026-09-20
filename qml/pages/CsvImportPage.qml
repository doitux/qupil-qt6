// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Qupil

Page {
    id: root
    signal done()

    property url csvFile
    property var csvData: ({ headers: [], preview: [], rowCount: 0, delimiter: "," })
    property var fields: [
        ["forename", qsTr("First name")], ["surname", qsTr("Last name")],
        ["birthday", qsTr("Birthday")], ["street", qsTr("Street")],
        ["zip", qsTr("Zip code")], ["city", qsTr("City")],
        ["phone", qsTr("Phone")], ["mobile", qsTr("Mobile")], ["email", qsTr("E-mail")]
    ]
    property var selectors: []

    function guessIndex(fieldKey) {
        const aliases = {
            "forename": ["first", "forename", "vorname"],
            "surname": ["last", "surname", "nachname", "name"],
            "birthday": ["birth", "birthday", "geburt"],
            "street": ["street", "straße", "strasse"],
            "zip": ["zip", "postal", "plz"],
            "city": ["city", "ort", "stadt"],
            "phone": ["phone", "telefon", "tel"],
            "mobile": ["mobile", "handy", "mobil"],
            "email": ["mail", "email", "e-mail"]
        }
        const keys = aliases[fieldKey] || [fieldKey]
        for (let i = 0; i < csvData.headers.length; ++i) {
            const h = String(csvData.headers[i]).toLowerCase()
            if (keys.some(k => h.indexOf(k) >= 0)) return i
        }
        return -1
    }

    function loadPreview() {
        if (!csvFile || String(csvFile).length === 0) return
        csvData = App.previewPupilCsv(csvFile, encoding.currentText)
        Qt.callLater(function() {
            for (let i = 0; i < selectors.length; ++i) {
                const idx = guessIndex(fields[i][0])
                selectors[i].currentIndex = idx >= 0 ? idx : csvData.headers.length
            }
        })
    }

    function importRows() {
        const map = {}
        for (let i = 0; i < fields.length; ++i) {
            const cb = selectors[i]
            map[fields[i][0]] = cb.currentIndex < csvData.headers.length ? cb.currentIndex : -1
        }
        const count = App.importPupilCsv(csvFile, encoding.currentText, map)
        if (count >= 0) {
            resultLabel.text = qsTr("%1 pupils imported").arg(count)
            resultPopup.open()
        }
    }

    FileDialog {
        id: picker
        title: qsTr("Open address CSV")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("CSV files (*.csv)"), qsTr("All files (*)")]
        onAccepted: { root.csvFile = selectedFile; root.loadPreview() }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            SectionCard {
                title: qsTr("CSV address-book import")
                Layout.fillWidth: true; Layout.margins: 12
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: qsTr("Choose CSV…"); onClicked: picker.open() }
                    ComboBox {
                        id: encoding
                        model: ["UTF-8", "Latin-1"]
                        onActivated: root.loadPreview()
                    }
                    Label { text: root.csvData.rowCount ? qsTr("%1 data rows · separator '%2'").arg(root.csvData.rowCount).arg(root.csvData.delimiter) : ""; Layout.fillWidth: true }
                }
                Label { text: root.csvFile ? String(root.csvFile) : qsTr("No file selected"); opacity: 0.6; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
            }

            SectionCard {
                visible: root.csvData.headers && root.csvData.headers.length > 0
                title: qsTr("Field mapping")
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12

                Repeater {
                    model: root.fields
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Label { text: modelData[1]; Layout.preferredWidth: 140 }
                        ComboBox {
                            id: selector
                            Layout.fillWidth: true
                            model: root.csvData.headers.concat([qsTr("Do not import")])
                            Component.onCompleted: root.selectors[index] = selector
                        }
                    }
                }
            }

            SectionCard {
                visible: root.csvData.preview && root.csvData.preview.length > 0
                title: qsTr("Preview")
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                Repeater {
                    model: root.csvData.preview
                    delegate: Label {
                        required property var modelData
                        text: modelData.join("  |  ")
                        font.family: "monospace"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.margins: 12
                Button { text: qsTr("Back"); onClicked: root.done() }
                Button { text: qsTr("Import"); enabled: root.csvData.rowCount > 0; onClicked: root.importRows() }
            }
        }
    }

    Popup {
        id: resultPopup
        anchors.centerIn: parent
        ColumnLayout {
            Label { id: resultLabel }
            Button { text: qsTr("Done"); onClicked: { resultPopup.close(); root.done() } }
        }
    }
}
