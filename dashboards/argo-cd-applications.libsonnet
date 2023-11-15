local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;
local textPanel = g.panel.text;

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
        'label_values(argocd_app_info{namespace=~"$namespace"}, job)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
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

    local applicationVariable =
      query.new(
        'application',
        'label_values(argocd_app_info{namespace=~"$namespace", job=~"$job", dest_server=~"$cluster", project=~"$project"}, name)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Application') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      namespaceVariable,
      jobVariable,
      clusterVariable,
      projectVariable,
      applicationVariable,
    ],

    local commonLabels = |||
      namespace=~'$namespace',
      job=~'$job',
      dest_server=~'$cluster',
      project=~'$project',
    |||,

    local appHealthStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, health_status)
    ||| % commonLabels,

    local appHealthStatusTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Health Status',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appHealthStatusQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }} - {{ health_status }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last', 'max']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appSyncStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, sync_status)
    ||| % commonLabels,

    local appSyncStatusTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Sync Status',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSyncStatusQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }} - {{ sync_status }}',
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last', 'max']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appSyncQuery = |||
      sum(
        round(
          increase(
            argocd_app_sync_total{
              %s
            }[$__rate_interval]
          )
        )
      ) by (job, dest_server, project, phase)
    ||| % commonLabels,

    local appSyncTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Syncs',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSyncQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }} - {{ phase }}',
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last', 'max']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appAutoSyncStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, autosync_enabled)
    ||| % commonLabels,

    local appAutoSyncStatusTimeSeriesPanel =
      timeSeriesPanel.new(
        'Application Auto Sync Enabled',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appAutoSyncStatusQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ dest_server }}/{{ project }} - {{ autosync_enabled }}',
        )
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['last', 'max']) +
      tsLegend.withSortBy('Last') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10),

    local appsDefined = std.length($._config.applications) != 0,
    local appBadgeContent = [
      '| %(name)s | %(environment)s | [![App Status](%(baseUrl)s/api/badge?name=%(applicationName)s&revision=true)](%(baseUrl)s/applications/%(applicationName)s) |' % application {
        baseUrl: if std.objectHas(application, 'baseUrl') then application.baseUrl else $._config.argoCdUrl,
        applicationName: if std.objectHas(application, 'applicationName') then application.applicationName else application.name,
      }
      for application in $._config.applications
    ],
    local appBadgeTextPanel =
      textPanel.new(
        'Application Badges',
      ) +
      textPanel.options.withMode('markdown') +
      textPanel.options.withContent(
        if appsDefined then |||
          | Application | Environment | Status |
          | --- | --- | --- |
          %s
        ||| % std.join('\n', appBadgeContent) else 'No applications defined',
      ),

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
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
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
              health_status: 'Health Status',
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
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
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
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
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
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Application')
      ) +
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
        'Summary by Cluster, Project'
      ),

    local appSummaryRow =
      row.new(
        'Applications (Unhealthy/OutOfSync/AutoSyncDisabled) Summary',
      ),

    local appRow =
      row.new(
        'Application ($application)',
      ),

    'argo-cd-application-overview.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Application / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD with a focus on Application status. It is created using the [argo-cd-mixin](https://github.com/adinhodovic/argo-cd-mixin). Requires custom configuration to add application badges. Please refer to the mixin.') +
      dashboard.withUid($._config.applicationOverviewDashboardUid) +
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
          appHealthStatusTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(1) +
          timeSeriesPanel.gridPos.withW(9) +
          timeSeriesPanel.gridPos.withH(5),
          appSyncStatusTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(9) +
          timeSeriesPanel.gridPos.withY(1) +
          timeSeriesPanel.gridPos.withW(9) +
          timeSeriesPanel.gridPos.withH(5),
          appSyncTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(6) +
          timeSeriesPanel.gridPos.withW(9) +
          timeSeriesPanel.gridPos.withH(5),
          appAutoSyncStatusTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(9) +
          timeSeriesPanel.gridPos.withY(6) +
          timeSeriesPanel.gridPos.withW(9) +
          timeSeriesPanel.gridPos.withH(5),
          appBadgeTextPanel +
          textPanel.gridPos.withX(18) +
          textPanel.gridPos.withY(1) +
          textPanel.gridPos.withW(6) +
          textPanel.gridPos.withH(10),
          appSummaryRow +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(11) +
          timeSeriesPanel.gridPos.withW(18) +
          timeSeriesPanel.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            appUnhealthyTablePanel,
            appOutOfSyncTablePanel,
            appSync7dTablePanel,
            appAutoSyncDisabledTablePanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=12
        ) +
        [
          appRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(23) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ]
        +
        grid.makeGrid(
          [
            appHealthStatusByAppTimeSeriesPanel,
            appSyncStatusByAppTimeSeriesPanel,
            appSyncByAppTimeSeriesPanel,
          ],
          panelWidth=8,
          panelHeight=8,
          startY=24
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
