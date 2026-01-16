{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'argo-cd',
        rules: if $._config.alerts.enabled then std.prune([
          if $._config.alerts.appSyncFailed.enabled then {
            alert: 'ArgoCdAppSyncFailed',
            expr: |||
              sum(
                round(
                  increase(
                    argocd_app_sync_total{
                      %(argoCdSelector)s,
                      phase!="Succeeded"
                    }[%(interval)s]
                  )
                )
              ) by (%(clusterLabel)s, job, dest_server, project, name, phase) > 0
            ||| % (
              $._config
              {
                interval: $._config.alerts.appSyncFailed.interval,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.appSyncFailed.severity,
            },
            annotations: {
              summary: 'An ArgoCD Application has Failed to Sync.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has failed to sync with the status {{ $labels.phase }} the past %s.' % $._config.alerts.appSyncFailed.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.appUnhealthy.enabled then {
            alert: 'ArgoCdAppUnhealthy',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  health_status!~"%(healthyStates)s",
                  name!~"%(ignoredApps)s"
                }
              ) by (%(clusterLabel)s, job, dest_server, project, name, health_status)
              > 0
            ||| % (
              $._config
              {
                healthyStates: $._config.alerts.appUnhealthy.healthyStates,
                ignoredApps: $._config.alerts.appUnhealthy.ignoredApps,
              }
            ),
            'for': $._config.alerts.appUnhealthy.interval,
            labels: {
              severity: $._config.alerts.appUnhealthy.severity,
            },
            annotations: {
              summary: 'An ArgoCD Application is Unhealthy.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is unhealthy with the health status {{ $labels.health_status }} for the past %s.' % $._config.alerts.appUnhealthy.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.appOutOfSync.enabled then {
            alert: 'ArgoCdAppOutOfSync',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  sync_status!="Synced"
                }
              ) by (%(clusterLabel)s, job, dest_server, project, name, sync_status)
              > 0
            ||| % $._config,
            'for': $._config.alerts.appOutOfSync.interval,
            labels: {
              severity: $._config.alerts.appOutOfSync.severity,
            },
            annotations: {
              summary: 'An ArgoCD Application is Out Of Sync.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is out of sync with the sync status {{ $labels.sync_status }} for the past %s.' % $._config.alerts.appOutOfSync.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.appUnknown.enabled then {
            alert: 'ArgoCdAppUnknown',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  sync_status="Unknown",
                  name!~"%(ignoredApps)s"
                }
              ) by (%(clusterLabel)s, job, dest_server, project, name, sync_status)
              > 0
            ||| % (
              $._config
              {
                ignoredApps: $._config.alerts.appUnknown.ignoredApps,
              }
            ),
            'for': $._config.alerts.appUnknown.interval,
            labels: {
              severity: $._config.alerts.appUnknown.severity,
            },
            annotations: {
              summary: 'An ArgoCD Application is in a Unknown state.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is in a `Unknown` state for the past %s.' % $._config.alerts.appUnknown.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.appAutoSyncDisabled.enabled then {
            alert: 'ArgoCdAppAutoSyncDisabled',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  autosync_enabled!="true",
                  name!~"%(ignoredApps)s"
                }
              ) by (%(clusterLabel)s, job, dest_server, project, name, autosync_enabled)
              > 0
            ||| % (
              $._config
              {
                ignoredApps: $._config.alerts.appAutoSyncDisabled.ignoredApps,
              }
            ),
            'for': $._config.alerts.appAutoSyncDisabled.interval,
            labels: {
              severity: $._config.alerts.appAutoSyncDisabled.severity,
            },
            annotations: {
              summary: 'An ArgoCD Application has AutoSync Disabled.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has autosync disabled for the past %s.' % $._config.alerts.appAutoSyncDisabled.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.notificationDeliveryFailed.enabled then {
            alert: 'ArgoCdNotificationDeliveryFailed',
            expr: |||
              sum(
                round(
                  increase(
                    argocd_notifications_deliveries_total{
                      %(argoCdSelector)s,
                      succeeded!="true"
                    }[%(interval)s]
                  )
                )
              ) by (%(clusterLabel)s, job, exported_service, succeeded) > 0
            ||| % (
              $._config
              {
                interval: $._config.alerts.notificationDeliveryFailed.interval,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.notificationDeliveryFailed.severity,
            },
            annotations: {
              summary: 'ArgoCD Notification Delivery Failed.',
              description: 'The notification job {{ $labels.job }} has failed to deliver to {{ $labels.exported_service }} for the past %s.' % $._config.alerts.notificationDeliveryFailed.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-notifications-overview'] + '?var-job={{ $labels.job }}&var-exported_service={{ $labels.exported_service }}' + clusterVariableQueryString,
            },
          },
        ]) else [],
      },
    ],
  },
}
