import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import chatlistmodel
import llm
import download
import network
import mysettings

Rectangle {
    id: chatDrawer

    Theme {
        id: theme
    }

    color: theme.viewBackground

    // FIXME_BLOCKER We need to organize these by date created and show in the UI

    Rectangle {
        id: borderRight
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 2
        color: theme.dividerColor
    }

    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: borderRight.left

        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("Drawer")
        Accessible.description: qsTr("Main navigation drawer")

        MySettingsButton {
            id: newChat
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            font.pixelSize: theme.fontSizeLarger
            topPadding: 20
            bottomPadding: 20
            text: qsTr("\uFF0B New chat")
            Accessible.description: qsTr("Create a new chat")
            onClicked: {
                ChatListModel.addChat()
                conversationList.positionViewAtIndex(0, ListView.Beginning)
                Network.trackEvent("new_chat", {"number_of_chats": ChatListModel.count})
            }
        }

        Rectangle {
            id: divider
            anchors.top: newChat.bottom
            anchors.margins: 20
            anchors.topMargin: 15
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: theme.dividerColor
        }

        ScrollView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 15
            anchors.top: divider.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 15
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            clip: true

            ListView {
                id: conversationList
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                model: ChatListModel

                Component.onCompleted: ChatListModel.loadChats()

                ScrollBar.vertical: ScrollBar {
                    parent: conversationList.parent
                    anchors.top: conversationList.top
                    anchors.left: conversationList.right
                    anchors.bottom: conversationList.bottom
                }

                Component {
                    id: sectionHeading
                    Rectangle {
                        width: ListView.view.width
                        height: childrenRect.height
                        color: "transparent"
                        property bool isServer: ChatListModel.get(parent.index) && ChatListModel.get(parent.index).isServer
                        visible: !isServer || MySettings.serverChat

                        required property string section

                        Text {
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 15
                            bottomPadding: 5
                            text: parent.section
                            color: theme.grayRed900
                            font.pixelSize: theme.fontSizeLarge
                        }
                    }
                }

                section.property: "section"
                section.criteria: ViewSection.FullString
                section.delegate: sectionHeading

                delegate: Rectangle {
                    id: chatRectangle
                    width: conversationList.width
                    height: chatName.height
                    property bool isCurrent: ChatListModel.currentChat === ChatListModel.get(index)
                    property bool isServer: ChatListModel.get(index) && ChatListModel.get(index).isServer
                    property bool trashQuestionDisplayed: false
                    visible: !isServer || MySettings.serverChat
                    z: isCurrent ? 199 : 1
                    color: isCurrent ? theme.white : "transparent"
                    border.width: isCurrent
                    border.color: theme.dividerColor
                    radius: 10

                    TextField {
                        id: chatName
                        anchors.left: parent.left
                        anchors.right: buttons.left
                        color: theme.grayRed900
                        topPadding: 15
                        bottomPadding: 15
                        focus: false
                        readOnly: true
                        wrapMode: Text.NoWrap
                        hoverEnabled: false // Disable hover events on the TextArea
                        selectByMouse: false // Disable text selection in the TextArea
                        font.pixelSize: theme.fontSizeLarge
                        font.bold: true
                        text: readOnly ? metrics.elidedText : name
                        horizontalAlignment: TextInput.AlignLeft
                        opacity: trashQuestionDisplayed ? 0.5 : 1.0
                        TextMetrics {
                            id: metrics
                            font: chatName.font
                            text: name
                            elide: Text.ElideRight
                            elideWidth: chatName.width - 15
                        }
                        background: Rectangle {
                            color: "transparent"
                        }
                        onEditingFinished: {
                            // Work around a bug in qml where we're losing focus when the whole window
                            // goes out of focus even though this textfield should be marked as not
                            // having focus
                            if (chatName.readOnly)
                                return;
                            Network.trackChatEvent("rename_chat")
                            changeName();
                        }
                        function changeName() {
                            ChatListModel.get(index).name = chatName.text
                            chatName.focus = false
                            chatName.readOnly = true
                            chatName.selectByMouse = false
                        }
                        TapHandler {
                            onTapped: {
                                if (isCurrent)
                                    return;
                                ChatListModel.currentChat = ChatListModel.get(index);
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: text
                        Accessible.description: qsTr("Select the current chat or edit the chat when in edit mode")
                    }
                    Row {
                        id: buttons
                        anchors.verticalCenter: chatName.verticalCenter
                        anchors.right: chatRectangle.right
                        anchors.rightMargin: 10
                        spacing: 10
                        MyToolButton {
                            id: editButton
                            width: 30
                            height: 30
                            visible: isCurrent && !isServer
                            opacity: trashQuestionDisplayed ? 0.5 : 1.0
                            source: "qrc:/gpt4all/icons/edit.svg"
                            onClicked: {
                                chatName.focus = true
                                chatName.readOnly = false
                                chatName.selectByMouse = true
                            }
                            Accessible.name: qsTr("Edit chat name")
                        }
                        MyToolButton {
                            id: trashButton
                            width: 30
                            height: 30
                            visible: isCurrent && !isServer
                            source: "qrc:/gpt4all/icons/trash.svg"
                            onClicked: {
                                trashQuestionDisplayed = true
                                timer.start()
                            }
                            Accessible.name: qsTr("Delete chat")
                        }
                    }
                    Rectangle {
                        id: trashSureQuestion
                        anchors.top: buttons.bottom
                        anchors.topMargin: 10
                        anchors.right: buttons.right
                        width: childrenRect.width
                        height: childrenRect.height
                        color: chatRectangle.color
                        visible: isCurrent && trashQuestionDisplayed
                        opacity: 1.0
                        radius: 10
                        z: 200
                        Row {
                            spacing: 10
                            Button {
                                id: checkMark
                                width: 30
                                height: 30
                                contentItem: Text {
                                    color: theme.textErrorColor
                                    text: "\u2713"
                                    font.pixelSize: theme.fontSizeLarger
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    width: 30
                                    height: 30
                                    color: "transparent"
                                }
                                onClicked: {
                                    Network.trackChatEvent("remove_chat")
                                    ChatListModel.removeChat(ChatListModel.get(index))
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Confirm chat deletion")
                            }
                            Button {
                                id: cancel
                                width: 30
                                height: 30
                                contentItem: Text {
                                    color: theme.textColor
                                    text: "\u2715"
                                    font.pixelSize: theme.fontSizeLarger
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    width: 30
                                    height: 30
                                    color: "transparent"
                                }
                                onClicked: {
                                    trashQuestionDisplayed = false
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Cancel chat deletion")
                            }
                        }
                    }
                    Timer {
                        id: timer
                        interval: 3000; running: false; repeat: false
                        onTriggered: trashQuestionDisplayed = false
                    }
                }

                Accessible.role: Accessible.List
                Accessible.name: qsTr("List of chats")
                Accessible.description: qsTr("List of chats in the drawer dialog")
            }
        }
    }
}
