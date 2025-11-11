local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

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
            increase(
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
              %(withProject)s
            }
          ) by (namespace, job, server)
        ||| % defaultFilters,

        apiResources: |||
          sum(
            argocd_cluster_api_resources{
              %(default)s
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
            increase(
              argocd_git_request_duration_seconds_bucket{
                %(default)s,
                request_type="ls-remote"
              }[$__rate_interval]
            )
          ) by (le)
        ||| % defaultFilters,

        gitFetchPerformance: |||
          sum(
            increase(
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
                %(default)s
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
          ),

        syncStatusPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Sync Status',
            'short',
            queries.syncStatusQuery,
            '{{ sync_status }}',
            description='The distribution of application sync statuses managed by ArgoCD.',
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
            ],
            overrides=[
              tbOverride.byName.new('name') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To Application') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    '/d/%s/argocd-notifications-overview?&var-project=${__data.fields.Project}&var-application=${__value.raw}' % $._config.dashboardIds['argocd-notifications-overview']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ],
          ),

        syncActivityTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Sync Activity',
            'short',
            queries.syncActivity,
            '{{ project }}/{{ name }}',
            description='A timeseries panel showing sync activity for applications managed by ArgoCD.',
          ),

        syncFailuresTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Sync Failures',
            'short',
            queries.syncFailures,
            '{{ project }}/{{ name }} - {{ phase }}',
            description='A timeseries panel showing sync failures for applications managed by ArgoCD.',
          ),

        reconcilationActivtyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Reconciliation Activity',
            'short',
            queries.reconcilationActivity,
            '{{ namespace }}/{{ job }}',
            description='A timeseries panel showing reconciliation activity for applications managed by ArgoCD.',
          ),

        reconcilationPerformanceHeatmap:
          mixinUtils.dashboards.heatmapPanel(
            'Reconciliation Performance',
            'short',
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
          ),

        pendingKubectlTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pending Kubectl Runs',
            'short',
            queries.pendingKubectlRun,
            '{{ command }}',
            description='A timeseries panel showing pending kubectl runs for ArgoCD.',
          ),

        resourceObjectsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Resource Objects',
            'short',
            queries.resourceObjects,
            '{{ server }}',
            description='A timeseries panel showing the number of resource objects in each cluster managed by ArgoCD.',
          ),

        apiResourcesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'API Resources',
            'short',
            queries.apiResources,
            '{{ server }}',
            description='A timeseries panel showing the number of API resources in each cluster managed by ArgoCD.',
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
            'short',
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
            'short',
            [
              {
                expr: queries.gitFetchPerformance,
                legend: '{{ le }}',
              },
            ],
            description='A heatmap panel showing git fetch performance for ArgoCD.',
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
            panels.healthStatusPieChart,
            panels.syncStatusPieChart,
            panels.appsTablePanel,
          ],
          panelWidth=24,
          panelHeight=10,
          startY=1
        ) +
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
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.reconcilationActivtyTimeSeries,
                panels.reconcilationPerformanceHeatmap,
                panels.k8sApiActivityTimeSeries,
                panels.pendingKubectlTimeSeries,
              ],
              panelWidth=24,
              panelHeight=6,
              startY=25
            )
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(24) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        [
          row.new('Cluster Stats') +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.resourceObjectsTimeSeries,
                panels.apiResourcesTimeSeries,
                panels.clusterEventsTimeSeries,
              ],
              panelWidth=24,
              panelHeight=6,
              startY=50
            )
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(49) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        [
          row.new('Repo Server Stats') +
          row.withCollapsed(true) +
          row.withPanels(
            grid.makeGrid(
              [
                panels.gitRequestsLsRemoteTimeSeries,
                panels.gitRequestsCheckoutTimeSeries,
                panels.gitFetchPerformanceHeatmap,
                panels.gitLsRemotePerformanceHeatmap,
              ],
              panelWidth=12,
              panelHeight=6,
              startY=69
            )
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(68) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
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
        mixinUtils.dashboards.dashboardLinks('ArgoCD', $._config)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
