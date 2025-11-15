{
  _config+:: {
    local this = self,

    argoCdSelector: 'job=~".*"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    grafanaUrl: 'https://grafana.com',
    argoCdUrl: 'https://argocd.com',

    dashboardIds: {
      'argo-cd-operational-overview': 'argo-cd-operational-overview-kask',
      'argo-cd-application-overview': 'argo-cd-application-overview-kask',
      'argo-cd-notifications-overview': 'argo-cd-notifications-overview-kask',
    },
    dashboardUrls: {
      'argo-cd-operational-overview': '%s/d/%s/argocd-operational-overview' % [this.grafanaUrl, this.dashboardIds['argo-cd-operational-overview']],
      'argo-cd-application-overview': '%s/d/%s/argocd-application-overview' % [this.grafanaUrl, this.dashboardIds['argo-cd-application-overview']],
      'argo-cd-notifications-overview': '%s/d/%s/argocd-notifications-overview' % [this.grafanaUrl, this.dashboardIds['argo-cd-notifications-overview']],
    },

    tags: ['ci/cd', 'argo-cd'],

    argoCdAppOutOfSyncEnabled: true,
    argoCdAppOutOfSyncFor: '15m',
    // The above OutOfSync alert also includes applications in an Unknown state.
    // However, that alert may not be appropriate in all scenarios.
    // This alert specifically targets applications that are Unknown to ArgoCD,
    // without triggering on other OutOfSync conditions.
    argoCdAppUnknownEnabled: false,
    argoCdAppUnknownFor: '15m',
    argoCdAppUnhealthyEnabled: true,
    argoCdAppUnhealthyFor: '15m',
    argoCdAppAutoSyncDisabledEnabled: true,
    argoCdAppAutoSyncDisabledFor: '2h',
    argoCdAppSyncInterval: '10m',
    argoCdNotificationDeliveryEnabled: true,
    argoCdNotificationDeliveryInterval: '10m',

    // List of applications to ignore in the unhealthy alert
    argoCdAppUnhealthyIgnoredApps: '',
    // List of states that are classified healthy.
    argoCdAppUnhealthyHealthyStates: 'Healthy|Progressing',
    // List of applications to ignore in the auto sync disabled alert
    argoCdAutoSyncDisabledIgnoredApps: '',
    // Backwards compability
    argoAutoSyncDisabledIgnoredApps: self.argoCdAutoSyncDisabledIgnoredApps,
    // List of applications to ignore in the unknown alert
    argoCdAppUnknownIgnoredApps: '',

    // Render ArgoCD badges in the dashboards
    // []struct{}
    // [
    //   {
    //     name: 'ArgoCD',
    //     namespace: 'argocd',
    //     applicationName: 'ArgoCD', // or self.name
    //     environment: 'Production',
    //     argoCdUrl: "https://argo-cd.example.com" // or $._config.argoCdUrl
    //   }
    // ]
    applications: [],

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      tags: [],
      datasource: '-- Grafana --',
      iconColor: 'blue',
      type: 'tags',
    },
  },
}
