local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local timeSeries = g.panel.timeSeries;
local textPanel = g.panel.text;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

// Timeseries
local tsOptions = timeSeries.options;
local tsStandardOptions = timeSeries.standardOptions;
local tsQueryOptions = timeSeries.queryOptions;
local tsFieldConfig = timeSeries.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'Prometheus',
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
    // query='label_values(argocd_app_info{}, namespace)',
    // current='',
    // hide='',
    // refresh=2,
    // sort=1

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

    local templates = [
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

    local appHealthStatusGraphPanel =
      timeSeries.new(
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

    local appSyncStatusGraphPanel =
      timeSeries.new(
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

    local appSyncGraphPanel =
      timeSeries.new(
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

    local appAutoSyncStatusGraphPanel =
      timeSeries.new(
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

    local standardOptions = tablePanel.standardOptions,
    local panelOptions = tablePanel.panelOptions,
    local queryOptions = tablePanel.queryOptions,
    local override = standardOptions.override,
    local custom = tablePanel.fieldConfig.defaults.custom,
    local appUnhealthyTable =
      tablePanel.new(
        'Applications Unhealthy',
      ) +
      tablePanel.options.withSortBy(2) +
      tablePanel.options.sortBy.withDesc(true) +
      tablePanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appUnhealthyQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tablePanel.queryOptions.withTransformations([
        queryOptions.transformation.withId(
          'organize'
        ) +
        queryOptions.transformation.withOptions(
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
      tablePanel.standardOptions.withOverrides([
        override.byName.new('name') +
        override.byName.withPropertiesFromOptions(
          standardOptions.withLinks(
            panelOptions.link.withTitle('Go To Application') +
            panelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        override.byName.new('health_status') +
        override.byName.withPropertiesFromOptions(
          standardOptions.color.withMode('fixed') +
          standardOptions.color.withFixedColor('yellow') +
          custom.withDisplayMode('color-background')
        ),
      ]),

    local appOutOfSyncQuery = |||
      sum(
        argocd_app_info{
          %s
          sync_status!="Synced"
        }
      ) by (job, dest_server, project, name, sync_status) == 1
    ||| % commonLabels,

    local appOutOfSyncTable =
      tablePanel.new(
        'Applications Out Of Sync',
      ) +
      tablePanel.options.withSortBy(2) +
      tablePanel.options.sortBy.withDesc(true) +
      tablePanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appOutOfSyncQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tablePanel.queryOptions.withTransformations([
        queryOptions.transformation.withId(
          'organize'
        ) +
        queryOptions.transformation.withOptions(
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
      tablePanel.standardOptions.withOverrides([
        override.byName.new('name') +
        override.byName.withPropertiesFromOptions(
          standardOptions.withLinks(
            panelOptions.link.withTitle('Go To Application') +
            panelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        override.byName.new('sync_status') +
        override.byName.withPropertiesFromOptions(
          standardOptions.color.withMode('fixed') +
          standardOptions.color.withFixedColor('yellow') +
          custom.withDisplayMode('color-background')
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
      ) by (job, dest_server, project, name, phase) == 1
    ||| % commonLabels,

    local appSync7dTable =
      tablePanel.new(
        'Applications That Failed to Sync[7d]',
      ) +
      tablePanel.options.withSortBy(2) +
      tablePanel.options.sortBy.withDesc(true) +
      tablePanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appSync7dQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tablePanel.queryOptions.withTransformations([
        queryOptions.transformation.withId(
          'organize'
        ) +
        queryOptions.transformation.withOptions(
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
      tablePanel.standardOptions.withOverrides([
        override.byName.new('name') +
        override.byName.withPropertiesFromOptions(
          standardOptions.withLinks(
            panelOptions.link.withTitle('Go To Application') +
            panelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        override.byName.new('Value') +
        override.byName.withPropertiesFromOptions(
          standardOptions.color.withMode('fixed') +
          standardOptions.color.withFixedColor('yellow') +
          custom.withDisplayMode('color-background')
        ),
      ]),

    local appAutoSyncDisabledQuery = |||
      sum(
        argocd_app_info{
          %s
          autosync_enabled!="true"
        }
      ) by (job, dest_server, project, name, autosync_enabled) == 1
    ||| % commonLabels,

    local appAutoSyncDisabledTable =
      tablePanel.new(
        'Applications With Auto Sync Disabled',
      ) +
      tablePanel.options.withSortBy(2) +
      tablePanel.options.sortBy.withDesc(true) +
      tablePanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          appAutoSyncDisabledQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tablePanel.queryOptions.withTransformations([
        queryOptions.transformation.withId(
          'organize'
        ) +
        queryOptions.transformation.withOptions(
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
      tablePanel.standardOptions.withOverrides([
        override.byName.new('name') +
        override.byName.withPropertiesFromOptions(
          standardOptions.withLinks(
            panelOptions.link.withTitle('Go To Application') +
            panelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Project}/${__value.raw}'
            )
          )
        ),
        override.byName.new('autosync_enabled') +
        override.byName.withPropertiesFromOptions(
          standardOptions.color.withMode('fixed') +
          standardOptions.color.withFixedColor('yellow') +
          custom.withDisplayMode('color-background')
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

    local appHealthStatusByAppGraphPanel =
      timeSeries.new(
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

    local appSyncStatusByAppGraphPanel =
      timeSeries.new(
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

    local appSyncByAppGraphPanel =
      timeSeries.new(
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
      dashboard.new(
        'ArgoCD / Application / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache). It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).') +
      dashboard.withUid($._config.applicationOverviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(templates) +
      dashboard.withPanels(
        [
          summaryRow,
          appHealthStatusGraphPanel +
          timeSeries.gridPos.withX(0) +
          timeSeries.gridPos.withY(1) +
          timeSeries.gridPos.withW(9) +
          timeSeries.gridPos.withH(5),
          appSyncStatusGraphPanel +
          timeSeries.gridPos.withX(9) +
          timeSeries.gridPos.withY(1) +
          timeSeries.gridPos.withW(9) +
          timeSeries.gridPos.withH(5),
          appSyncGraphPanel +
          timeSeries.gridPos.withX(0) +
          timeSeries.gridPos.withY(6) +
          timeSeries.gridPos.withW(9) +
          timeSeries.gridPos.withH(5),
          appAutoSyncStatusGraphPanel +
          timeSeries.gridPos.withX(9) +
          timeSeries.gridPos.withY(6) +
          timeSeries.gridPos.withW(9) +
          timeSeries.gridPos.withH(5),
          appBadgeTextPanel +
          textPanel.gridPos.withX(18) +
          textPanel.gridPos.withY(1) +
          textPanel.gridPos.withW(6) +
          textPanel.gridPos.withH(10),
          appSummaryRow +
          timeSeries.gridPos.withX(0) +
          timeSeries.gridPos.withY(11) +
          timeSeries.gridPos.withW(18) +
          timeSeries.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            appUnhealthyTable,
            appOutOfSyncTable,
            appSync7dTable,
            appAutoSyncDisabledTable,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=12
        ) +
        [
          appRow +
          timeSeries.gridPos.withX(0) +
          timeSeries.gridPos.withY(23) +
          timeSeries.gridPos.withW(24) +
          timeSeries.gridPos.withH(1),
        ]
        +
        grid.makeGrid(
          [
            appHealthStatusByAppGraphPanel,
            appSyncStatusByAppGraphPanel,
            appSyncByAppGraphPanel,
          ],
          panelWidth=8,
          panelHeight=8,
          startY=24
        )
      )
      +
      if $._config.annotation.enabled then
        {
          annotations: {
            list: [
              $._config.customAnnotation,
            ],
          },
        }
      else {},
  },
}
