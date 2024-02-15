local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local timeSeriesPanel = g.panel.timeSeries;

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
        'label_values(argocd_notifications_deliveries_total{}, namespace)'
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
        'label_values(argocd_notifications_deliveries_total{namespace=~"$namespace"}, job)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true, '.*') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local exportedServiceVariable =
      query.new(
        'exported_service',
        'label_values(argocd_notifications_deliveries_total{namespace=~"$namespace", job=~"$job"}, exported_service)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Notifications Service') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      namespaceVariable,
      jobVariable,
      exportedServiceVariable,
    ],

    local commonLabels = |||
      namespace=~'$namespace',
      job=~'$job',
    |||,

    local deliveriesQuery = |||
      sum(
        round(
          increase(
            argocd_notifications_deliveries_total{
              %s
              exported_service=~"$exported_service",
            }[$__rate_interval]
          )
        )
      ) by (job, exported_service, succeeded)
    ||| % commonLabels,

    local deliveriesTimeSeriesPanel =
      timeSeriesPanel.new(
        'Notification Deliveries',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          deliveriesQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ exported_service }} - Succeeded: {{ succeeded }}'
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

    local triggerEvalQuery = |||
      sum(
        round(
          increase(
            argocd_notifications_trigger_eval_total{
              %s
            }[$__rate_interval]
          )
        )
      ) by (job, name, triggered)
    ||| % commonLabels,

    local triggerEvalTimeSeriesPanel =
      timeSeriesPanel.new(
        'Trigger Evaluations',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          triggerEvalQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ name }} - Triggered: {{ triggered }}',
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

    local summaryRow =
      row.new(
        title='Summary'
      ),

    'argo-cd-notifications-overview.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Notifications / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD notifications. It is created using the [argo-cd-mixin](https://github.com/adinhodovic/argo-cd-mixin).') +
      dashboard.withUid($._config.notificationsOverviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-2d') +
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
        ] +
        grid.makeGrid(
          [
            deliveriesTimeSeriesPanel,
            triggerEvalTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=1
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
