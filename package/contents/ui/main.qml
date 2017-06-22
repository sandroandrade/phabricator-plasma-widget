/***************************************************************************
 *   Copyright (C) 2017 by Enoque Joseneas <enoquejoseneas@gmail.com>      *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.1
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.1
import Qt.labs.settings 1.0
import QtQuick.Controls 2.1
import QtGraphicalEffects 1.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

Item {
    id: rootItem
    width: 450; height: 350
    implicitWidth: width; implicitHeight: height
    Layout.minimumWidth: width; Layout.minimumHeight: height

    // to request tasks assigned to user, we needs the user id
    // this function load the user id using the user email, phabricator token and phabricator url
    function loadUserId() {
        jsonModel.requestParams = "api.token=%1&emails[0]=%2".arg(settings.token).arg(settings.useremail);
        jsonModel.source += "/api/user.query";
        messageBar.show(qsTr("Loading your phabricator id..."));
        jsonModel.load(function(response) {
            if (response && jsonModel.httpStatus == 200) {
                settings.userPhabricatorId = response.result[0].phid
                messageBar.show(qsTr("Your id was success loaded!"))
                maniphestPage.maniphestPageRequest()
            }
        });
    }

    MessageDialog {
        id: dialog
        title: qsTr("Warning!")

        function show(message, dtitle) {
            if (dtitle)
                dialog.title = dtitle;
            dialog.text = message;
            dialog.open();
        }
    }

    // show phabricator logo in widget background
    Image {
        id: notificationIcon
        source: "../images/Phabricator.png"
        asynchronous: true; anchors.fill: parent; opacity: 0.1
    }

    // show system notification
    Notification {
        id: systemTrayNotification
    }

    // timer to reload tasks
    Timer {
        interval: 300000; running: true; repeat: true
        onTriggered: maniphestPage.maniphestPageRequest()
    }

    // the storage of widget data (token, user id and phabricator url)
    Settings {
        id: settings
        objectName: "Phabricator Widget"
        property string token
        property string phabricatorUrl
        property string useremail
        property string userPhabricatorId

        Component.onCompleted: {
            Plasmoid.fullRepresentation = column;
            if (settings.token && settings.userPhabricatorId)
                maniphestPage.maniphestPageRequest();
        }
    }

    // the request http object
    JSONListModel {
        id: jsonModel
        source: settings.phabricatorUrl
        requestMethod: "POST"
        // reset url after each request response
        onStateChanged: if (state === "ready" || state === "error") jsonModel.source = settings.phabricatorUrl
    }

    // show in widget bottom dynamically messages
    MessageBar {
        id: messageBar
        z: tabGroup.z + 10
    }

    Column {
        id: column
        spacing: 2; width: parent.width; anchors.fill: parent

        PlasmaComponents.TabBar {
            id: tabBar
            z: parent.z + 100; clip: true; width: parent.width

            PlasmaComponents.TabButton {
                tab: maniphestPage
                text: qsTr("Maniphest")
                clip: true
            }

            PlasmaComponents.TabButton {
                tab: settingsPage
                text: qsTr("Settings")
                clip: true
            }
        }

        PlasmaComponents.TabGroup {
            id: tabGroup
            clip: true
            width: parent.width; height: parent.height - tabBar.height

            PlasmaComponents.Page {
                id: maniphestPage
                clip: true; anchors.fill: parent

                function getPriorityTaskColor(priority) {
                    if (priority === "Unbreak Now!")
                        return "#da49be";
                    else if (priority === "Needs Triage")
                        return "#8e44ad";
                    else if (priority === "Hight")
                        return "#c0392b";
                    else if (priority === "Normal")
                        return "#e67e22";
                    else if (priority === "Low")
                        return "#f1c40f";
                    return "#3498db";
                }

                function maniphestPageRequest() {
                    jsonModel.requestParams = "api.token=%1&constraints[assigned][0]=%2".arg(settings.token).arg(settings.userPhabricatorId)
                    jsonModel.source += "/api/maniphest.search"
                    messageBar.show(qsTr("Loading maniphest opened tasks..."))
                    jsonModel.load(function(response) {
                        if (jsonModel.httpStatus == 200 && response.result) {
                            if (maniphestView.count > 0 && maniphestView.count !== response.result.data.length) {
                                var fixBind = [];
                                maniphestView.model = fixBind;
                                systemTrayNotification.showMessage(qsTr("Phabricator Widget"), qsTr("New task(s) for you! Take a look in Phabricator widget!"))
                            }
                            maniphestView.model = response.result.data
                        }
                    });
                }

                Rectangle {
                    id: preview
                    clip: true; anchors.fill: parent
                    color: "transparent"; visible: false

                    property int requestId: 0
                    property var previewObject: {
                        "fields": {"name": ""},
                        "description": {"raw": ""}
                    }

                    onRequestIdChanged: {
                        messageBar.show(qsTr("Loading details for task %1".arg(requestId)))
                        jsonModel.source += "/api/maniphest.search"
                        jsonModel.requestParams = "api.token=%1&constraints[ids][0]=%2".arg(settings.token).arg(requestId)
                        jsonModel.load(function(response) {
                            if (jsonModel.httpStatus == 200 && response.result && response.result.data.length) {
                                preview.previewObject = response.result.data[0]
                                preview.visible = true
                            }
                        })
                    }

                    Image {
                        width: 24; height: width
                        asynchronous: true; clip: true
                        source: "../images/arrow_back.svg"
                        anchors { left: parent.left; leftMargin: 5; top: parent.top; topMargin: 5 }

                        MouseArea {
                            onClicked: preview.visible = false
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: cursorShape = Qt.PointingHandCursor
                        }

                        ColorOverlay {
                            source: parent
                            color: "#fff"
                            cached: true
                            anchors.fill: parent
                        }
                    }

                    Column {
                        clip: true
                        spacing: 20
                        width: parent.width * 0.90
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 30 }

                        PlasmaComponents.Label {
                            width: parent.width
                            elide: Text.ElideRight
                            text: preview.previewObject.fields.name
                        }

                        PlasmaComponents.Label {
                            width: parent.width
                            elide: Text.ElideRight
                            text: typeof preview.previewObject.description != "undefined" ? preview.previewObject.description.raw : ""
                        }
                    }
                }

                ListView {
                    id: maniphestView
                    anchors.fill: parent
                    visible: !preview.visible
                    clip: true; spacing: 0
                    ScrollIndicator.vertical: ScrollIndicator { }
                    delegate: Rectangle {
                        clip: true; color: "transparent"
                        width: parent.width; height: 50

                        RowLayout {
                            anchors { fill: parent; verticalCenter: parent.verticalCenter }

                            // show phabricator priority task color
                            Rectangle {
                                width: 4; height: parent.height-5
                                color: maniphestPage.getPriorityTaskColor(modelData.fields.priority.name);
                                anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
                            }

                            // show the task title
                            Rectangle  {
                                color: "transparent"
                                width: parent.width * 0.80; height: parent.height

                                PlasmaComponents.Label {
                                    id: taskTitle
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: modelData.fields.name
                                    anchors {
                                        left: parent.left
                                        leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // show the task priority name
                            PlasmaComponents.Label {
                                color: taskTitle.color
                                text: modelData.fields.priority.name
                                height: parent.height
                                font.pointSize: 7; opacity: 0.7
                                anchors { right: parent.right; rightMargin: 5; top: parent.top; topMargin: 3 }
                            }

                            // show the task created datetime
                            PlasmaComponents.Label {
                                color: taskTitle.color
                                text: Qt.formatDateTime(new Date(modelData.fields.dateCreated*1000))
                                font.pointSize: 7; opacity: 0.7
                                anchors { right: parent.right; rightMargin: 5; bottom: parent.bottom; bottomMargin: 3 }
                            }
                        }

                        // add a click support to open task details in previous tab
                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            onExited: parent.opacity = 1.0
                            onClicked: preview.requestId = modelData.id;
                            onEntered: {
                                parent.opacity = 0.8
                                cursorShape = Qt.PointingHandCursor
                            }
                        }

                        // Add a divider line to list items
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: taskTitle.color; opacity: 0.2 }
                    }
                }
            }

            PlasmaComponents.Page {
                id: settingsPage
                clip: true; anchors.fill: parent

                Flickable {
                    anchors.fill: parent; height: rootItem.height
                    contentHeight: formColumn.contentHeight
                    ScrollBar.vertical: ScrollBar { }

                    ColumnLayout {
                        id: formColumn
                        spacing: 10; anchors.fill: parent

                        PlasmaComponents.Label {
                            text: qsTr("Enter you phabricator email:")
                            anchors {left: parent.left; leftMargin: 15; bottom: useremailField.top; bottomMargin: 5 }
                        }

                        PlasmaComponents.TextField {
                            id: useremailField
                            text: settings.useremail
                            anchors { left: parent.left; right: parent.right; margins: 15 }
                        }

                        PlasmaComponents.Label {
                            text: qsTr("Enter the phabricator conduit token:")
                            anchors {left: parent.left; leftMargin: 15; bottom: tokenField.top; bottomMargin: 5 }
                        }

                        PlasmaComponents.TextField {
                            id: tokenField
                            text: settings.token
                            anchors { left: parent.left; right: parent.right; margins: 15 }
                        }

                        PlasmaComponents.Label {
                            text: qsTr("Enter the phabricator url:")
                            anchors {left: parent.left; leftMargin: 15; bottom: phabricatorUrlField.top; bottomMargin: 5 }
                        }

                        PlasmaComponents.TextField {
                            id: phabricatorUrlField
                            text: settings.phabricatorUrl
                            anchors { left: parent.left; right: parent.right; margins: 15 }
                        }

                        PlasmaComponents.Label {
                            id: phabricatorUserId
                            visible: settings.userPhabricatorId.length > 0
                            text: qsTr("Your phabricator ID is ") + settings.userPhabricatorId
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        PlasmaComponents.Button {
                            id: button
                            text: qsTr("Submit")
                            anchors.horizontalCenter: parent.horizontalCenter
                            onClicked: {
                                if (useremailField.text && tokenField.text && phabricatorUrlField.text) {
                                    settings.token = tokenField.text;
                                    settings.useremail = useremailField.text;
                                    settings.phabricatorUrl = phabricatorUrlField.text;
                                    loadUserId();
                                } else {
                                    dialog.show(qsTr("All fields needs to be set!"));
                                }
                            }
                        }

                        Item { width: parent.width; height: 25 }
                    }
                }
            }
        }
    }
}
