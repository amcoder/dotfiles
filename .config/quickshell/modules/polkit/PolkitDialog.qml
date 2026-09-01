import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.config
import qs.widgets
import qs.windows

Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: root.flow !== null && !root.flow.isCompleted
    readonly property bool awaitingResponse: root.flow !== null && root.flow.isResponseRequired

    // Held until the next submission: polkit re-prompts straight after a failed
    // attempt, which would otherwise wipe the message before it could be read.
    property string statusText: ""
    property bool statusIsError: false

    function submit() {
        if (!root.awaitingResponse)
            return;

        root.flow.submit(input.text);
        input.text = "";
        root.statusText = "Authenticating…";
        root.statusIsError = false;
    }

    function cancel() {
        if (root.flow !== null)
            root.flow.cancelAuthenticationRequest();
    }

    onFlowChanged: {
        input.text = "";
        root.statusText = "";
        root.statusIsError = false;
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: root.flow

        // Quickshell does not forward PAM's own failure text, so a rejected
        // password only ever surfaces through this signal.
        function onAuthenticationFailed() {
            root.statusText = "Authentication failed";
            root.statusIsError = true;
        }

        function onSupplementaryMessageChanged() {
            if (root.flow.supplementaryMessage === "")
                return;

            root.statusText = root.flow.supplementaryMessage;
            root.statusIsError = root.flow.supplementaryIsError;
        }
    }

    ModalOverlay {
        namespaceSuffix: "polkit"

        visible: root.active
        cardWidth: 620
        padding: 20
        focusItem: input

        onDismissed: root.cancel()

        Row {
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "lock-key"
                color: Theme.yellow
                size: Appearance.headingFontSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication required"
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
                font.bold: true
            }
        }

        Text {
            width: parent.width
            visible: root.flow !== null && root.flow.message !== ""
            text: root.flow !== null ? root.flow.message : ""
            color: Theme.popupText
            wrapMode: Text.WordWrap
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Text {
            width: parent.width
            visible: root.flow !== null && root.flow.actionId !== ""
            text: root.flow !== null ? root.flow.actionId : ""
            color: Theme.popupSubtext
            elide: Text.ElideMiddle
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Flow {
            width: parent.width
            visible: root.flow !== null && root.flow.identities.length > 1
            spacing: 6

            Repeater {
                model: root.flow !== null ? root.flow.identities : []

                Rectangle {
                    id: identity

                    required property var modelData

                    readonly property bool current: root.flow !== null && root.flow.selectedIdentity === identity.modelData

                    implicitWidth: identityLabel.implicitWidth + 24
                    height: 34
                    radius: 4
                    activeFocusOnTab: true
                    color: {
                        if (identity.current)
                            return Theme.popupSelection;
                        if (identityMouse.containsMouse)
                            return Theme.popupHover;
                        return "transparent";
                    }
                    border.color: {
                        if (identity.activeFocus)
                            return Theme.text;
                        if (identity.current)
                            return Theme.blue;
                        return Theme.surface1;
                    }
                    border.width: identity.activeFocus ? 2 : 1

                    Keys.onSpacePressed: root.flow.selectedIdentity = identity.modelData
                    Keys.onReturnPressed: root.flow.selectedIdentity = identity.modelData
                    Keys.onEnterPressed: root.flow.selectedIdentity = identity.modelData

                    Text {
                        id: identityLabel

                        anchors.centerIn: parent
                        text: identity.modelData.displayName
                        color: Theme.popupText
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }

                    MouseArea {
                        id: identityMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.flow.selectedIdentity = identity.modelData
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6

            Text {
                text: {
                    if (root.flow === null)
                        return "";
                    if (root.flow.inputPrompt !== "")
                        return root.flow.inputPrompt;
                    return "Password:";
                }
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }

            TextField {
                id: input

                width: parent.width
                enabled: root.awaitingResponse
                echoMode: root.flow !== null && root.flow.responseVisible ? TextInput.Normal : TextInput.Password

                onAccepted: root.submit()
            }
        }

        Text {
            width: parent.width
            visible: root.statusText !== ""
            text: root.statusText
            color: root.statusIsError ? Theme.red : Theme.popupSubtext
            wrapMode: Text.WordWrap
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            Button {
                text: "Cancel"

                onActivated: root.cancel()
            }

            Button {
                text: "Authenticate"

                enabled: root.awaitingResponse
                background: Theme.blue
                hoverBackground: Theme.sapphire
                foreground: Theme.base

                onActivated: root.submit()
            }
        }
    }
}
