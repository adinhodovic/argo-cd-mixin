{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'django',
        rules: [
          {
            alert: 'DjangoMigrationsUnapplied',
            expr: |||
              sum(
                django_migrations_unapplied_total{
                  %(djangoSelector)s
                }
              ) by (namespace, job)
              > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': '15m',
            annotations: {
              summary: 'Django has unapplied migrations.',
              description: 'The job {{ $labels.job }} has unapplied migrations.',
              dashboard_url: $._config.overviewDashboardUrl + '?var-job={{ $labels.job }}',
            },
          },
          {
            alert: 'DjangoDatabaseException',
            expr: |||
              sum (
                increase(
                  django_db_errors_total{
                    %(djangoSelector)s
                  }[10m]
                )
              ) by (type, namespace, job)
              > 0
            ||| % $._config,
            labels: {
              severity: 'info',
            },
            annotations: {
              summary: 'Django database exception.',
              description: 'The job {{ $labels.job }} has hit the database exception {{ $labels.type }}.',
              dashboard_url: $._config.overviewDashboardUrl + '?var-job={{ $labels.job }}',
            },
          },
          {
            alert: 'DjangoHighHttp4xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    status=~"^4.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django4xxInterval)s]
                )
              )  by (namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django4xxInterval)s]
                )
              )  by (namespace, job, view)
              * 100 > %(django4xxThreshold)s
            ||| % $._config,
            'for': '1m',
            annotations: {
              summary: 'Django high HTTP 4xx error rate.',
              description: 'More than %(django4xxThreshold)s%% HTTP requests with status 4xx for {{ $labels.job }}/{{ $labels.view }} the past %(django4xxInterval)s.' % $._config,
              dashboard_url: $._config.requestsByViewDashboardUrl + '?var-job={{ $labels.job }}&var-view={{ $labels.view }}',
            },
            labels: {
              severity: $._config.django4xxSeverity,
            },
          },
          {
            alert: 'DjangoHighHttp5xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    status=~"^5.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django5xxInterval)s]
                )
              )  by (namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django5xxInterval)s]
                )
              )  by (namespace, job, view)
              * 100 > %(django5xxThreshold)s
            ||| % $._config,
            'for': '1m',
            annotations: {
              summary: 'Django high HTTP 5xx error rate.',
              description: 'More than %(django5xxThreshold)s%% HTTP requests with status 5xx for {{ $labels.job }}/{{ $labels.view }} the past %(django5xxInterval)s.' % $._config,
              dashboard_url: $._config.requestsByViewDashboardUrl + '?var-job={{ $labels.job }}&var-view={{ $labels.view }}',
            },
            labels: {
              severity: $._config.django5xxSeverity,
            },
          },
        ],
      },
    ],
  },
}
