local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotation = g.dashboard.annotation;

{
  _config+:: {
    argoCdSelector: 'job=~".*"',

    grafanaUrl: 'https://grafana.com',
    argoCdUrl: 'https://argocd.com',

    applicationOverviewDashboardUid: 'argo-cd-application-overview-kask',
    notificationsOverviewDashboardUid: 'argo-cd-notifications-overview-kask',

    applicationOverviewDashboardUrl: '%s/d/%s/argocd-application-overview' % [self.grafanaUrl, self.applicationOverviewDashboardUid],
    notificationsOverviewDashboardUrl: '%s/d/%s/argocd-notifications-overview' % [self.grafanaUrl, self.notificationsOverviewDashboardUid],

    tags: ['ci/cd', 'argo-cd'],

    argoCdAppOutOfSyncFor: '10m',
    argoCdAppUnhealthyFor: '10m',
    argoCdAppAutoSyncDisabledFor: '1h',
    argoCdAppSyncInterval: '10m',
    argoCdNotificationDeliveryInterval: '10m',

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      datasource: '-- Grafana --',
      iconColor: 'green',
      tags: [],
    },

    // Render ArgoCD badges in the dashboards
    // []struct{}
    // [
    //   {
    //     name: 'ArgoCD',
    //     applicationName: 'ArgoCD', // or self.name
    //     environment: 'Production',
    //     argoCdUrl: "https://argo-cd.example.com" // or $._config.argoCdUrl
    //   }
    // ]
    applications: [],

    customAnnotation:: if $._config.annotation.enabled then
      annotation.withName($._config.annotation.name) +
      annotation.withIconColor($._config.annotation.iconColor) +
      annotation.withHide(false) +
      annotation.datasource.withUid($._config.annotation.datasource) +
      annotation.target.withMatchAny(true) +
      annotation.target.withTags($._config.annotation.tags) +
      annotation.target.withType('tags')
    else {},
  },
}
