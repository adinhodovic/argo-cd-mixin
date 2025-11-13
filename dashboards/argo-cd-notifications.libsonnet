local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  local dashboardName = 'argo-cd-notifications-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.jobNotifications,
        defaultVariables.notificationsExportedService,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        deliveriesCount: |||
          sum(
            increase(
              argocd_notifications_deliveries_total{
                %(withNotifications)s
              }[$__rate_interval]
            )
          ) by (exported_service, succeeded)
        ||| % defaultFilters,

        triggerEvalCount: |||
          sum(
            increase(
              argocd_notifications_trigger_eval_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (name, triggered)
        ||| % defaultFilters,
      };


      local panels = {
        deliveriesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Notification Deliveries',
            'short',
            queries.deliveriesCount,
            '{{ exported_service }} - Succeeded: {{ succeeded }}',
            description='A timeseries panel showing the count of notification deliveries by exported service and success status.',
            stack='normal'
          ),

        triggerEvalTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Trigger Evaluations',
            'short',
            queries.triggerEvalCount,
            '{{ name }} - Triggered: {{ triggered }}',
            description='A timeseries panel showing the count of trigger evaluations by name and triggered status.',
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
            panels.deliveriesTimeSeries,
            panels.triggerEvalTimeSeries,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=1
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Notifications / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD with a focus on the notifications. %s' % mixinUtils.dashboards.dashboardDescriptionLink('argo-cd-mixin', 'https://github.com/adinhodovic/argo-cd-mixin')) +
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
