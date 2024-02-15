local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local pieChartPanel = g.panel.pieChart;
local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;
local heatmapPanel = g.panel.heatmap;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

// Pie Chart
local pcOptions = pieChartPanel.options;
local pcStandardOptions = pieChartPanel.standardOptions;
local pcOverride = pcStandardOptions.override;
local pcLegend = pcOptions.legend;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

// Table
local tbOptions = tablePanel.options;
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

// HeatmapPanel
local hmStandardOptions = heatmapPanel.standardOptions;
local hmQueryOptions = heatmapPanel.queryOptions;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source'),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(argocd_app_info{}, namespace)'
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local jobVariable =
      query.new(
        'job',
        'label_values(job)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.withRegex('argo.*') +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true, '.*') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local clusterVariable =
      query.new(
        'cluster',
        'label_values(argocd_app_info{namespace=~"$namespace", job=~"$job"}, dest_server)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Cluster') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local projectVariable =
      query.new(
        'project',
        'label_values(argocd_app_info{namespace=~"$namespace", job=~"$job", dest_server=~"$cluster"}, project)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Project') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      namespaceVariable,
      jobVariable,
      clusterVariable,
      projectVariable,
    ],

    local commonLabels = |||
      namespace=~'$namespace',
      job=~'$job',
      dest_server=~'$cluster',
      project=~'$project',
    |||,

    local clustersCountQuery = |||
      sum(
        argocd_cluster_info{
          namespace=~'$namespace',
          job=~'$job'
        }
      )
    |||,

    local clustersCountStatPanel =
      statPanel.new(
        'Clusters',
      ) +
      statPanel.standardOptions.withUnit('short') +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          clustersCountQuery,
        )
      ),

    local repositoriesCountQuery = |||
      count(
        count(
          argocd_app_info{
            namespace=~'$namespace',
            job=~'$job'
          }
        )
        by (repo)
      )
    |||,

    local repositoriesCountStatPanel =
      statPanel.new(
        'Repositories',
      ) +
      statPanel.standardOptions.withUnit('short') +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          repositoriesCountQuery,
        )
      ),

    local appsCountQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      )
    ||| % commonLabels,

    local appsCountStatPanel =
      statPanel.new(
        'Applications',
      ) +
      statPanel.standardOptions.withUnit('short') +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appsCountQuery,
        )
      ),

    local healthStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (health_status)
    ||| % commonLabels,

    local healthStatusPieChartPanel =
      pieChartPanel.new(
        'Health Status',
      ) +
      pieChartPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          healthStatusQuery,
        ) +
        prometheus.withInstant(true) +
        prometheus.withLegendFormat(
          '{{ health_status }}'
        )
      ) +
      pcStandardOptions.withUnit('short') +
      pcOptions.tooltip.withMode('multi') +
      pcLegend.withShowLegend(true) +
      pcLegend.withDisplayMode('table') +
      pcLegend.withPlacement('right') +
      pcLegend.withValues(['value']) +
      pcStandardOptions.withOverrides([
        pcOverride.byName.new('Healthy') +
        pcOverride.byName.withPropertiesFromOptions(
          pcStandardOptions.color.withMode('fixed') +
          pcStandardOptions.color.withFixedColor('green')
        ),
        pcOverride.byName.new('Degraded') +
        pcOverride.byName.withPropertiesFromOptions(
          pcStandardOptions.color.withMode('fixed') +
          pcStandardOptions.color.withFixedColor('red')
        ),
        pcOverride.byName.new('Progressing') +
        pcOverride.byName.withPropertiesFromOptions(
          pcStandardOptions.color.withMode('fixed') +
          pcStandardOptions.color.withFixedColor('yellow')
        ),
      ]),

    local syncStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (sync_status)
    ||| % commonLabels,

    local syncStatusPieChartPanel =
      pieChartPanel.new(
        'Sync Status',
      ) +
      pieChartPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          syncStatusQuery,
        ) +
        prometheus.withInstant(true) +
        prometheus.withLegendFormat(
          '{{ sync_status }}'
        )
      ) +
      pcStandardOptions.withUnit('short') +
      pcOptions.tooltip.withMode('multi') +
      pcLegend.withShowLegend(true) +
      pcLegend.withDisplayMode('table') +
      pcLegend.withPlacement('right') +
      pcLegend.withValues(['value']) +
      pcStandardOptions.withOverrides([
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
      ]),

    local appsQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, name, health_status, sync_status)
    ||| % commonLabels,

    local appsTablePanel =
      tablePanel.new(
        'Applications',
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appsQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.transformation.withId(
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              job: 'Job',
              dest_server: 'Cluster',
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
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('name') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/argocd-notifications-overview?&var-project=${__data.fields.Project}&var-application=${__value.raw}' % $._config.applicationOverviewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local syncActivityQuery = |||
      sum(
        round(
          increase(
            argocd_app_sync_total{
              %s
            }[$__rate_interval]
          )
        )
      ) by (job, dest_server, project, name)
    ||| % commonLabels,

    local syncActivityTimeSeriesPanel =
      timeSeriesPanel.new(
        'Sync Activity',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          syncActivityQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }}/{{ name }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local syncFailuresQuery = |||
      sum(
        round(
          increase(
            argocd_app_sync_total{
              %s
              phase=~"Error|Failed"
            }[$__rate_interval]
          )
        )
      ) by (job, dest_server, project, application, phase)
    ||| % commonLabels,

    local syncFailuresTimeSeriesPanel =
      timeSeriesPanel.new(
        'Sync Failures',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          syncFailuresQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }}/{{ application }} - {{ phase }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local reconcilationActivityQuery = |||
      sum(
        round(
          increase(
            argocd_app_reconcile_count{
              namespace=~'$namespace',
              job=~'$job',
              dest_server=~'$cluster'
            }[$__rate_interval]
          )
        )
      ) by (namespace, job, dest_server)
    |||,

    local reconcilationActivtyTimeSeriesPanel =
      timeSeriesPanel.new(
        'Recociliation Activity',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          reconcilationActivityQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ namespace }}/{{ dest_server }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local reconcilationPerformanceQuery = |||
      sum(
        increase(
          argocd_app_reconcile_bucket{
            namespace=~'$namespace',
            job=~'$job',
            dest_server=~'$cluster'
          }[$__rate_interval]
        )
      ) by (le)
    |||,

    local reconcilationPerformanceHeatmapPanel =
      heatmapPanel.new(
        'Reconciliation Performance',
      ) +
      hmQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          reconcilationPerformanceQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ le }}'
        ) +
        prometheus.withFormat('heatmap')
      ) +
      hmStandardOptions.withUnit('short'),

    local k8sApiActivityQuery = |||
      sum(
        round(
          increase(
            argocd_app_k8s_request_total{
              namespace=~'$namespace',
              job=~'$job',
              project=~'$project'
            }[$__rate_interval]
          )
        )
      ) by (job, server, project, verb, resource_kind)
    |||,

    local k8sApiActivityTimeSeriesPanel =
      timeSeriesPanel.new(
        'K8s API Activity',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          k8sApiActivityQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ server }}/{{ project }} - {{ verb }}/{{ resource_kind }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local pendingKubectlRunQuery = |||
      sum(
        argocd_kubectl_exec_pending{
          namespace=~'$namespace',
          job=~'$job'
        }
      ) by (job, command)
    |||,

    local pendingKubectlTimeSeriesPanel =
      timeSeriesPanel.new(
        'Pending Kubectl Runs',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          pendingKubectlRunQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }} - {{ command }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local resourceObjectsQuery = |||
      sum(
        argocd_cluster_api_resource_objects{
          namespace=~'$namespace',
          job=~'$job',
          server=~'$cluster'
        }
      ) by (namespace, job, server)
    |||,

    local resourceObjectsTimeSeriesPanel =
      timeSeriesPanel.new(
        'Resource Objects',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          resourceObjectsQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ server }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local apiResourcesQuery = |||
      sum(
        argocd_cluster_api_resources{
          namespace=~'$namespace',
          job=~'$job',
          server=~'$cluster'
        }
      ) by (namespace, job, server)
    |||,

    local apiResourcesTimeSeriesPanel =
      timeSeriesPanel.new(
        'API Resources',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          apiResourcesQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ server }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local clusterEventsQuery = |||
      sum(
        increase(
          argocd_cluster_events_total{
            namespace=~'$namespace',
            job=~'$job',
            server=~'$cluster'
          }[$__rate_interval]
        )
      ) by (namespace, job, server)
    |||,

    local clusterEventsTimeSeriesPanel =
      timeSeriesPanel.new(
        'Cluster Events',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          clusterEventsQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ server }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local gitRequestsLsRemoteQuery = |||
      sum(
        increase(
          argocd_git_request_total{
            namespace=~'$namespace',
            job=~'$job',
            request_type="ls-remote"
          }[$__rate_interval]
        )
      ) by (namespace, job, repo)
    |||,

    local gitRequestsLsRemoteTimeSeriesPanel =
      timeSeriesPanel.new(
        'Git Requests (ls-remote)',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          gitRequestsLsRemoteQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ namespace }} - {{ repo }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local gitRequestsCheckoutQuery = |||
      sum(
        increase(
          argocd_git_request_total{
            namespace=~'$namespace',
            job=~'$job',
            request_type="fetch"
          }[$__rate_interval]
        )
      ) by (namespace, job, repo)
    |||,

    local gitRequestsCheckoutTimeSeriesPanel =
      timeSeriesPanel.new(
        'Git Requests (checkout)',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          gitRequestsCheckoutQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ namespace }} - {{ repo }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local gitFetchPerformanceQuery = |||
      sum(
        increase(
          argocd_git_request_duration_seconds_bucket{
            namespace=~'$namespace',
            job=~'$job',
            request_type="fetch"
          }[$__rate_interval]
        )
      ) by (le)
    |||,

    local gitFetchPerformanceHeatmapPanel =
      heatmapPanel.new(
        'Git Fetch Performance',
      ) +
      hmQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          gitFetchPerformanceQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ le }}'
        ) +
        prometheus.withFormat('heatmap')
      ) +
      hmStandardOptions.withUnit('short'),

    local gitLsRemotePerformanceQuery = |||
      sum(
        increase(
          argocd_git_request_duration_seconds_bucket{
            namespace=~'$namespace',
            job=~'$job',
            request_type="ls-remote"
          }[$__rate_interval]
        )
      ) by (le)
    |||,

    local gitLsRemotePerformanceHeatmapPanel =
      heatmapPanel.new(
        'Git Ls-remote Performance',
      ) +
      hmQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          gitLsRemotePerformanceQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ le }}'
        ) +
        prometheus.withFormat('heatmap')
      ) +
      hmStandardOptions.withUnit('short'),

    local summaryRow =
      row.new(
        'Summary'
      ),

    local syncStatsRow =
      row.new(
        'Sync Stats'
      ),

    local controllerStatsRow =
      row.new(
        'Controller Stats'
      ),

    local clusterStatsRow =
      row.new(
        'Cluster Stats'
      ),

    local repoServerStatsRow =
      row.new(
        'Repo Server Stats',
      ),

    'argo-cd-operational-overview.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Operational / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD with a focus on the operational. It is created using the [argo-cd-mixin](https://github.com/adinhodovic/argo-cd-mixin).') +
      dashboard.withUid($._config.operationalOverviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('ArgoCD Dashboards', $._config.tags) +
          dashboard.link.link.options.withTargetBlank(true),
        ]
      ) +
      dashboard.withPanels(
        [
          summaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          clustersCountStatPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(4) +
          tablePanel.gridPos.withH(4),
          repositoriesCountStatPanel +
          tablePanel.gridPos.withX(4) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(4) +
          tablePanel.gridPos.withH(4),
          appsCountStatPanel +
          tablePanel.gridPos.withX(8) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(4) +
          tablePanel.gridPos.withH(4),
          healthStatusPieChartPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(5) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(6),
          syncStatusPieChartPanel +
          tablePanel.gridPos.withX(6) +
          tablePanel.gridPos.withY(5) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(6),
          appsTablePanel +
          tablePanel.gridPos.withX(12) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(12) +
          tablePanel.gridPos.withH(10),
        ] +
        [
          syncStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [syncActivityTimeSeriesPanel, syncFailuresTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=12
        ) +
        [
          controllerStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(18) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            reconcilationActivtyTimeSeriesPanel,
            reconcilationPerformanceHeatmapPanel,
            k8sApiActivityTimeSeriesPanel,
            pendingKubectlTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=19
        ) +
        [
          clusterStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(31) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [resourceObjectsTimeSeriesPanel, apiResourcesTimeSeriesPanel, clusterEventsTimeSeriesPanel],
          panelWidth=8,
          panelHeight=6,
          startY=32
        ) +
        [
          repoServerStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(38) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            gitRequestsLsRemoteTimeSeriesPanel,
            gitRequestsCheckoutTimeSeriesPanel,
            gitFetchPerformanceHeatmapPanel,
            gitLsRemotePerformanceHeatmapPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=39
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
