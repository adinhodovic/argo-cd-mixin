rule {
  match {
    name = "ArgoCdAppAutoSyncDisabled"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdAppSyncFailed"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdAppUnhealthy"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdAppOutOfSync"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdNotificationDeliveryFailed"
  }
  disable = ["promql/regexp"]
}
