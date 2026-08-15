function parseJson(str) {
  try {
    return JSON.parse(str)
  } catch (e) {
    return null
  }
}

function parseNodes(touchData) {
  if (!touchData) return []
  var out = []
  var seen = {}

  // 1. Regular servers
  if (Array.isArray(touchData.servers)) {
    for (var i = 0; i < touchData.servers.length; i++) {
      var s = touchData.servers[i]
      if (!s) continue
      var serverId = s.id !== undefined ? s.id : (i + 1)
      var sType = s._type || "server"
      var sub = (s.sub !== undefined && s.sub !== null) ? s.sub : 0
      var key = sType + ":" + sub + ":" + serverId
      if (seen[key]) continue
      seen[key] = true

      var name = String(s.name || s.remarks || s.address || ("Server " + serverId)).trim()
      var valObj = { id: serverId, _type: sType, sub: sub }
      out.push({
        value: JSON.stringify(valObj),
        label: name,
        id: serverId,
        _type: sType,
        sub: sub,
        name: name,
        hostname: s.address || s.host || "",
        port: s.port || ""
      })
    }
  }

  // 2. Subscriptions
  if (touchData.subscriptions && typeof touchData.subscriptions === "object") {
    var subKeys = Object.keys(touchData.subscriptions)
    for (var k = 0; k < subKeys.length; k++) {
      var subName = subKeys[k]
      var subObj = touchData.subscriptions[subName]
      if (!subObj) continue

      var subServers = Array.isArray(subObj.servers)
        ? subObj.servers
        : (Array.isArray(subObj) ? subObj : [])

      for (var j = 0; j < subServers.length; j++) {
        var ss = subServers[j]
        if (!ss) continue
        var ssId = ss.id !== undefined ? ss.id : (j + 1)
        var ssType = ss._type || "subscriptionServer"
        var ssKey = ssType + ":" + subName + ":" + ssId
        if (seen[ssKey]) continue
        seen[ssKey] = true

        var rawSsName = String(ss.name || ss.remarks || ss.address || ("Node " + ssId)).trim()
        var fullLabel = (subName ? "[" + subName + "] " : "") + rawSsName
        var ssValObj = { id: ssId, _type: ssType, sub: subName }

        out.push({
          value: JSON.stringify(ssValObj),
          label: fullLabel,
          id: ssId,
          _type: ssType,
          sub: subName,
          name: fullLabel,
          hostname: ss.address || ss.host || "",
          port: ss.port || ""
        })
      }
    }
  }

  out.sort(function(a, b) {
    return a.label.localeCompare(b.label)
  })

  return out
}

function getConnectedNodeValue(touchData) {
  if (!touchData || !Array.isArray(touchData.connectedServer) || touchData.connectedServer.length === 0) {
    return ""
  }
  var conn = touchData.connectedServer[0]
  if (!conn) return ""
  if (typeof conn === "string") return conn

  return JSON.stringify({
    id: conn.id,
    _type: conn._type || "server",
    sub: (conn.sub !== undefined && conn.sub !== null) ? conn.sub : 0
  })
}

function getConnectedNodeName(touchData, nodesList) {
  var valStr = getConnectedNodeValue(touchData)
  if (!valStr) return ""
  var valObj = parseJson(valStr)
  if (!valObj) return ""

  if (Array.isArray(nodesList)) {
    for (var i = 0; i < nodesList.length; i++) {
      var n = nodesList[i]
      if (n && n.value === valStr) {
        return n.label
      }
    }
  }

  return valObj.sub ? ("Node " + valObj.id + " (" + valObj.sub + ")") : ("Node " + valObj.id)
}

function statusText(state, activeNodeName) {
  switch (String(state || "")) {
    case "Connected":
      return activeNodeName ? ("Connected (" + activeNodeName + ")") : "Connected"
    case "Connecting": return "Connecting…"
    case "Disconnecting": return "Disconnecting…"
    case "Disconnected": return "Disconnected"
    case "Unauthorized": return "Authentication Required"
    case "Unavailable": return "Unavailable"
    default: return "Checking…"
  }
}

function elide(text, maxLen) {
  var len = maxLen || 140
  var value = String(text || "").replace(/\s+/g, " ").trim()
  return value.length > len ? value.substring(0, len - 3) + "…" : value
}
