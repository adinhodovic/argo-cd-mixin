{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'argo-cd',
        rules: [
          {
            alert: 'ArgoCdAppOutOfSync',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  sync_status!="Synced"
                }
              ) by (job, dest_server, project, name, sync_status)
              > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': $._config.argoCdAppOutOfSyncFor,
            annotations: {
              summary: 'An ArgoCD Application is Out Of Sync.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is out of sync with the sync status {{ $labels.sync_status }} for the past %s.' % $._config.argoCdAppOutOfSyncFor,
              dashboard_url: $._config.applicationOverviewDashboardUrl + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}',
            },
          },
          {
            alert: 'ArgoCdAppUnhealthy',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  health_status!~"Healthy|Progressing"
                }
              ) by (job, dest_server, project, name, health_status)
              > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': $._config.argoCdAppUnhealthyFor,
            annotations: {
              summary: 'An ArgoCD Application is Unhealthy.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} is unhealthy with the health status {{ $labels.health_status }} for the past %s.' % $._config.argoCdAppUnhealthyFor,
              dashboard_url: $._config.applicationOverviewDashboardUrl + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}',
            },
          },
          {
            alert: 'ArgoCdAppAutoSyncDisabled',
            expr: |||
              sum(
                argocd_app_info{
                  %(argoCdSelector)s,
                  autosync_enabled!="true",
                  name!~"%(argoAutoSyncDisabledIgnoredApps)s"
                }
              ) by (job, dest_server, project, name, autosync_enabled)
              > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': $._config.argoCdAppAutoSyncDisabledFor,
            annotations: {
              summary: 'An ArgoCD Application has AutoSync Disabled.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has autosync disabled for the past %s.' % $._config.argoCdAppAutoSyncDisabledFor,
              dashboard_url: $._config.applicationOverviewDashboardUrl + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}',
            },
          },
          {
            alert: 'ArgoCdAppSyncFailed',
            expr: |||
              sum(
                round(
                  increase(
                    argocd_app_sync_total{
                      %(argoCdSelector)s,
                      phase!="Succeeded"
                    }[%(argoCdAppSyncInterval)s]
                  )
                )
              ) by (job, dest_server, project, name, phase) > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': '1m',
            annotations: {
              summary: 'An ArgoCD Application has Failed to Sync.',
              description: 'The application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has failed to sync with the status {{ $labels.phase }} the past %s.' % $._config.argoCdAppSyncInterval,
              dashboard_url: $._config.applicationOverviewDashboardUrl + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}',
            },
          },
          {
            alert: 'ArgoCdNotificationDeliveryFailed',
            expr: |||
              sum(
                round(
                  increase(
                    argocd_notifications_deliveries_total{
                      %(argoCdSelector)s,
                      succeeded!="true"
                    }[%(argoCdNotificationDeliveryInterval)s]
                  )
                )
              ) by (job, exported_service, succeeded) > 0
            ||| % $._config,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'ArgoCD Notification Delivery Failed.',
              description: 'The notification job {{ $labels.job }} has failed to deliver to {{ $labels.exported_service }} for the past %s.' % $._config.argoCdNotificationDeliveryInterval,
              dashboard_url: $._config.notificationsOverviewDashboardUrl + '?var-job={{ $labels.job }}&var-exported_service={{ $labels.exported_service }}',
            },
          },
        ],
      },
    ],
  },
}
