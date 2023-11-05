local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;

{
  grafanaDashboards+:: {

    local prometheusTemplate =
      template.datasource(
        'datasource',
        'prometheus',
        'Prometheus',
        label='Data Source',
        hide='',
      ),

    local namespaceTemplate =
      template.new(
        name='namespace',
        label='Namespace',
        datasource='$datasource',
        query='label_values(argocd_notifications_deliveries_total{}, namespace)',
        current='',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local jobTemplate =
      template.new(
        name='job',
        label='Job',
        datasource='$datasource',
        query='label_values(argocd_notifications_deliveries_total{namespace=~"$namespace"}, job)',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local exportedServiceTemplate =
      template.new(
        name='exported_service',
        label='Notifications Service',
        datasource='$datasource',
        query='label_values(argocd_notifications_deliveries_total{namespace=~"$namespace", job=~"$job"}, exported_service)',
        current='',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local templates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
      exportedServiceTemplate,
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
              exported_service =~"$exported_service",
            }[$__rate_interval]
          )
        )
      ) by (job, exported_service, succeeded)
    ||| % commonLabels,
    local deliveriesGraphPanel =
      graphPanel.new(
        'Notification Deliveries',
        datasource='$datasource',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_current=true,
        legend_max=true,
        legend_sort='current',
        legend_sortDesc=true,
        nullPointMode='null as zero',
        fill=1,
      )
      .addTarget(
        prometheus.target(
          deliveriesQuery,
          legendFormat='{{ exported_service }} - Succeeded: {{ succeeded }}',
        )
      ),

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
    local triggerEvalGraphPanel =
      graphPanel.new(
        'Trigger Evaluations',
        datasource='$datasource',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_current=true,
        legend_max=true,
        legend_sort='current',
        legend_sortDesc=true,
        nullPointMode='null as zero',
        fill=1,
      )
      .addTarget(
        prometheus.target(
          triggerEvalQuery,
          legendFormat='{{ name }} - Triggered: {{ triggered }}',
        )
      ),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    'argo-cd-notifications-overview.json':
      dashboard.new(
        'ArgoCD / Notifications / Overview',
        description='A dashboard that monitors ArgoCD notifications. It is created using the [argo-cd-mixin](https://github.com/adinhodovic/argo-cd-mixin).',
        uid=$._config.notificationsOverviewDashboardUid,
        tags=$._config.tags,
        time_from='now-2d',
        editable=false,
        time_to='now',
        timezone='utc'
      )
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(deliveriesGraphPanel, gridPos={ h: 8, w: 12, x: 0, y: 1 })
      .addPanel(triggerEvalGraphPanel, gridPos={ h: 8, w: 12, x: 12, y: 1 })

      +
      { templating+: { list+: templates } } +
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
