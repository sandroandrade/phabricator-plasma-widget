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

import QtQuick 2.8
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.1
import org.kde.plasma.components 2.0 as PlasmaComponents

Rectangle {
    id: rootItem
    color: "#323232"
    anchors { bottom: parent.bottom; bottomMargin: -2 }
    width: parent.width; height: rootItem.opacity == 1 ? 30 : 0

    OpacityAnimator {
        target: rootItem
        from: 0; to: 1; duration: 350; running: isOpened
    }

    OpacityAnimator {
        id: hideOpacityAnimator
        target: rootItem
        from: 1; to: 0; duration: 350; running: false
    }

    property bool isOpened: false

    signal opened()
    signal closed()
    signal restarted()

    function show(s) {
        message.text = s
        if (isOpened) {
            restarted();
            closed();
        } else {
            opened();
            hideTimer.start();
        }
    }

    onClosed: {
        isOpened = false
        hideOpacityAnimator.running = true
    }
    onOpened: isOpened = true
    onRestarted: reopenTimer.start();

    Timer {
        id: hideTimer
        repeat: false; interval: 3000
        onTriggered: {
            isOpened = false
            hideOpacityAnimator.running = true
        }
    }

    Timer {
        id: reopenTimer
        repeat: false; interval: 700
        onTriggered: {
            opened();
            hideTimer.start();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        width: parent.width; height: parent.height

        RowLayout {
            width: parent.width; height: parent.height
            anchors { left: parent.left; leftMargin: 15; right: parent.right; verticalCenter: parent.verticalCenter }

            Label {
                id: message
                color: "#fff"; opacity: 0.9
                width: parent.width * 0.70
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                onTextChanged: {
                    while (rootItem.height < message.text.contentHeight)
                        rootItem.height *= 1.2;
                }
            }

            Image {
                visible: rootItem.opacity == 1
                asynchronous: true; clip: true
                source: "../images/settings.svg"
                sourceSize { width: 20; height: 20 }
                anchors { right: parent.right; margins: 15; verticalCenter: parent.verticalCenter }

                NumberAnimation on rotation {
                    from: 0; to: 360; running: rootItem.visible
                    duration: 1100; loops: Animation.Infinite
                }
            }
        }
    }
}