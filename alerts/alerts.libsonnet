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
                summary: if groupByApp then 'ArgoCD application sync failed.' else 'ArgoCD application syncs failed.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} had at least one sync attempt fail with phase {{ $labels.phase }} in the last %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} had at least one sync attempt fail with phase {{ $labels.phase }} in the last %s.' % alertConfig.interval,
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
                summary: if groupByApp then 'ArgoCD application is unhealthy.' else 'ArgoCD applications are unhealthy.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has reported health status {{ $labels.health_status }} for at least %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have reported health status {{ $labels.health_status }} for at least %s.' % alertConfig.interval,
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
                summary: if groupByApp then 'ArgoCD application is out of sync.' else 'ArgoCD applications are out of sync.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has reported sync status {{ $labels.sync_status }} for at least %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have reported sync status {{ $labels.sync_status }} for at least %s.' % alertConfig.interval,
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
                summary: if groupByApp then 'ArgoCD application state is unknown.' else 'ArgoCD application states are unknown.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has reported sync status Unknown for at least %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have reported sync status Unknown for at least %s.' % alertConfig.interval,
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
                summary: if groupByApp then 'ArgoCD application auto-sync is disabled.' else 'ArgoCD applications have auto-sync disabled.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has had auto-sync disabled for at least %s.' % alertConfig.interval
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have had auto-sync disabled for at least %s.' % alertConfig.interval,
                dashboard_url: if groupByApp then
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}&var-application={{ $labels.name }}' + clusterVariableQueryString
                else
                  $._config.dashboardUrls['argo-cd-application-overview'] + '?var-dest_server={{ $labels.dest_server }}&var-project={{ $labels.project }}' + clusterVariableQueryString,
              },
            },
          if $._config.alerts.rolloutProgressing.enabled then
            local alertConfig = $._config.alerts.rolloutProgressing;
            local groupByApp = getGroupByApp(alertConfig);
            local groupLabels = buildLabels(groupByApp);
            {
              alert: 'ArgoCdRolloutProgressing',
              expr: |||
                sum(
                  argocd_app_info{
                    %(argoCdSelector)s,
                    health_status="Progressing",
                    name!~"%(ignoredApps)s"
                  }
                ) by (%(groupBy)s, health_status)
                > 0
              ||| % (
                $._config
                {
                  ignoredApps: alertConfig.ignoredApps,
                  groupBy: groupLabels,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: if groupByApp then 'ArgoCD application rollout is still progressing.' else 'ArgoCD application rollouts are still progressing.',
                description: if groupByApp then
                  'Application {{ $labels.dest_server }}/{{ $labels.project }}/{{ $labels.name }} has remained in health status Progressing for more than %s.' % alertConfig['for']
                else
                  'Applications in project {{ $labels.dest_server }}/{{ $labels.project }} have remained in health status Progressing for more than %s.' % alertConfig['for'],
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
              summary: 'ArgoCD notification delivery failed.',
              description: 'Notification job {{ $labels.job }} failed to deliver to {{ $labels.exported_service }} at least once in the last %s.' % $._config.alerts.notificationDeliveryFailed.interval,
              dashboard_url: $._config.dashboardUrls['argo-cd-notifications-overview'] + '?var-job={{ $labels.job }}&var-exported_service={{ $labels.exported_service }}' + clusterVariableQueryString,
            },
          },

          // ArgoCD Operational Health Alerts
          // Monitor ArgoCD's own performance and health

          if $._config.alerts.highReconciliationDuration.enabled then
            local alertConfig = $._config.alerts.highReconciliationDuration;
            {
              alert: 'ArgoCdAppControllerHighReconciliationDuration',
              expr: |||
                histogram_quantile(%(quantile)s,
                  sum(
                    rate(
                      argocd_app_reconcile_bucket{
                        %(argoCdSelector)s
                      }[%(interval)s]
                    )
                  ) by (%(clusterLabel)s, namespace, le)
                ) > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                  quantile: alertConfig.quantile,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD application reconciliation is slow.',
                description: 'The P%(quantile)s application reconciliation duration in namespace {{ $labels.namespace }} has been above %(threshold)ss for %(__for)s. The application controller may be overloaded or blocked on Kubernetes API calls.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.pendingRepoRequests.enabled then
            local alertConfig = $._config.alerts.pendingRepoRequests;
            {
              alert: 'ArgoCdRepoServerPendingRequests',
              expr: |||
                sum(
                  argocd_repo_pending_request_total{
                    %(argoCdSelector)s
                  }
                ) by (%(clusterLabel)s, namespace)
                > %(threshold)s
              ||| % (
                $._config
                {
                  threshold: alertConfig.threshold,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD repo server has pending requests.',
                description: 'Repo server in namespace {{ $labels.namespace }} has had more than %(threshold)s pending requests for %(__for)s. The repo server may be overloaded or waiting on slow repository operations.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highGitRequestDuration.enabled then
            local alertConfig = $._config.alerts.highGitRequestDuration;
            {
              alert: 'ArgoCdRepoServerHighGitRequestDuration',
              expr: |||
                histogram_quantile(%(quantile)s,
                  sum(
                    rate(
                      argocd_git_request_duration_seconds_bucket{
                        %(argoCdSelector)s
                      }[%(interval)s]
                    )
                  ) by (%(clusterLabel)s, namespace, le)
                ) > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                  quantile: alertConfig.quantile,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD repo server Git requests are slow.',
                description: 'The P%(quantile)s Git request duration in namespace {{ $labels.namespace }} has been above %(threshold)ss for %(__for)s. Repository access, network latency, or repo server load may be degraded.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.clusterConnectionErrors.enabled then
            local alertConfig = $._config.alerts.clusterConnectionErrors;
            {
              alert: 'ArgoCdClusterConnectionError',
              expr: |||
                argocd_cluster_connection_status{
                  %(argoCdSelector)s
                } < 1
              ||| % $._config,
              'for': alertConfig.interval,
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD cannot connect to a managed cluster.',
                description: 'ArgoCD in namespace {{ $labels.namespace }} has been unable to connect to cluster {{ $labels.server }} for %(interval)s. Check cluster credentials, API server reachability, and network policy.' % alertConfig,
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.gitRequestErrors.enabled then
            local alertConfig = $._config.alerts.gitRequestErrors;
            {
              alert: 'ArgoCdGitRequestErrors',
              expr: |||
                sum(
                  round(
                    increase(
                      argocd_git_fetch_fail_total{
                        %(argoCdSelector)s
                      }[%(interval)s]
                    )
                  )
                ) by (%(clusterLabel)s, namespace, repo) > 0
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD Git requests are failing.',
                description: 'ArgoCD in namespace {{ $labels.namespace }} has had Git fetch failures for repository {{ $labels.repo }} for %(__for)s. Check repository availability, credentials, and network connectivity.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highKubectlRateLimiterDuration.enabled then
            local alertConfig = $._config.alerts.highKubectlRateLimiterDuration;
            {
              alert: 'ArgoCdHighKubectlRateLimiterDuration',
              expr: |||
                histogram_quantile(%(quantile)s,
                  sum(
                    rate(
                      argocd_kubectl_rate_limiter_duration_seconds_bucket{
                        %(argoCdSelector)s
                      }[%(interval)s]
                    )
                  ) by (%(clusterLabel)s, namespace, le)
                ) > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                  quantile: alertConfig.quantile,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD kubectl client-side throttling is high.',
                description: 'The P%(quantile)s kubectl rate limiter wait time in namespace {{ $labels.namespace }} has been above %(threshold)ss for %(__for)s. ArgoCD may be throttling requests before they reach the Kubernetes API server.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highKubectlRequestDuration.enabled then
            local alertConfig = $._config.alerts.highKubectlRequestDuration;
            {
              alert: 'ArgoCdHighKubectlRequestDuration',
              expr: |||
                histogram_quantile(%(quantile)s,
                  sum(
                    rate(
                      argocd_kubectl_request_duration_seconds_bucket{
                        %(argoCdSelector)s
                      }[%(interval)s]
                    )
                  ) by (%(clusterLabel)s, namespace, le)
                ) > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                  quantile: alertConfig.quantile,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD kubectl requests are slow.',
                description: 'The P%(quantile)s kubectl request duration in namespace {{ $labels.namespace }} has been above %(threshold)ss for %(__for)s. The Kubernetes API server or network path may be slow.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highKubectlRequestRetryRate.enabled then
            local alertConfig = $._config.alerts.highKubectlRequestRetryRate;
            {
              alert: 'ArgoCdHighKubectlRequestRetryRate',
              expr: |||
                sum(
                  increase(
                    argocd_kubectl_request_retries_total{
                      %(argoCdSelector)s
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace) > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD kubectl request retry rate is high.',
                description: 'ArgoCD in namespace {{ $labels.namespace }} has had more than %(threshold)s kubectl request retries per minute for %(__for)s. This usually points to Kubernetes API errors, throttling, or network instability.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highGrpcErrorRate.enabled then
            local alertConfig = $._config.alerts.highGrpcErrorRate;
            {
              alert: 'ArgoCdHighGrpcErrorRate',
              expr: |||
                sum(
                  rate(
                    grpc_server_handled_total{
                      %(argoCdServerSelector)s,
                      grpc_code!="OK"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, job)
                /
                sum(
                  rate(
                    grpc_server_handled_total{
                      %(argoCdServerSelector)s
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, job) * 100
                > %(threshold)s
              ||| % (
                $._config
                {
                  interval: alertConfig.interval,
                  threshold: alertConfig.threshold,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD gRPC error rate is high.',
                description: 'ArgoCD job {{ $labels.job }} in namespace {{ $labels.namespace }} has had a gRPC error rate above %(threshold)s%% for %(__for)s. Check argocd-server errors and upstream dependencies.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },

          if $._config.alerts.highKubectlPendingExec.enabled then
            local alertConfig = $._config.alerts.highKubectlPendingExec;
            {
              alert: 'ArgoCdHighKubectlPendingExec',
              expr: |||
                sum(
                  argocd_kubectl_exec_pending{
                    %(argoCdSelector)s
                  }
                ) by (%(clusterLabel)s, namespace) > %(threshold)s
              ||| % (
                $._config
                {
                  threshold: alertConfig.threshold,
                }
              ),
              'for': alertConfig['for'],
              labels: {
                severity: alertConfig.severity,
              },
              annotations: {
                summary: 'ArgoCD has many pending kubectl executions.',
                description: 'ArgoCD in namespace {{ $labels.namespace }} has had more than %(threshold)s pending kubectl executions for %(__for)s. This may indicate resource contention, slow Kubernetes API calls, or slow manifest generation.' % (alertConfig { __for: alertConfig['for'] }),
                dashboard_url: $._config.dashboardUrls['argo-cd-operational-overview'] + clusterVariableQueryString,
              },
            },
        ]) else [],
      },
    ],
  },
}
