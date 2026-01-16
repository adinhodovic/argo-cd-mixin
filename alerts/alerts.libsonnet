{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',

  // Helper function: get groupByApplication for an alert (with fallback to top-level)
  local getGroupByApp(alertConfig) =
    if std.objectHas(alertConfig, 'groupByApplication') then
      alertConfig.groupByApplication
    else
      $._config.alerts.groupByApplication,

  // Helper function: build label string based on groupByApplication flag
  local buildLabels(groupByApp) =
    if groupByApp then
      '%(clusterLabel)s, job, dest_server, project, name' % $._config
    else
      'job, dest_server, project',

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'argo-cd',
        rules: if $._config.alerts.enabled then std.prune([
          if $._config.alerts.appSyncFailed.enabled then
            local alertConfig = $._config.alerts.appSyncFailed;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
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
                ) by (%(groupBy)s, phase) > 0
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  groupBy: groupLabels,
                }
              ),
              'for': '1m',
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'An ArgoCD Application has Failed to Sync.' else 'ArgoCD Applications have Failed to Sync.',
                description: if groupByApp then
                  'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has failed to sync with the status {{ $labels.phase }} the past %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have failed to sync with the status {{ $labels.phase }} the past %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
              },
            },
          if $._config.alerts.appUnhealthy.enabled then
            local alertConfig = $._config.alerts.appUnhealthy;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
              alert: 'ArgoCdAppUnhealthy',
              expr: |||
                sum(
                  argocd_app_info{
                    %(argoCdSelector)s,
                    health_status!~"%(healthyStates)s",
                    name!~"%(ignoredApps)s"
                  }
                ) by (%(groupBy)s, health_status)
                > 0
              ||| % (
                $._config
                {
                  healthyStates: alertConfig.healthyStates,
                  ignoredApps: alertConfig.ignoredApps,
                  groupBy: groupLabels,
                }
              ),
              'for': alertConfig.interval,
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'An ArgoCD Application is Unhealthy.' else 'ArgoCD Applications are Unhealthy.',
                description: if groupByApp then
                  'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is unhealthy with the health status {{ $labels.health_status }} for the past %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} are unhealthy with the health status {{ $labels.health_status }} for the past %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
              },
            },
          if $._config.alerts.appOutOfSync.enabled then
            local alertConfig = $._config.alerts.appOutOfSync;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
              alert: 'ArgoCdAppOutOfSync',
              expr: |||
                sum(
                  argocd_app_info{
                    %(argoCdSelector)s,
                    sync_status!="Synced"
                  }
                ) by (%(groupBy)s, sync_status)
                > 0
              ||| % (
                $._config
                {
                  groupBy: groupLabels,
                }
              ),
              'for': alertConfig.interval,
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'An ArgoCD Application is Out Of Sync.' else 'ArgoCD Applications are Out Of Sync.',
                description: if groupByApp then
                  'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is out of sync with the sync status {{ $labels.sync_status }} for the past %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} are out of sync with the sync status {{ $labels.sync_status }} for the past %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
              },
            },
          if $._config.alerts.appUnknown.enabled then
            local alertConfig = $._config.alerts.appUnknown;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
              alert: 'ArgoCdAppUnknown',
              expr: |||
                sum(
                  argocd_app_info{
                    %(argoCdSelector)s,
                    sync_status="Unknown",
                    name!~"%(ignoredApps)s"
                  }
                ) by (%(groupBy)s, sync_status)
                > 0
              ||| % (
                $._config
                {
                  ignoredApps: alertConfig.ignoredApps,
                  groupBy: groupLabels,
                }
              ),
              'for': alertConfig.interval,
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'An ArgoCD Application is in a Unknown state.' else 'ArgoCD Applications are in a Unknown state.',
                description: if groupByApp then
                  'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is in a `Unknown` state for the past %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} are in a `Unknown` state for the past %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
              },
            },
          if $._config.alerts.appAutoSyncDisabled.enabled then
            local alertConfig = $._config.alerts.appAutoSyncDisabled;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
              alert: 'ArgoCdAppAutoSyncDisabled',
              expr: |||
                sum(
                  argocd_app_info{
                    %(argoCdSelector)s,
                    autosync_enabled!="true",
                    name!~"%(ignoredApps)s"
                  }
                ) by (%(groupBy)s, autosync_enabled)
                > 0
              ||| % (
                $._config
                {
                  ignoredApps: alertConfig.ignoredApps,
                  groupBy: groupLabels,
                }
              ),
              'for': alertConfig.interval,
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'An ArgoCD Application has AutoSync Disabled.' else 'ArgoCD Applications have AutoSync Disabled.',
                description: if groupByApp then
                  'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has autosync disabled for the past %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have autosync disabled for the past %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
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
