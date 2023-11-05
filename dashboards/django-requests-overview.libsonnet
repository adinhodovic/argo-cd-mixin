local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;

local paginateTable = {
  pageSize: 6,
};

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
        query='label_values(django_http_responses_total_by_status_view_method_total{}, namespace)',
        current='',
        hide='',
        refresh=2,  // On Time Range Change
        multi=false,
        includeAll=false,
        sort=1
      ),

    local jobTemplate =
      template.new(
        name='job',
        label='Job',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{namespace=~"$namespace"}, job)',
        hide='',
        refresh=2,  // On Time Range Change
        multi=false,
        includeAll=false,
        sort=1
      ),

    local defaultFilters = 'namespace=~"$namespace", job=~"$job"',

    local viewTemplate =
      template.new(
        name='view',
        label='View',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{%s, view!~"%s"}, view)' % [defaultFilters, $._config.djangoIgnoredViews],
        hide='',
        refresh=2,  // On Time Range Change
        multi=true,
        includeAll=true,
        sort=1
      ),

    local methodTemplate =
      template.new(
        name='method',
        label='Method',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{%s, view=~"$view"}, method)' % defaultFilters,
        hide='',
        refresh=2,  // On Time Range Change
        multi=true,
        includeAll=true,
        sort=1
      ),

    local templates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
      viewTemplate,
      methodTemplate,
    ],

    local requestVolumeQuery = |||
      round(
        sum(
          rate(
            django_http_requests_total_by_view_transport_method_total{namespace=~"$namespace", job=~"$job", view=~"$view", view!~"%(djangoIgnoredViews)s", method=~"$method"}[2m]
          )
        ), 0.001
      )
    ||| % $._config,
    local requestVolumeStatPanel =
      statPanel.new(
        'Request Volume',
        datasource='$datasource',
        unit='reqps',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestVolumeQuery))
      .addThresholds([
        { color: 'red', value: 0 },
        { color: 'green', value: 0.001 },
      ]),

    local requestSuccessRateQuery = |||
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{namespace=~"$namespace", job=~"$job", view=~"$view", view!~"%(djangoIgnoredViews)s", method=~"$method", status!~"[4-5].*"}[$__rate_interval]
          )
      ) /
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{namespace=~"$namespace", job=~"$job", view=~"$view", view!~"%(djangoIgnoredViews)s", method=~"$method"}[$__rate_interval]
        )
      )
    ||| % $._config,
    local requestSuccessRateStatPanel =
      statPanel.new(
        'Success Rate (non 4-5xx responses)',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestSuccessRateQuery))
      .addThresholds([
        { color: 'red', value: 0.90 },
        { color: 'yellow', value: 0.95 },
        { color: 'green', value: 0.99 },
      ]),

    local requestBytesP95Query = |||
      histogram_quantile(0.95,
        sum (
          rate (
              django_http_requests_body_total_bytes_bucket {
                namespace=~"$namespace",
                job=~"$job",
              }[$__rate_interval]
          )
        ) by (job, le)
      )
    ||| % $._config,
    local requestBytesStatPanel =
      statPanel.new(
        'Request Body Size (P95)',
        datasource='$datasource',
        unit='decbytes',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestBytesP95Query))
      .addThresholds([
        { color: 'red', value: 0.1 },
        { color: 'yellow', value: 0.2 },
        { color: 'green', value: 0.3 },
      ]),

    local requestLatencyP95SummaryQuery = |||
      histogram_quantile(0.95,
        sum (
          irate(
              django_http_requests_latency_seconds_by_view_method_bucket {
                namespace=~"$namespace",
                job=~"$job",
                view!~"%(djangoIgnoredViews)s",
              }[$__rate_interval]
          )
        ) by (job, le)
      )
    ||| % $._config,
    local requestLatencyP95SummaryStatPanel =
      statPanel.new(
        'Request Latency (P95)',
        datasource='$datasource',
        unit='s',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestLatencyP95SummaryQuery))
      .addThresholds([
        { color: 'green', value: 0 },
        { color: 'yellow', value: 2500 },
        { color: 'red', value: 5000 },
      ]),

    local apiRequestLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          rate(
            django_http_requests_latency_seconds_by_view_method_bucket{
              namespace=~"$namespace",
              job=~"$job",
              view=~"$view",
              view!~"%(djangoIgnoredViews)s|",
              view!~"%(adminViewRegex)s",
              method=~"$method"
            }[$__rate_interval]
          ) > 0
        ) by (view, job, le)
      )
    ||| % $._config,
    local apiRequestLatencyP95Query = std.strReplace(apiRequestLatencyP50Query, '0.50', '0.95'),
    local apiRequestLatencyP99Query = std.strReplace(apiRequestLatencyP50Query, '0.50', '0.99'),

    local apiRequestLatencyTable =
      grafana.tablePanel.new(
        'API & Other Views Request Latency',
        datasource='$datasource',
        sort={
          col: 3,
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
            alias: 'View',
            pattern: 'view',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To View',
            linkUrl: $._config.requestsByViewDashboardUrl + '?var-job=$job&var-namespace=$namespace&var-view=${__cell}',
          },
          {
            alias: 'Namespace',
            pattern: 'namespace',
          },
          {
            alias: 'Job',
            pattern: 'job',
          },
          {
            alias: 'P50 Latency',
            pattern: 'Value #A',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P90 Latency',
            pattern: 'Value #B',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P99 Latency',
            pattern: 'Value #C',
            type: 'number',
            unit: 'dtdurations',
          },
        ]
      )
      .addTarget(
        prometheus.target(
          apiRequestLatencyP50Query,
          format='table',
          instant=true
        )
      )
      .addTarget(
        prometheus.target(
          apiRequestLatencyP95Query,
          format='table',
          instant=true
        )
      )
      .addTarget(
        prometheus.target(
          apiRequestLatencyP99Query,
          format='table',
          instant=true
        )
      ) + paginateTable,

    local adminRequestLatencyP50Query = std.strReplace(apiRequestLatencyP50Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminRequestLatencyP95Query = std.strReplace(apiRequestLatencyP95Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminRequestLatencyP99Query = std.strReplace(apiRequestLatencyP99Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),

    local adminRequestLatencyTable =
      grafana.tablePanel.new(
        'Admin Request Latency',
        datasource='$datasource',
        sort={
          col: 3,
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
            alias: 'View',
            pattern: 'view',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To View',
            linkUrl: $._config.requestsByViewDashboardUrl + '?var-job=$job&var-namespace=$namespace&var-view=${__cell}',
          },
          {
            alias: 'Namespace',
            pattern: 'namespace',
          },
          {
            alias: 'Job',
            pattern: 'Job',
          },
          {
            alias: 'P50 Latency',
            pattern: 'Value #A',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P90 Latency',
            pattern: 'Value #B',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P99 Latency',
            pattern: 'Value #C',
            type: 'number',
            unit: 'dtdurations',
          },
        ]
      )
      .addTarget(
        prometheus.target(
          adminRequestLatencyP50Query,
          format='table',
          instant=true
        )
      )
      .addTarget(
        prometheus.target(
          adminRequestLatencyP95Query,
          format='table',
          instant=true
        )
      )
      .addTarget(
        prometheus.target(
          adminRequestLatencyP99Query,
          format='table',
          instant=true
        )
      ) + paginateTable,

    local apiResponse2xxQuery = |||
      round(
        sum(
          rate(
            django_http_responses_total_by_status_view_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view=~"$view",
              view!~"%(djangoIgnoredViews)s",
              method=~"$method",
              status=~"2.*",
              view!~"%(adminViewRegex)s",
            }[$__rate_interval]
          ) > 0
        ) by (namespace, job, view), 0.001
      )
    ||| % $._config,
    local apiResponse4xxQuery = std.strReplace(apiResponse2xxQuery, '2.*', '4.*'),
    local apiResponse5xxQuery = std.strReplace(apiResponse2xxQuery, '2.*', '5.*'),
    local apiResponseGraphPanel =
      graphPanel.new(
        'API & Other Views Response Status',
        datasource='$datasource',
        format='reqps',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
        legend_sort='avg',
        legend_sortDesc=true,
        fill=10,
        stack=true,
        nullPointMode='null as zero'
      )
      .addTarget(
        prometheus.target(
          apiResponse2xxQuery,
          legendFormat='{{ view }} / 2xx',
        )
      )
      .addTarget(
        prometheus.target(
          apiResponse4xxQuery,
          legendFormat='{{ view }} / 4xx',
        )
      )
      .addTarget(
        prometheus.target(
          apiResponse5xxQuery,
          legendFormat='{{ view }} / 5xx',
        )
      ),

    local adminResponse2xxQuery = std.strReplace(apiResponse2xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminResponse4xxQuery = std.strReplace(apiResponse4xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminResponse5xxQuery = std.strReplace(apiResponse5xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminResponseGraphPanel =
      graphPanel.new(
        'Admin Views Response Status',
        datasource='$datasource',
        format='reqps',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
        legend_sort='avg',
        legend_sortDesc=true,
        stack=true,
        fill=10,
        nullPointMode='null as zero'
      )
      .addTarget(
        prometheus.target(
          adminResponse2xxQuery,
          legendFormat='{{ view }} / 2xx',
        )
      )
      .addTarget(
        prometheus.target(
          adminResponse4xxQuery,
          legendFormat='{{ view }} / 4xx',
        )
      )
      .addTarget(
        prometheus.target(
          adminResponse5xxQuery,
          legendFormat='{{ view }} / 5xx',
        )
      ),

    local topHttpExceptionsByType1wQuery = |||
      round(
        topk(10,
          sum by (type) (
            increase(
              django_http_exceptions_total_by_type_total{
                namespace=~"$namespace",
                job=~"$job",
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,
    local topHttpExceptionsByType1wTable =
      grafana.tablePanel.new(
        'Top Exceptions by Type (1w)',
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
            alias: 'Type',
            pattern: 'type',
          },
          {
            alias: 'Value',
            pattern: 'Value',
            type: 'number',
          },
        ]
      )
      .addTarget(prometheus.target(topHttpExceptionsByType1wQuery, format='table', instant=true)) + paginateTable,

    local topHttpExceptionsByView1wQuery = |||
      round(
        topk(10,
          sum by (view) (
            increase(
              django_http_exceptions_total_by_view_total{
                namespace=~"$namespace",
                job=~"$job",
                view!~"%(djangoIgnoredViews)s",
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,
    local topHttpExceptionsByView1wTable =
      grafana.tablePanel.new(
        'Top Exceptions by View (1w)',
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
            alias: 'View',
            pattern: 'view',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To View',
            linkUrl: $._config.requestsByViewDashboardUrl + '?var-job=$job&var-namespace=$namespace&var-view=${__cell}',
          },
          {
            alias: 'Value',
            pattern: 'Value',
            type: 'number',
          },
        ]
      )
      .addTarget(prometheus.target(topHttpExceptionsByView1wQuery, format='table', instant=true)) + paginateTable,

    local topResponseByView1wQuery = |||
      round(
        topk(10,
          sum by (view) (
            increase(
              django_http_responses_total_by_status_view_method_total{
                namespace=~"$namespace",
                job=~"$job",
                view!~"%(djangoIgnoredViews)s",
                method=~"$method"
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,
    local topResponseByView1wTable =
      grafana.tablePanel.new(
        'Top Responses By View (1w)',
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
            alias: 'View',
            pattern: 'view',
            link: true,
            linkTargetBlank: true,
            linkTooltip: 'Go To View',
            linkUrl: $._config.requestsByViewDashboardUrl + '?var-job=$job&var-namespace=$namespace&var-view=${__cell}',
          },
        ]
      )
      .addTarget(prometheus.target(topResponseByView1wQuery, format='table', instant=true)) + paginateTable,


    local topTemplates1wQuery = |||
      topk(10,
        round(
          sum by (templatename) (
            increase(
              django_http_responses_total_by_templatename_total{
                namespace=~"$namespace",
                job=~"$job",
                templatename!~"%(djangoIgnoredTemplates)s"
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,
    local topTemplates1wTable =
      grafana.tablePanel.new(
        'Top Templates (1w)',
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
            alias: 'Template Name',
            pattern: 'templatename',
          },
        ]
      )
      .addTarget(prometheus.target(topTemplates1wQuery, format='table', instant=true)) + paginateTable,

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local adminViewRow =
      row.new(
        title='Admin Views'
      ),

    local apiViewRow =
      row.new(
        title='API Views & Other'
      ),

    local weeklyBreakdownRow =
      row.new(
        title='Weekly Breakdown',
      ),

    'django-requests-overview.json':
      dashboard.new(
        'Django / Requests / Overview',
        description='A dashboard that monitors Django which focuses on giving a overview for requests. It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).',
        uid=$._config.requestsOverviewDashboardUid,
        tags=$._config.tags,
        time_from='now-1h',
        editable=true,
        time_to='now',
        timezone='utc'
      )
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(requestVolumeStatPanel, gridPos={ h: 4, w: 6, x: 0, y: 1 })
      .addPanel(requestSuccessRateStatPanel, gridPos={ h: 4, w: 6, x: 6, y: 1 })
      .addPanel(requestLatencyP95SummaryStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(requestBytesStatPanel, gridPos={ h: 4, w: 6, x: 18, y: 1 })
      .addPanel(apiViewRow, gridPos={ h: 1, w: 24, x: 0, y: 5 })
      .addPanel(apiResponseGraphPanel, gridPos={ h: 10, w: 12, x: 0, y: 6 })
      .addPanel(apiRequestLatencyTable, gridPos={ h: 10, w: 12, x: 12, y: 6 })
      .addPanel(adminViewRow, gridPos={ h: 1, w: 24, x: 0, y: 16 })
      .addPanel(adminResponseGraphPanel, gridPos={ h: 10, w: 12, x: 0, y: 17 })
      .addPanel(adminRequestLatencyTable, gridPos={ h: 10, w: 12, x: 12, y: 17 })
      .addPanel(weeklyBreakdownRow, gridPos={ h: 1, w: 24, x: 0, y: 26 })
      .addPanel(topHttpExceptionsByView1wTable, gridPos={ h: 8, w: 12, x: 0, y: 27 })
      .addPanel(topHttpExceptionsByType1wTable, gridPos={ h: 8, w: 12, x: 12, y: 27 })
      .addPanel(topResponseByView1wTable, gridPos={ h: 8, w: 12, x: 0, y: 35 })
      .addPanel(topTemplates1wTable, gridPos={ h: 8, w: 12, x: 12, y: 35 })
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
