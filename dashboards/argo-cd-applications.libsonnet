local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local tablePanel = g.panel.table;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;
local textPanel = grafana.text;

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
        query='label_values(argocd_app_info{}, namespace)',
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
        query='label_values(argocd_app_info{namespace=~"$namespace"}, job)',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local clusterTemplate =
      template.new(
        name='cluster',
        label='Cluster',
        datasource='$datasource',
        query='label_values(argocd_app_info{namespace=~"$namespace", job=~"$job"}, dest_server)',
        current='',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local projectTemplate =
      template.new(
        name='project',
        label='Project',
        datasource='$datasource',
        query='label_values(argocd_app_info{namespace=~"$namespace", job=~"$job", dest_server=~"$cluster"}, project)',
        current='',
        hide='',
        refresh=2,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local applicationTemplate =
      template.new(
        name='application',
        label='Application',
        datasource='$datasource',
        query='label_values(argocd_app_info{namespace=~"$namespace", job=~"$job", dest_server=~"$cluster", project=~"$project"}, name)',
        current='',
        hide='',
        refresh=2,
        multi=true,
        includeAll=false,
        sort=1
      ),

    local templates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
      clusterTemplate,
      projectTemplate,
      applicationTemplate,
    ],

    local commonLabels = |||
      namespace=~'$namespace',
      job=~'$job',
      dest_server=~'$cluster',
      project=~'$project',
    |||,

    local appQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project)
    ||| % commonLabels,

    local appStatPanel =
      statPanel.new(
        'Applications',
        datasource='$datasource',
        unit='short',
        reducerFunction='lastNotNull',
      )
      .addTarget(
        prometheus.target(
          appQuery,
          legendFormat='{{ dest_server }}/{{ project }}',
        )
      )
      .addThresholds([
        { color: 'yellow', value: 0 },
        { color: 'green', value: 0.1 },
      ]),

    local appHealthStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, health_status)
    ||| % commonLabels,

    local appHealthStatusGraphPanel =
      graphPanel.new(
        'Application Health Status',
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
          appHealthStatusQuery,
          legendFormat='{{ dest_server }}/{{ project }} - {{ health_status }}',
        )
      ),

    local appSyncStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, sync_status)
    ||| % commonLabels,

    local appSyncStatusGraphPanel =
      graphPanel.new(
        'Application Sync Status',
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
          appSyncStatusQuery,
          legendFormat='{{ dest_server }}/{{ project }} - {{ sync_status }}',
        )
      ),

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
      graphPanel.new(
        'Application Syncs',
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
          appSyncQuery,
          legendFormat='{{ dest_server }}/{{ project }} - {{ phase }}',
        )
      ),

    local appAutoSyncStatusQuery = |||
      sum(
        argocd_app_info{
          %s
        }
      ) by (job, dest_server, project, autosync_enabled)
    ||| % commonLabels,

    local appAutoSyncStatusGraphPanel =
      graphPanel.new(
        'Application Auto Sync Enabled',
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
          appAutoSyncStatusQuery,
          legendFormat='{{ dest_server }}/{{ project }} - {{ autosync_enabled }}',
        )
      ),

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
        content=if appsDefined then |||
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

    local appUnhealthyTable =
      grafana.tablePanel.new(
        'Applications Unhealthy',
        datasource='$datasource',
        sort={
          col: 2,
          desc: true,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Health Status',
            pattern: 'health_status',
            type: 'string',
            colorMode: 'value',
            colors: [
              'null',
              'orange',
            ],
            thresholds: [
              0.1,
            ],
          },
          {
            alias: 'Job',
            pattern: 'job',
            type: 'hidden',
          },
          {
            alias: 'Cluster',
            pattern: 'dest_server',
            type: 'hidden',
          },
          {
            alias: 'Project',
            pattern: 'project',
          },
          {
            alias: 'Application',
            pattern: 'name',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To Application',
            linkUrl: $._config.argoCdUrl + '/applications/${__cell_4}/${__cell}',
          },
          {
            alias: 'Value',
            pattern: 'Value',
            type: 'hidden',
          },
        ]
      )
      .addTarget(prometheus.target(appUnhealthyQuery, format='table', instant=true)),

    local appOutOfSyncQuery = |||
      sum(
        argocd_app_info{
          %s
          sync_status!="Synced"
        }
      ) by (job, dest_server, project, name, sync_status) == 1
    ||| % commonLabels,

    local appOutOfSyncTable =
      grafana.tablePanel.new(
        'Applications Out Of Sync',
        datasource='$datasource',
        sort={
          col: 2,
          desc: true,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Sync Status',
            pattern: 'sync_status',
            type: 'string',
            colorMode: 'cell',
            colors: [
              'null',
              'orange',
            ],
            thresholds: [
              0.1,
            ],
          },
          {
            alias: 'Job',
            pattern: 'job',
            type: 'hidden',
          },
          {
            alias: 'Cluster',
            pattern: 'dest_server',
            type: 'hidden',
          },
          {
            alias: 'Project',
            pattern: 'project',
          },
          {
            alias: 'Application',
            pattern: 'name',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To Application',
            linkUrl: $._config.argoCdUrl + '/applications/${__cell_4}/${__cell}',
          },
          {
            alias: 'Value',
            pattern: 'Value',
            type: 'hidden',
          },
        ]
      )
      .addTarget(prometheus.target(appOutOfSyncQuery, format='table', instant=true)),

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
      grafana.tablePanel.new(
        'Applications That Failed to Sync[7d]',
        datasource='$datasource',
        sort={
          col: 2,
          desc: true,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Phase',
            pattern: 'phase',
          },
          {
            alias: 'Job',
            pattern: 'job',
            type: 'hidden',
          },
          {
            alias: 'Cluster',
            pattern: 'dest_server',
            type: 'hidden',
          },
          {
            alias: 'Project',
            pattern: 'project',
          },
          {
            alias: 'Application',
            pattern: 'name',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To Application',
            linkUrl: $._config.argoCdUrl + '/applications/${__cell_5}/${__cell}',
          },
          {
            alias: 'Count',
            pattern: 'Value',
            type: 'number',
            colorMode: 'cell',
            colors: [
              'null',
              'orange',
            ],
            thresholds: [
              0.1,
            ],
          },
        ]
      )
      .addTarget(prometheus.target(appSync7dQuery, format='table', instant=true)),

    local appAutoSyncDisabledQuery = |||
      sum(
        argocd_app_info{
          %s
          autosync_enabled!="true"
        }
      ) by (job, dest_server, project, name, autosync_enabled) == 1
    ||| % commonLabels,

    local appAutoSyncDisabledTable =
      grafana.tablePanel.new(
        'Applications With Auto Sync Disabled',
        datasource='$datasource',
        sort={
          col: 2,
          desc: true,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Auto Sync Enabled',
            pattern: 'autosync_enabled',
            type: 'string',
            colorMode: 'value',
            colors: [
              'null',
              'orange',
            ],
            thresholds: [
              0.1,
            ],
          },
          {
            alias: 'Job',
            pattern: 'job',
            type: 'hidden',
          },
          {
            alias: 'Cluster',
            pattern: 'dest_server',
            type: 'hidden',
          },
          {
            alias: 'Project',
            pattern: 'project',
          },
          {
            alias: 'Application',
            pattern: 'name',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To Application',
            linkUrl: $._config.argoCdUrl + '/applications/${__cell_5}/${__cell}',
          },
          {
            alias: 'Value',
            pattern: 'Value',
            type: 'hidden',
          },
        ]
      )
      .addTarget(prometheus.target(appAutoSyncDisabledQuery, format='table', instant=true)),

    local appHealthStatusByAppQuery = |||
      sum(
        argocd_app_info{
          %s
          name=~"$application",
        }
      ) by (namespace, job, dest_server, project, name, health_status)
    ||| % commonLabels,

    local appHealthStatusByAppGraphPanel =
      graphPanel.new(
        'Application Health Status',
        datasource='$datasource',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        legend_current=true,
        legend_sort='current',
        legend_sortDesc=true,
        nullPointMode='null as zero',
        fill=0,
      )
      .addTarget(
        prometheus.target(
          appHealthStatusByAppQuery,
          legendFormat='{{ dest_server }}/{{ project }}/{{ name }} - {{ health_status }}',
          interval='2m'
        )
      ),

    local appSyncStatusByAppQuery = |||
      sum(
        argocd_app_info{
          %s
          name=~"$application",
        }
      ) by (namespace, job, dest_server, project, name, sync_status)
    ||| % commonLabels,

    local appSyncStatusByAppGraphPanel =
      graphPanel.new(
        'Application Sync Status',
        datasource='$datasource',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        legend_current=true,
        legend_sort='current',
        legend_sortDesc=true,
        nullPointMode='null as zero',
        fill=0,
      )
      .addTarget(
        prometheus.target(
          appSyncStatusByAppQuery,
          legendFormat='{{ dest_server }}/{{ project }}/{{ name }} - {{ sync_status }}',
          interval='2m'
        )
      ),

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
      graphPanel.new(
        'Application Sync Result',
        datasource='$datasource',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        legend_current=true,
        legend_sort='current',
        legend_sortDesc=true,
        nullPointMode='null as zero',
        fill=0,
      )
      .addTarget(
        prometheus.target(
          appSyncByAppQuery,
          legendFormat='{{ dest_server }}/{{ project }}/{{ name }} - {{ phase }}',
          interval='2m'
        )
      ),

    local summaryRow =
      row.new(
        title='Summary by Cluster, Project'
      ),

    local appSummaryRow =
      row.new(
        title='Applications (Unhealthy/OutOfSync/AutoSyncDisabled) Summary',
      ),

    local appRow =
      row.new(
        title='Application ($application)',
      ),

    'argo-cd-application-overview.json':
      dashboard.new(
        'ArgoCD / Application / Overview',
        description='A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache). It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).',
        uid=$._config.applicationOverviewDashboardUid,
        tags=$._config.tags,
        time_from='now-6h',
        editable=true,
        time_to='now',
        timezone='utc'
      )
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(appHealthStatusGraphPanel, gridPos={ h: 5, w: 9, x: 0, y: 1 })
      .addPanel(appSyncStatusGraphPanel, gridPos={ h: 5, w: 9, x: 9, y: 1 })
      .addPanel(appSyncGraphPanel, gridPos={ h: 5, w: 9, x: 0, y: 6 })
      .addPanel(appAutoSyncStatusGraphPanel, gridPos={ h: 5, w: 9, x: 9, y: 6 })
      .addPanel(appBadgeTextPanel, gridPos={ h: 10, w: 6, x: 18, y: 1 })
      .addPanel(appSummaryRow, gridPos={ h: 1, w: 24, x: 0, y: 11 })
      .addPanel(appUnhealthyTable, gridPos={ h: 6, w: 12, x: 0, y: 12 })
      .addPanel(appOutOfSyncTable, gridPos={ h: 6, w: 12, x: 12, y: 12 })
      .addPanel(appSync7dTable, gridPos={ h: 6, w: 12, x: 0, y: 18 })
      .addPanel(appAutoSyncDisabledTable, gridPos={ h: 6, w: 12, x: 12, y: 18 })
      .addPanel(appRow, gridPos={ h: 1, w: 24, x: 0, y: 23 })
      .addPanel(appHealthStatusByAppGraphPanel, gridPos={ h: 8, w: 8, x: 0, y: 23 })
      .addPanel(appSyncStatusByAppGraphPanel, gridPos={ h: 8, w: 8, x: 8, y: 23 })
      .addPanel(appSyncByAppGraphPanel, gridPos={ h: 8, w: 8, x: 16, y: 23 })
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
