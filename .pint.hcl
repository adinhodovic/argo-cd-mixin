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

rule {
  match {
    name = "ArgoCdAppControllerHighReconciliationDuration"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdRepoServerPendingRequests"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdRepoServerHighGitRequestDuration"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdClusterConnectionError"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdGitRequestErrors"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdHighKubectlRateLimiterDuration"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdHighKubectlRequestDuration"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdHighKubectlRequestRetryRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdHighGrpcErrorRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoCdHighKubectlPendingExec"
  }
  disable = ["promql/regexp"]
}
