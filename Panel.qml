import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.rizmi.v2raya-vpn"
  ipcTarget: "io.github.rizmi.v2raya-vpn"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: v2raya.unavailable ? urgent : (v2raya.active ? foreground : dim)
  readonly property color barIconColor: v2raya.unavailable ? Qt.darker(barForeground, 1.2) : (v2raya.active ? barForeground : Qt.darker(barForeground, 1.55))
  readonly property string toggleHint: v2raya.active ? "Disconnect" : "Connect"
  property bool authExpanded: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: v2raya
    settings: root.settings
  }

  onOpenedChanged: {
    if (opened) {
      v2raya.refresh()
      root.authExpanded = false
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { v2raya.refresh(); return "ok" }
    function status(): string { return v2raya.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖂"
    foreground: root.barIconColor
    tooltipText: "v2rayA VPN — " + v2raya.statusText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) v2raya.refresh()
      else if (buttonCode === Qt.MiddleButton) v2raya.toggle()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: nodePicker.popupOpen || userInput.activeFocus || passInput.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") v2raya.refresh()
        else if (t === "c" || t === "C") v2raya.toggle()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "v2rayA VPN"
          meta: v2raya.statusText
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: v2raya.unavailable ? 0.5 : (v2raya.active ? 1.0 : 0.6)
          iconComponent: Component {
            Text {
              text: "󰖂"
              color: root.iconColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: powerSwitch
              checked: v2raya.active
              busy: v2raya.busy || v2raya.unavailable
              interactive: !v2raya.busy && !v2raya.unavailable
              foreground: hero.foreground
              onToggled: v2raya.toggle()

              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: root.toggleHint
                fontFamily: hero.fontFamily
              }
            }
          }
        }

        Text {
          visible: v2raya.actionStatus !== "" || v2raya.lastError !== ""
          width: parent.width
          text: v2raya.actionStatus !== "" ? v2raya.actionStatus : v2raya.lastError
          color: v2raya.lastError !== "" && v2raya.actionStatus === "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "SERVER NODE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          SearchableDropdown {
            id: nodePicker
            width: parent.width
            showLabel: false
            placeholderText: "Search servers / nodes..."
            fontFamily: root.fontFamily
            options: v2raya.nodes
            value: v2raya.currentNode
            onChanged: function(v) { v2raya.setNode(v) }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // Settings button row
        Rectangle {
          width: parent.width
          height: Style.space(32)
          color: settingsBtnArea.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
          radius: Style.space(6)

RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(4)
              anchors.rightMargin: Style.space(4)
              spacing: Style.space(8)

              Text {
                text: "⚙"
                color: root.dim
                font.pixelSize: Style.font.body
                Layout.alignment: Qt.AlignVCenter
              }

              Text {
                text: "Authentication"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.alignment: Qt.AlignVCenter
              }

              Item { Layout.fillWidth: true }

              Text {
                text: root.authExpanded ? "▲" : "▼"
                color: root.dim
                font.pixelSize: Style.font.bodySmall
                Layout.alignment: Qt.AlignVCenter
              }
            }

          MouseArea {
            id: settingsBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.authExpanded = !root.authExpanded
          }
        }

        // Collapsible auth fields
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.authExpanded
          clip: true

          Rectangle {
            width: parent.width
            height: Style.space(36)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            radius: Style.space(6)
            border.color: userInput.activeFocus ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
            border.width: 1

            TextInput {
              id: userInput
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              verticalAlignment: Text.AlignVCenter
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              selectByMouse: true

              Text {
                text: "Username"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                visible: userInput.text === "" && !userInput.activeFocus
                anchors.verticalCenter: parent.verticalCenter
              }

              onAccepted: passInput.forceActiveFocus()
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(36)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            radius: Style.space(6)
            border.color: passInput.activeFocus ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
            border.width: 1

            TextInput {
              id: passInput
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              verticalAlignment: Text.AlignVCenter
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              echoMode: TextInput.Password
              selectByMouse: true

              Text {
                text: "Password"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                visible: passInput.text === "" && !passInput.activeFocus
                anchors.verticalCenter: parent.verticalCenter
              }

              onAccepted: loginBtn.doLogin()
            }
          }

          Rectangle {
            id: loginBtn
            width: parent.width
            height: Style.space(32)
            color: loginBtnArea.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
            radius: Style.space(6)

            function doLogin() {
              v2raya.loginWith(userInput.text, passInput.text)
            }

            Text {
              anchors.centerIn: parent
              text: v2raya.busy ? "Authenticating…" : "Save & Login"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              id: loginBtnArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: loginBtn.doLogin()
            }
          }
        }
      }
    }
  }
}
