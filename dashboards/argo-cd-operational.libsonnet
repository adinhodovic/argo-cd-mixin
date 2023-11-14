local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;
local heatmapPanel = g.panel.heatmap;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

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
local tbPanelOptions = tablePanel.panelOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbFieldConfig = tablePanel.fieldConfig;
local tbCustom = tbFieldConfig.defaults.custom;
local tbOverride = tbStandardOptions.override;

// HeatmapPanel
local hmOptions = heatmapPanel.options;
local hmStandardOptions = heatmapPanel.standardOptions;
local tbPanelOptions = tablePanel.panelOptions;
local hmQueryOptions = heatmapPanel.queryOptions;
local tbFieldConfig = tablePanel.fieldConfig;
local tbCustom = tbFieldConfig.defaults.custom;
local tbOverride = tbStandardOptions.override;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data Source'),

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
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appsCountQuery,
        )
      ),

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
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
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
            )
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

    local appsDefined = std.length($._config.applications) != 0,
    local appBadgeContent = [
      '| %(name)s | %(environment)s | [![App Status](%(baseUrl)s/api/badge?name=%(applicationName)s&revision=true)](%(baseUrl)s/applications/%(applicationName)s) |' % application {
        baseUrl: if std.objectHas(application, 'baseUrl') then application.baseUrl else $._config.argoCdUrl,
        applicationName: if std.objectHas(application, 'applicationName') then application.applicationName else application.name,
      }
      for application in $._config.applications
    ],

    local appUnhealthyQuery = |||
      sum(
        argocd_app_info{
          %s
          health_status!~"Healthy|Progressing"
        }
      ) by (job, dest_server, project, name, health_status)
    ||| % commonLabels,

    local appUnhealthyTablePanel =
      tablePanel.new(
        'Applications Unhealthy',
      ) +
      tbOptions.withSortBy(2) +
      tbOptions.sortBy.withDesc(true) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appUnhealthyQuery,
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
              health_status: 'Sync Status',
            },
            indexByName: {
              name: 0,
              project: 1,
              health_status: 2,
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
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        tbOverride.byName.new('health_status') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbCustom.withDisplayMode('color-background')
        ),
      ]),

    local appOutOfSyncQuery = |||
      sum(
        argocd_app_info{
          %s
          sync_status!="Synced"
        }
      ) by (job, dest_server, project, name, sync_status) > 0
    ||| % commonLabels,

    local appOutOfSyncTablePanel =
      tablePanel.new(
        'Applications Out Of Sync',
      ) +
      tbOptions.withSortBy(2) +
      tbOptions.sortBy.withDesc(true) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appOutOfSyncQuery,
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
              sync_status: 'Sync Status',
            },
            indexByName: {
              name: 0,
              project: 1,
              sync_status: 2,
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
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        tbOverride.byName.new('sync_status') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbCustom.withDisplayMode('color-background')
        ),
      ]),

    local appSync7dQuery = |||
      sum(
        round(
          increase(
            argocd_app_sync_total{
              %s
              phase!="Succeeded"
            }[7d]
          )
        )
      ) by (job, dest_server, project, name, phase) > 0
    ||| % commonLabels,

    local appSync7dTablePanel =
      tablePanel.new(
        'Applications That Failed to Sync[7d]',
      ) +
      tbOptions.withSortBy(2) +
      tbOptions.sortBy.withDesc(true) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSync7dQuery,
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
              phase: 'Phase',
              Value: 'Count',
            },
            indexByName: {
              name: 0,
              project: 1,
              phase: 2,
            },
            excludeByName: {
              Time: true,
              job: true,
              dest_server: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('name') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        tbOverride.byName.new('Value') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbCustom.withDisplayMode('color-background')
        ),
      ]),

    local appAutoSyncDisabledQuery = |||
      sum(
        argocd_app_info{
          %s
          autosync_enabled!="true"
        }
      ) by (job, dest_server, project, name, autosync_enabled) > 0
    ||| % commonLabels,

    local appAutoSyncDisabledTablePanel =
      tablePanel.new(
        'Applications With Auto Sync Disabled',
      ) +
      tbOptions.withSortBy(2) +
      tbOptions.sortBy.withDesc(true) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appAutoSyncDisabledQuery,
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
              autosync_enabled: 'Auto Sync Enabled',
            },
            indexByName: {
              name: 0,
              project: 1,
              autosync_enabled: 2,
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
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        tbOverride.byName.new('autosync_enabled') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbCustom.withDisplayMode('color-background')
        ),
      ]),

    local appHealthStatusByAppQuery = |||
      sum(
        argocd_app_info{
          %s
          name=~"$application",
        }
      ) by (namespace, job, dest_server, project, name, health_status)
    ||| % commonLabels,

    local appHealthStatusByAppTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Health Status',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appHealthStatusByAppQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }}/{{ name }} - {{ health_status }}'
        )
      ) +
      tsQueryOptions.withInterval('5m') +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appSyncStatusByAppQuery = |||
      sum(
        argocd_app_info{
          %s
          name=~"$application",
        }
      ) by (namespace, job, dest_server, project, name, sync_status)
    ||| % commonLabels,

    local appSyncStatusByAppTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Sync Status',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSyncStatusByAppQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }}/{{ name }} - {{ sync_status }}'
        )
      ) +
      tsQueryOptions.withInterval('5m') +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appSyncByAppQuery = |||
      sum(
        round(
          increase(
            argocd_app_sync_total{
              %s
              name=~"$application",
            }[$__rate_interval]
          )
        )
      ) by (namespace, job, dest_server, project, name, phase)
    ||| % commonLabels,

    local appSyncByAppTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Sync Result',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSyncByAppQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }}/{{ name }} - {{ phase }}'
        )
      ) +
      tsQueryOptions.withInterval('5m') +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withCalcs(['last']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

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
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(4),
          repositoriesCountStatPanel +
          tablePanel.gridPos.withX(6) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(4),
          appsCountStatPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(5) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(4),
          appsTablePanel +
          tablePanel.gridPos.withX(12) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(12) +
          tablePanel.gridPos.withH(8),
        ] +
        [
          syncStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(9) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [syncActivityTimeSeriesPanel, syncFailuresTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=10
        ) +
        [
          controllerStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(16) +
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
          startY=17
        ) +
        [
          clusterStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(29) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [resourceObjectsTimeSeriesPanel, apiResourcesTimeSeriesPanel, clusterEventsTimeSeriesPanel],
          panelWidth=8,
          panelHeight=6,
          startY=30
        ) +
        [
          repoServerStatsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(36) +
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
          startY=37
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
