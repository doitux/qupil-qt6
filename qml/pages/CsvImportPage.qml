// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Page {
    id: root
    signal done()

    property url csvFile
    property var csvData: ({ headers: [], preview: [], rowCount: 0, delimiter: "," })

    property string summaryText: csvData.rowCount
                                 ? qsTr("%1 data rows · separator '%2'").arg(csvData.rowCount).arg(csvData.delimiter)
                                 : ""
    property var previewLines: {
        const result = []
        const rows = csvData.preview || []
        for (let i = 0; i < rows.length; ++i)
            result.push(rows[i].join("  |  "))
        return result
    }

    property var fields: [
        ["forename", qsTr("First name")], ["surname", qsTr("Last name")],
        ["birthday", qsTr("Birthday")], ["street", qsTr("Street")],
        ["zip", qsTr("Zip code")], ["city", qsTr("City")],
        ["phone", qsTr("Phone")], ["mobile", qsTr("Mobile")], ["email", qsTr("E-mail")]
    ]

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
            if (keys.some(k => h.indexOf(k) >= 0))
                return i
        }
        return -1
    }

    function loadPreview() {
        if (!csvFile || String(csvFile).length === 0)
            return
        csvData = App.previewPupilCsv(csvFile, form.encoding.currentText)
        Qt.callLater(function() {
            for (let i = 0; i < fields.length; ++i) {
                const row = form.mappingRepeater.itemAt(i)
                if (!row)
                    continue
                const idx = guessIndex(fields[i][0])
                row.selectorControl.currentIndex = idx >= 0 ? idx : csvData.headers.length
            }
        })
    }

    function importRows() {
        const map = {}
        for (let i = 0; i < fields.length; ++i) {
            const row = form.mappingRepeater.itemAt(i)
            const currentIndex = row ? row.selectorControl.currentIndex : csvData.headers.length
            map[fields[i][0]] = currentIndex < csvData.headers.length ? currentIndex : -1
        }
        const count = App.importPupilCsv(csvFile, form.encoding.currentText, map)
        if (count >= 0) {
            form.resultLabel.text = qsTr("%1 pupils imported").arg(count)
            form.resultPopup.open()
        }
    }

    Action { id: chooseFileAction; onTriggered: picker.open() }
    Action { id: backAction; onTriggered: root.done() }
    Action { id: importAction; onTriggered: root.importRows() }
    Action {
        id: doneAction
        onTriggered: {
            form.resultPopup.close()
            root.done()
        }
    }

    CsvImportPageForm {
        id: form
        anchors.fill: parent
        csvFileString: root.csvFile ? String(root.csvFile) : ""
        csvData: root.csvData
        fields: root.fields
        summaryText: root.summaryText
        previewLines: root.previewLines
        chooseFileAction: chooseFileAction
        backAction: backAction
        importAction: importAction
        doneAction: doneAction

        encoding.onActivated: root.loadPreview()
    }

    FileDialog {
        id: picker
        title: qsTr("Open address CSV")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("CSV files (*.csv)"), qsTr("All files (*)")]
        onAccepted: {
            root.csvFile = selectedFile
            root.loadPreview()
        }
    }
}
