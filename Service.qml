import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property string customUsername: ""
  property string customPassword: ""

  readonly property string serverUrl: String(setting("serverUrl", "http://127.0.0.1:2017")).replace(/\/+$/, "")
  readonly property string usernameSetting: customUsername !== "" ? customUsername : String(setting("username", "")).trim()
  readonly property string passwordSetting: customPassword !== "" ? customPassword : String(setting("password", "")).trim()
  readonly property string tokenSetting: String(setting("token", "")).trim()
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 60)

  property string authToken: tokenSetting
  property string connectionState: "Unknown"
  property string currentNode: ""
  property string activeNodeName: ""
  property var nodes: []
  property bool nodesLoaded: false
  property bool coreRunning: false

  property int _desired: -1
  property bool _needsCoreStart: false
  readonly property bool connected: coreRunning && connectionState === "Connected"
  readonly property bool transitioning: connectionState === "Connecting" || connectionState === "Disconnecting"
  readonly property bool unavailable: connectionState === "Unavailable" || connectionState === "Unauthorized"
  readonly property bool active: _desired === -1 ? connected : (_desired === 1)
  readonly property bool busy: _desired !== -1 || controlProcess.running || setNodeProcess.running || loginProcess.running
  readonly property string statusText: Model.statusText(connectionState, activeNodeName)
  property string actionStatus: ""
  property string lastError: ""

  property string _stateOutput: ""
  property string _controlOutput: ""
  property string _controlError: ""
  property string _loginOutput: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  onSettingsChanged: {
    if (tokenSetting !== "") {
      authToken = tokenSetting
    }
  }

  function refresh() {
    if (controlProcess.running || setNodeProcess.running) return
    if (!stateProcess.running) {
      _stateOutput = ""
      stateProcess.command = buildCurlCommand("GET", "/api/touch", null)
      stateProcess.running = true
    }
  }

  function buildCurlCommand(method, endpoint, bodyObj) {
    var cmd = ["curl", "-s", "-m", "5"]

    var tokenToUse = authToken !== "" ? authToken : tokenSetting
    if (tokenToUse !== "") {
      cmd.push("-H", "Authorization: " + tokenToUse)
    }

    if (method === "POST" || method === "PUT" || method === "DELETE") {
      cmd.push("-X", method)
      if (bodyObj !== null && bodyObj !== undefined) {
        cmd.push("-H", "Content-Type: application/json")
        cmd.push("-d", JSON.stringify(bodyObj))
      }
    }

    cmd.push(serverUrl + endpoint)
    return cmd
  }

  function toggle() {
    if (busy) return

    if (connected || coreRunning) {
      // Stop the v2ray core entirely — this is the clean way to disconnect
      _desired = 0
      _needsCoreStart = false
      connectionState = "Disconnecting"
      controlProcess.command = buildCurlCommand("DELETE", "/api/v2ray", null)
    } else {
      // Start the v2ray core — connects to whatever nodes were selected
      _desired = 1
      connectionState = "Connecting"
      if (currentNode !== "") {
        var connObj = Model.parseJson(currentNode)
        if (connObj) {
          _needsCoreStart = true
          controlProcess.command = buildCurlCommand("POST", "/api/connection", {
            id: connObj.id,
            _type: connObj._type || "server",
            sub: (connObj.sub !== undefined && connObj.sub !== null) ? connObj.sub : 0,
            outbound: ""
          })
        } else {
          _needsCoreStart = false
          controlProcess.command = buildCurlCommand("POST", "/api/v2ray", null)
        }
      } else {
        _needsCoreStart = false
        controlProcess.command = buildCurlCommand("POST", "/api/v2ray", null)
      }
    }
    _controlOutput = ""
    _controlError = ""
    controlProcess.running = true
  }

  function setNode(valueStr) {
    if (!valueStr || busy) return
    var nodeObj = Model.parseJson(valueStr)
    if (!nodeObj) return

    currentNode = valueStr
    _desired = 1
    connectionState = "Connecting"
    setNodeProcess.command = buildCurlCommand("POST", "/api/connection", {
      id: nodeObj.id,
      _type: nodeObj._type || "server",
      sub: (nodeObj.sub !== undefined && nodeObj.sub !== null) ? nodeObj.sub : 0,
      outbound: ""
    })
    setNodeProcess.running = true
  }

  function attemptLogin() {
    if (loginProcess.running || usernameSetting === "" || passwordSetting === "") return
    loginProcess.command = ["curl", "-s", "-m", "5", "-H", "Content-Type: application/json", "-X", "POST", "-d", JSON.stringify({
      username: usernameSetting,
      password: passwordSetting
    }), serverUrl + "/api/login"]
    loginProcess.running = true
  }

  function loginWith(u, p) {
    customUsername = String(u || "").trim()
    customPassword = String(p || "").trim()
    authToken = ""
    attemptLogin()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: settleTimer
    property int ticks: 0
    interval: 1500
    repeat: true
    running: false
    onTriggered: {
      settleTimer.ticks += 1
      root.refresh()
      if (settleTimer.ticks >= 8) {
        settleTimer.ticks = 0
        settleTimer.running = false
        root._desired = -1
      }
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: stateProcess
    running: false
    command: []
    stdout: StdioCollector { id: stateStdout; waitForEnd: true; onStreamFinished: root._stateOutput = text }
    onExited: function(exitCode) {
      var stdout = String(stateStdout.text || root._stateOutput || "").trim()
      if (exitCode === 0 && stdout !== "") {
        var res = Model.parseJson(stdout)
        if (res && res.code === "SUCCESS" && res.data) {
          var touchData = res.data.touch || {}
          var isRunning = !!res.data.running
          var connVal = Model.getConnectedNodeValue(touchData)

          root.coreRunning = isRunning
          root.nodes = Model.parseNodes(touchData)
          root.nodesLoaded = root.nodes.length > 0

          var isNowConnected = isRunning && connVal !== ""

          if (root._desired !== -1) {
            // We are in a transition — check if target state reached
            var wantConnected = (root._desired === 1)
            if (wantConnected && isNowConnected) {
              // Target: connected, and we are now connected
              root.currentNode = connVal
              root.activeNodeName = Model.getConnectedNodeName(touchData, root.nodes)
              root.connectionState = "Connected"
              root._desired = -1
              settleTimer.running = false
              settleTimer.ticks = 0
            } else if (!wantConnected && !isRunning) {
              // Target: disconnected, and core is stopped
              root.activeNodeName = ""
              root.connectionState = "Disconnected"
              root._desired = -1
              settleTimer.running = false
              settleTimer.ticks = 0
            }
            // Otherwise keep waiting — don't update connectionState
          } else {
            // Not transitioning, update state from API
            if (isNowConnected) {
              root.currentNode = connVal
              root.activeNodeName = Model.getConnectedNodeName(touchData, root.nodes)
              root.connectionState = "Connected"
            } else {
              root.activeNodeName = ""
              if (root.currentNode === "" && root.nodes.length > 0) {
                root.currentNode = root.nodes[0].value
              }
              root.connectionState = "Disconnected"
            }
          }
        } else if (res && res.message && (res.message.indexOf("token") !== -1 || res.message.indexOf("login") !== -1)) {
          if (root.usernameSetting !== "" && root.passwordSetting !== "") {
            root.attemptLogin()
          } else {
            root._desired = -1
            settleTimer.running = false
            root.connectionState = "Unauthorized"
            root.lastError = "Authentication required"
          }
        } else {
          if (root._desired === -1) {
            root.connectionState = "Unavailable"
          }
        }
      } else {
        if (root._desired === -1) {
          root.connectionState = "Unavailable"
        }
      }
    }
  }

  Process {
    id: loginProcess
    running: false
    command: []
    stdout: StdioCollector { id: loginStdout; waitForEnd: true; onStreamFinished: root._loginOutput = text }
    onExited: function(exitCode) {
      var stdout = String(loginStdout.text || root._loginOutput || "").trim()
      if (exitCode === 0 && stdout !== "") {
        var res = Model.parseJson(stdout)
        if (res && res.code === "SUCCESS" && res.data && res.data.token) {
          root.authToken = res.data.token
          root.lastError = ""
          root.refresh()
          return
        }
      }
      root.connectionState = "Unauthorized"
      root.lastError = "Login failed: check username and password"
    }
  }

  Process {
    id: controlProcess
    running: false
    command: []
    stdout: StdioCollector { id: controlStdout; waitForEnd: true; onStreamFinished: root._controlOutput = text }
    stderr: StdioCollector { id: controlStderr; waitForEnd: true; onStreamFinished: root._controlError = text }
    onExited: function(exitCode) {
      var stdout = String(controlStdout.text || root._controlOutput || "")
      var stderr = String(controlStderr.text || root._controlError || "")
      var res = Model.parseJson(stdout.trim())

      if (exitCode !== 0 || (res && res.code !== "SUCCESS")) {
        root._desired = -1
        root.connectionState = "Disconnected"
        var errMsg = (res && res.message) ? res.message : (stderr || stdout || "v2rayA command failed")
        root.lastError = Model.elide(errMsg)
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
        // Check if the response itself has touch data with connected info
        if (res && res.data && res.data.touch) {
          var connVal = Model.getConnectedNodeValue(res.data.touch)
          var isRunning = !!res.data.running
          root.coreRunning = isRunning
          if (root._desired === 0 && !isRunning) {
            root.connectionState = "Disconnected"
            root.activeNodeName = ""
            root._desired = -1
            root._needsCoreStart = false
            return
          } else if (root._desired === 1 && isRunning && connVal !== "") {
            root.currentNode = connVal
            root.activeNodeName = Model.getConnectedNodeName(res.data.touch, root.nodes)
            root.connectionState = "Connected"
            root._desired = -1
            root._needsCoreStart = false
            return
          } else if (root._desired === 1 && root._needsCoreStart && connVal !== "") {
            // Node selected successfully, now start the core
            root._needsCoreStart = false
            controlProcess.command = buildCurlCommand("POST", "/api/v2ray", null)
            _controlOutput = ""
            _controlError = ""
            controlProcess.running = true
            return
          }
        }
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }

  Process {
    id: setNodeProcess
    running: false
    command: []
    stdout: StdioCollector { id: setNodeStdout; waitForEnd: true }
    stderr: StdioCollector { id: setNodeStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var stdout = String(setNodeStdout.text || "").trim()
      var res = Model.parseJson(stdout)

      if (exitCode !== 0 || (res && res.code !== "SUCCESS")) {
        root._desired = -1
        root.connectionState = "Disconnected"
        var errMsg = (res && res.message) ? res.message : (setNodeStderr.text || "Could not switch v2rayA node")
        root.lastError = Model.elide(errMsg)
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
        if (res && res.data && res.data.touch) {
          var connVal = Model.getConnectedNodeValue(res.data.touch)
          var isRunning = !!res.data.running
          root.coreRunning = isRunning
          if (isRunning && connVal !== "") {
            root.currentNode = connVal
            root.activeNodeName = Model.getConnectedNodeName(res.data.touch, root.nodes)
            root.connectionState = "Connected"
            root._desired = -1
            return
          } else if (connVal !== "") {
            // Node selected, now start the core
            controlProcess.command = buildCurlCommand("POST", "/api/v2ray", null)
            _controlOutput = ""
            _controlError = ""
            controlProcess.running = true
            return
          }
        }
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }
}
