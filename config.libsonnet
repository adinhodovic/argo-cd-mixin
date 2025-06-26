local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotation = g.dashboard.annotation;

{
  _config+:: {
    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    argoCdSelector: 'job=~".*"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    grafanaUrl: 'https://grafana.com',
    argoCdUrl: 'https://argocd.com',

    operationalOverviewDashboardUid: 'argo-cd-operational-overview-kask',
    applicationOverviewDashboardUid: 'argo-cd-application-overview-kask',
    notificationsOverviewDashboardUid: 'argo-cd-notifications-overview-kask',

    applicationOverviewDashboardUrl: '%s/d/%s/argocd-application-overview' % [self.grafanaUrl, self.applicationOverviewDashboardUid],
    notificationsOverviewDashboardUrl: '%s/d/%s/argocd-notifications-overview' % [self.grafanaUrl, self.notificationsOverviewDashboardUid],

    tags: ['ci/cd', 'argo-cd'],

    argoCdAppOutOfSyncEnabled: true,
    argoCdAppOutOfSyncFor: '15m',
    argoCdAppUnhealthyEnabled: true,
    argoCdAppUnhealthyFor: '15m',
    argoCdAppAutoSyncDisabledEnabled: true,
    argoCdAppAutoSyncDisabledFor: '2h',
    argoCdAppSyncInterval: '10m',
    argoCdNotificationDeliveryEnabled: true,
    argoCdNotificationDeliveryInterval: '10m',

    // List of applications to ignore in the unhealthy alert
    argoCdAppUnhealthyIgnoredApps: '',
    // List of applications to ignore in the auto sync disabled alert
    argoCdAutoSyncDisabledIgnoredApps: '',
    // Backwards compability
    argoAutoSyncDisabledIgnoredApps: self.argoCdAutoSyncDisabledIgnoredApps,

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
