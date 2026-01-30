local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local pieChartPanel = g.panel.pieChart;

// Pie Chart
local pcStandardOptions = pieChartPanel.standardOptions;
local pcOverride = pcStandardOptions.override;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;

{
  local dashboardName = 'argo-cd-operational-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.kubernetesCluster,
        defaultVariables.project,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        clustersCount: |||
          sum(
            argocd_cluster_info{
              %(default)s
            }
          )
        ||| % defaultFilters,

        repositoriesCount: |||
          count(
            count(
              argocd_app_info{
                %(default)s
              }
            )
            by (repo)
          )
        ||| % defaultFilters,

        appsCount: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          )
        ||| % defaultFilters,

        healthStatus: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (health_status)
        ||| % defaultFilters,

        apps: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (job, dest_server, project, name, health_status, sync_status)
        ||| % defaultFilters,

        syncStatusQuery: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (sync_status)
        ||| % defaultFilters,

        syncActivity: |||
          sum(
            round(
              increase(
                argocd_app_sync_total{
                  %(withProject)s
                }[$__rate_interval]
              )
            )
          ) by (job, dest_server, project, name)
          > 0
        ||| % defaultFilters,

        syncFailures: |||
          sum(
            round(
              increase(
                argocd_app_sync_total{
                  %(withProject)s,
                  phase=~"Error|Failed"
                }[$__rate_interval]
              )
            )
          ) by (job, dest_server, project, name, phase)
          > 0
        ||| % defaultFilters,

        reconcilationActivity: |||
          sum(
            round(
              increase(
                argocd_app_reconcile_count{
                  %(default)s
                }[$__rate_interval]
              )
            )
          ) by (namespace, job)
        ||| % defaultFilters,

        reconcilationPerformance: |||
          sum(
            rate(
              argocd_app_reconcile_bucket{
                %(default)s
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        k8sApiActivity: |||
          sum(
            round(
              increase(
                argocd_app_k8s_request_total{
                  %(default)s
                }[$__rate_interval]
              )
            )
          ) by (job, verb, resource_kind)
        ||| % defaultFilters,

        pendingKubectlRun: |||
          sum(
            argocd_kubectl_exec_pending{
              %(default)s
            }
          ) by (job, command)
        ||| % defaultFilters,

        resourceObjects: |||
          sum(
            argocd_cluster_api_resource_objects{
              %(default)s,
              %(kubernetesClusterServer)s
            }
          ) by (namespace, job, server)
        ||| % defaultFilters,

        apiResources: |||
          sum(
            argocd_cluster_api_resources{
              %(default)s,
              %(kubernetesClusterServer)s
            }
          ) by (namespace, job, server)
        ||| % defaultFilters,

        gitRequestsLsRemote: |||
          sum(
            increase(
              argocd_git_request_total{
                %(default)s,
                request_type="ls-remote"
              }[$__rate_interval]
            )
          ) by (namespace, job, repo)
        ||| % defaultFilters,

        gitLsRemotePerformance: |||
          sum(
            rate(
              argocd_git_request_duration_seconds_bucket{
                %(default)s,
                request_type="ls-remote"
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        gitFetchPerformance: |||
          sum(
            rate(
              argocd_git_request_duration_seconds_bucket{
                %(default)s,
                request_type="fetch"
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        clusterEvents: |||
          sum(
            increase(
              argocd_cluster_events_total{
                %(default)s,
                %(kubernetesClusterServer)s
              }[$__rate_interval]
            )
          ) by (namespace, job, server)
        ||| % defaultFilters,

        gitRequestsCheckout: |||
          sum(
            increase(
              argocd_git_request_total{
                %(default)s,
                request_type="fetch"
              }[$__rate_interval]
            )
          ) by (namespace, job, repo)
        ||| % defaultFilters,

        pendingRepoRequests: |||
          sum(
            argocd_repo_pending_request_total{
              %(default)s
            }
          ) by (namespace, job)
        ||| % defaultFilters,

        clusterConnectionStatus: |||
          sum(
            argocd_cluster_connection_status{
              %(default)s,
              %(kubernetesClusterServer)s
            }
          ) by (namespace, job, server, k8s_version)
        ||| % defaultFilters,

        gitFetchFailures: |||
          sum(
            increase(
              argocd_git_fetch_fail_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, repo)
        ||| % defaultFilters,

        // Redis Performance Metrics
        redisRequestTotal: |||
          sum(
            rate(
              argocd_redis_request_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, initiator)
        ||| % defaultFilters,

        redisRequestDuration: |||
          sum(
            rate(
              argocd_redis_request_duration_seconds_bucket{
                %(default)s
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        // Kubectl Exec Metrics
        kubectlExecTotal: |||
          sum(
            round(
              increase(
                argocd_kubectl_exec_total{
                  %(default)s
                }[$__rate_interval]
              )
            )
          ) by (namespace, job, command)
        ||| % defaultFilters,

        // Cluster Cache Metrics
        clusterCacheAge: |||
          argocd_cluster_cache_age_seconds{
            %(default)s,
            %(kubernetesClusterServer)s
          }
        ||| % defaultFilters,

        // Resource Event Processing Metrics
        resourceEventProcessingDuration: |||
          sum(
            rate(
              argocd_resource_events_processing_bucket{
                %(default)s
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        resourceEventsBatchSize: |||
          sum(
            argocd_resource_events_processed_in_batch{
              %(default)s
            }
          ) by (namespace, job)
        ||| % defaultFilters,
      };

      local panels = {

        clusterCountStat:
          mixinUtils.dashboards.statPanel(
            'Clusters',
            'short',
            queries.clustersCount,
            description='The total number of clusters being managed by ArgoCD.',
          ),

        repositoryCountStat:
          mixinUtils.dashboards.statPanel(
            'Repositories',
            'short',
            queries.repositoriesCount,
            description='The total number of Git repositories being monitored by ArgoCD.',
          ),

        applicationCountStat:
          mixinUtils.dashboards.statPanel(
            'Applications',
            'short',
            queries.appsCount,
            description='The total number of applications being managed by ArgoCD.',
          ),

        healthStatusPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Health Status',
            'short',
            queries.healthStatus,
            '{{ health_status }}',
            description='The distribution of application health statuses managed by ArgoCD.',
            overrides=[
              pcOverride.byName.new('Synced') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('green')
              ),
              pcOverride.byName.new('OutOfSync') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('red')
              ),
              pcOverride.byName.new('Unknown') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('yellow')
              ),
            ]
          ),

        syncStatusPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Sync Status',
            'short',
            queries.syncStatusQuery,
            '{{ sync_status }}',
            description='The distribution of application sync statuses managed by ArgoCD.',
            overrides=[
              pcOverride.byName.new('Synced') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('green')
              ),
              pcOverride.byName.new('OutOfSync') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('red')
              ),
              pcOverride.byName.new('Unknown') +
              pcOverride.byName.withPropertiesFromOptions(
                pcStandardOptions.color.withMode('fixed') +
                pcStandardOptions.color.withFixedColor('yellow')
              ),
            ]
          ),

        appsTablePanel:
          mixinUtils.dashboards.tablePanel(
            'Applications',
            'short',
            queries.apps,
            description='A table listing all applications managed by ArgoCD, along with their health and sync statuses.',
            sortBy={ name: 'Application', desc: false },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    dest_server: 'Kubernetes Cluster',
                    project: 'Project',
                    name: 'Application',
                    health_status: 'Health Status',
                    sync_status: 'Sync Status',
                  },
                  indexByName: {
                    name: 0,
                    project: 1,
                    health_status: 2,
                    sync_status: 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    dest_server: true,
                    Value: true,
                  },
                }
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/argo-cd-application-overview?&var-project=${__data.fields.Project}&var-application=${__data.fields.Application}' % $._config.dashboardIds['argo-cd-application-overview']
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        syncActivityTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Sync Activity',
            'short',
            queries.syncActivity,
            '{{ project }}/{{ name }}',
            description='A timeseries panel showing sync activity for applications managed by ArgoCD.',
            stack='normal',
          ),

        syncFailuresTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Sync Failures',
            'short',
            queries.syncFailures,
            '{{ project }}/{{ name }} - {{ phase }}',
            description='A timeseries panel showing sync failures for applications managed by ArgoCD.',
            stack='normal'
          ),

        reconcilationActivtyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Reconciliation Activity',
            'short',
            queries.reconcilationActivity,
            '{{ namespace }}/{{ job }}',
            description='A timeseries panel showing reconciliation activity for applications managed by ArgoCD.',
            stack='normal'
          ),

        reconcilationPerformanceHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Reconciliation Performance',
            's',
            [
              {
                expr: queries.reconcilationPerformance,
                legend: '{{ le }}',
              },
            ],
            description='A heatmap panel showing reconciliation performance for applications managed by ArgoCD.',
          ),

        k8sApiActivityTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'K8s API Activity',
            'short',
            queries.k8sApiActivity,
            '{{ verb }} {{ resource_kind }}',
            description='A timeseries panel showing Kubernetes API activity for applications managed by ArgoCD.',
            stack='normal'
          ),

        pendingKubectlTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pending Kubectl Runs',
            'short',
            queries.pendingKubectlRun,
            '{{ command }}',
            description='A timeseries panel showing pending kubectl runs for ArgoCD.',
            stack='normal'
          ),

        resourceObjectsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Resource Objects',
            'short',
            queries.resourceObjects,
            '{{ server }}',
            description='A timeseries panel showing the number of resource objects in each cluster managed by ArgoCD.',
            stack='normal'
          ),

        apiResourcesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'API Resources',
            'short',
            queries.apiResources,
            '{{ server }}',
            description='A timeseries panel showing the number of API resources in each cluster managed by ArgoCD.',
            stack='normal'
          ),

        clusterEventsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Cluster Events',
            'short',
            queries.clusterEvents,
            '{{ server }}',
            description='A timeseries panel showing cluster events for clusters managed by ArgoCD.',
            stack='normal'
          ),

        gitRequestsLsRemoteTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Git Requests (ls-remote)',
            'short',
            queries.gitRequestsLsRemote,
            '{{ namespace }} - {{ repo }}',
            description='A timeseries panel showing git ls-remote requests made by ArgoCD.',
            stack='normal'
          ),

        gitRequestsCheckoutTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Git Requests (checkout)',
            'short',
            queries.gitRequestsCheckout,
            '{{ namespace }} - {{ repo }}',
            description='A timeseries panel showing git checkout requests made by ArgoCD.',
            stack='normal'
          ),

        gitLsRemotePerformanceHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Git Ls-remote Performance',
            's',
            [
              {
                expr: queries.gitLsRemotePerformance,
                legend: '{{ le }}',
              },
            ],
            description='A heatmap panel showing git ls-remote performance for ArgoCD.',
          ),

        gitFetchPerformanceHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Git Fetch Performance',
            's',
            [
              {
                expr: queries.gitFetchPerformance,
                legend: '{{ le }}',
              },
            ],
            description='A heatmap panel showing git fetch performance for ArgoCD.',
          ),

        pendingRepoRequestsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pending Repo Requests',
            'short',
            queries.pendingRepoRequests,
            '{{ namespace }}/{{ job }}',
            description='A timeseries panel showing pending requests in the ArgoCD repo server queue. High values may indicate the repo server needs scaling.',
            stack='normal'
          ),

        clusterConnectionStatusTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Cluster Connection Status',
            'short',
            queries.clusterConnectionStatus,
            '{{ server }} - {{ k8s_version }}',
            description='A timeseries panel showing the connection status of each cluster managed by ArgoCD. Failed connections indicate cluster connectivity or authentication issues.',
            min=0,
            max=1,
            fillOpacity=0
          ),

        gitFetchFailuresTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Git Fetch Failures',
            'short',
            queries.gitFetchFailures,
            '{{ namespace }} - {{ repo }}',
            description='A timeseries panel showing git fetch failures for repositories monitored by ArgoCD. High values may indicate git repository connectivity or authentication issues.',
            stack='normal'
          ),

        // Redis Performance Panels
        redisRequestRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Redis Request Rate',
            'reqps',
            queries.redisRequestTotal,
            '{{ initiator }}',
            description='Rate of Redis requests by ArgoCD component. High rates may indicate Redis becoming a bottleneck at scale.',
            stack='normal'
          ),

        redisRequestDurationHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Redis Request Duration',
            's',
            [
              {
                expr: queries.redisRequestDuration,
                legend: '{{ le }}',
              },
            ],
            description='Redis request latency distribution. High latencies indicate Redis performance issues that can affect controller scalability.',
          ),

        // Kubectl Exec Panels
        kubectlExecTotalTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Kubectl Exec Total',
            'short',
            queries.kubectlExecTotal,
            '{{ command }}',
            description='Total kubectl executions for manifest generation (Helm, Kustomize, plugins). High counts are expected during sync operations.',
            stack='normal'
          ),

        // Cluster Cache Panels
        clusterCacheAgeTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Cluster Cache Age',
            's',
            queries.clusterCacheAge,
            '{{ server }}',
            description='Age of the cluster cache in seconds. Stale caches (high values) can cause reconciliation delays and performance issues.',
            stack='none',
            fillOpacity=0
          ),

        // Resource Event Processing Panels
        resourceEventProcessingHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Resource Event Processing Duration',
            's',
            [
              {
                expr: queries.resourceEventProcessingDuration,
                legend: '{{ le }}',
              },
            ],
            description='Time to process resource events in batches. Controlled by ARGOCD_CLUSTER_CACHE_BATCH_EVENTS_PROCESSING and related settings.',
          ),

        resourceEventsBatchSizeTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Resource Events Batch Size',
            'short',
            queries.resourceEventsBatchSize,
            '{{ namespace }}/{{ job }}',
            description='Number of resource events processed per batch. Batch processing improves performance when managing large numbers of resources.',
            stack='normal'
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.clusterCountStat,
            panels.repositoryCountStat,
            panels.applicationCountStat,
          ],
          panelWidth=4,
          panelHeight=4,
          startY=1
        ) +
        grid.wrapPanels(
          [
            panels.healthStatusPieChart,
            panels.syncStatusPieChart,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=5
        ) +
        [
          panels.appsTablePanel +
          row.gridPos.withX(12) +
          row.gridPos.withY(1) +
          row.gridPos.withW(12) +
          row.gridPos.withH(10),
        ] +
        [
          row.new('Sync Stats') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.syncActivityTimeSeries,
            panels.syncFailuresTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=12
        ) +
        [
          row.new('Controller Stats') +
          row.gridPos.withX(0) +
          row.gridPos.withY(24) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.reconcilationActivtyTimeSeries,
                panels.reconcilationPerformanceHeatmap,
                panels.k8sApiActivityTimeSeries,
                panels.pendingKubectlTimeSeries,
                panels.kubectlExecTotalTimeSeries,
                panels.resourceEventProcessingHeatmap,
                panels.resourceEventsBatchSizeTimeSeries,
              ],
              panelWidth=24,
              panelHeight=6,
              startY=25
            )
          ),
        ] +
        [
          row.new('Cluster Stats') +
          row.gridPos.withX(0) +
          row.gridPos.withY(25) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.clusterConnectionStatusTimeSeries,
                panels.clusterCacheAgeTimeSeries,
                panels.resourceObjectsTimeSeries,
                panels.apiResourcesTimeSeries,
                panels.clusterEventsTimeSeries,
              ],
              panelWidth=24,
              panelHeight=6,
              startY=26
            )
          ),
        ] +
        [
          row.new('Repo Server Stats') +
          row.gridPos.withX(0) +
          row.gridPos.withY(26) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.pendingRepoRequestsTimeSeries,
                panels.gitFetchFailuresTimeSeries,
                panels.gitRequestsLsRemoteTimeSeries,
                panels.gitRequestsCheckoutTimeSeries,
                panels.gitFetchPerformanceHeatmap,
                panels.gitLsRemotePerformanceHeatmap,
              ],
              panelWidth=12,
              panelHeight=6,
              startY=27
            )
          ),
        ] +
        [
          row.new('Redis Performance') +
          row.gridPos.withX(0) +
          row.gridPos.withY(27) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.redisRequestRateTimeSeries,
                panels.redisRequestDurationHeatmap,
              ],
              panelWidth=24,
              panelHeight=6,
              startY=28
            )
          ),
        ];


      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Operational / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD with a focus on the operational side of ArgoCD. %s' % mixinUtils.dashboards.dashboardDescriptionLink('argo-cd-mixin', 'https://github.com/adinhodovic/argo-cd-mixin')) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('ArgoCD', $._config, dropdown=true)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
