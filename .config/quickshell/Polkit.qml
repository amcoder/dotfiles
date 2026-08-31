import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Services.Polkit

Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: root.flow !== null && !root.flow.isCompleted
    readonly property bool awaitingResponse: root.flow !== null && root.flow.isResponseRequired

    // Held until the next submission: polkit re-prompts straight after a failed
    // attempt, which would otherwise wipe the message before it could be read.
    property string statusText: ""
    property bool statusIsError: false

    readonly property var focusedScreen: {
        const workspace = I3.workspaces.values.find(ws => ws.focused);
        const name = workspace && workspace.monitor ? workspace.monitor.name : "";

        for (const screen of Quickshell.screens) {
            if (screen.name === name)
                return screen;
        }

        return null;
    }

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

    PanelWindow {
        id: window

        readonly property int padding: 20

        visible: root.active
        screen: root.focusedScreen
        color: Theme.overlayScrim

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-polkit"

        onVisibleChanged: {
            if (window.visible)
                input.forceActiveFocus();
        }

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: dialog

            anchors.centerIn: parent
            width: 620
            implicitHeight: body.implicitHeight + window.padding * 2
            color: Theme.popupBackground
            border.color: Theme.popupBorder
            border.width: 1
            radius: 6

            Keys.onEscapePressed: root.cancel()

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.padding
                spacing: 12

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock-key"
                        color: Theme.yellow
                        size: Theme.headingFontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Authentication required"
                        color: Theme.popupText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                        font.bold: true
                    }
                }

                Text {
                    width: parent.width
                    visible: root.flow !== null && root.flow.message !== ""
                    text: root.flow !== null ? root.flow.message : ""
                    color: Theme.popupText
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    width: parent.width
                    visible: root.flow !== null && root.flow.actionId !== ""
                    text: root.flow !== null ? root.flow.actionId : ""
                    color: Theme.popupSubtext
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
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
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
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
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 4
                        color: Theme.base
                        border.color: input.activeFocus ? Theme.blue : Theme.surface1
                        border.width: 1

                        TextInput {
                            id: input

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            focus: true
                            activeFocusOnTab: true
                            enabled: root.awaitingResponse
                            echoMode: root.flow !== null && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                            color: Theme.popupText
                            selectionColor: Theme.popupSelection
                            selectedTextColor: Theme.popupText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            onAccepted: root.submit()
                            onEnabledChanged: {
                                if (input.enabled)
                                    input.forceActiveFocus();
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.statusText !== ""
                    text: root.statusText
                    color: root.statusIsError ? Theme.red : Theme.popupSubtext
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    anchors.right: parent.right
                    spacing: 10

                    Rectangle {
                        id: cancelButton

                        implicitWidth: cancelLabel.implicitWidth + 28
                        height: 38
                        radius: 4
                        activeFocusOnTab: true
                        color: cancelMouse.containsMouse ? Theme.surface2 : Theme.surface1
                        border.color: Theme.text
                        border.width: cancelButton.activeFocus ? 2 : 0

                        Keys.onSpacePressed: root.cancel()
                        Keys.onReturnPressed: root.cancel()
                        Keys.onEnterPressed: root.cancel()

                        Text {
                            id: cancelLabel

                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.popupText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            id: cancelMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.cancel()
                        }
                    }

                    Rectangle {
                        id: authenticateButton

                        implicitWidth: authenticateLabel.implicitWidth + 28
                        height: 38
                        radius: 4
                        activeFocusOnTab: true
                        opacity: root.awaitingResponse ? 1 : 0.5
                        color: authenticateMouse.containsMouse ? Theme.sapphire : Theme.blue
                        border.color: Theme.text
                        border.width: authenticateButton.activeFocus ? 2 : 0

                        Keys.onSpacePressed: root.submit()
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()

                        Text {
                            id: authenticateLabel

                            anchors.centerIn: parent
                            text: "Authenticate"
                            color: Theme.base
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            id: authenticateMouse

                            anchors.fill: parent
                            enabled: root.awaitingResponse
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.submit()
                        }
                    }
                }
            }
        }
    }
}
