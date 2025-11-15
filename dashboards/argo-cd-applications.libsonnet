local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local textPanel = g.panel.text;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;
local tbCustom = tablePanel.fieldConfig.defaults.custom;

{
  local dashboardName = 'argo-cd-application-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.kubernetesCluster,
        defaultVariables.project,
        defaultVariables.applicationNamespace,
        defaultVariables.application,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        // By Project
        appHealthStatusCount: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (job, project, health_status)
        ||| % defaultFilters,

        appSyncStatusCount: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (job, project, sync_status)
        ||| % defaultFilters,

        appSyncCount: |||
          sum(
            round(
              increase(
                argocd_app_sync_total{
                  %(withProject)s
                }[$__rate_interval]
              )
            )
          ) by (job, project, phase)
        ||| % defaultFilters,

        appAutoSyncStatusCount: |||
          sum(
            argocd_app_info{
              %(withProject)s
            }
          ) by (job, project, autosync_enabled)
        ||| % defaultFilters,

        // By Application (grouped)
        appUnhealthyCount: |||
          sum(
            argocd_app_info{
              %(withProject)s,
              health_status!~"Healthy|Progressing"
            }
          ) by (job, dest_server, project, name, exported_namespace, health_status) > 0
        ||| % defaultFilters,

        appOutOfSyncCount: |||
          sum(
            argocd_app_info{
              %(withProject)s,
              sync_status!="Synced"
            }
          ) by (job, dest_server, project, name, exported_namespace, sync_status) > 0
        ||| % defaultFilters,

        appAutoSyncDisabledCount: |||
          sum(
            argocd_app_info{
              %(withProject)s,
              autosync_enabled!="true"
            }
          ) by (job, dest_server, project, name, exported_namespace, autosync_enabled) > 0
        ||| % defaultFilters,

        appSyncFailed7dCount: |||
          sum(
            round(
              increase(
                argocd_app_sync_total{
                  %(withProject)s,
                  phase!="Succeeded"
                }[7d]
              )
            )
          ) by (job, dest_server, project, name, exported_namespace, phase) > 0
        ||| % defaultFilters,

        // By Application (detailed)
        appHealthStatusByAppCount: |||
          sum(
            argocd_app_info{
              %(withApplication)s
            }
          ) by (namespace, job, dest_server, project, name, exported_namespace, health_status)
        ||| % defaultFilters,

        appSyncStatusByAppCount: |||
          sum(
            argocd_app_info{
              %(withApplication)s
            }
          ) by (namespace, job, dest_server, project, name, exported_namespace, sync_status)
        ||| % defaultFilters,

        appSyncByAppCount: |||
          sum(
            round(
              increase(
                argocd_app_sync_total{
                  %(withApplication)s
                }[$__rate_interval]
              )
            )
          ) by (namespace, job, dest_server, project, name, exported_namespace, phase)
        ||| % defaultFilters,
      };

      local panels = {

        // By Project
        appHealthStatusTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Health Status',
            'short',
            queries.appHealthStatusCount,
            '{{ project }} - {{ health_status }}',
            description='A timeseries panel showing the health status of applications managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appSyncStatusTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Sync Status',
            'short',
            queries.appSyncStatusCount,
            '{{ project }} - {{ sync_status }}',
            description='A timeseries panel showing the sync status of applications managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appSyncTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Syncs',
            'short',
            queries.appSyncCount,
            '{{ project }} - {{ phase }}',
            description='A timeseries panel showing the sync results of applications managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appAutoSyncStatusTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Auto Sync Enabled',
            'short',
            queries.appAutoSyncStatusCount,
            '{{ project }} - {{ autosync_enabled }}',
            description='A timeseries panel showing whether auto sync is enabled for applications managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appsDefined: std.length($._config.applications) != 0,
        local appBadgeContent = [
          '| %(name)s | %(environment)s | [![App Status](%(baseUrl)s/api/badge?namespace=%(namespace)s&name=%(applicationName)s&revision=true)](%(baseUrl)s/applications/%(namespace)s/%(applicationName)s) |' % application {
            baseUrl: if std.objectHas(application, 'baseUrl') then application.baseUrl else $._config.argoCdUrl,
            applicationName: if std.objectHas(application, 'applicationName') then application.applicationName else application.name,
          }
          for application in $._config.applications
        ],
        appBadgeTextPanel:
          mixinUtils.dashboards.textPanel(
            'Application Badges',
            |||
              | Application | Environment | Status |
              | --- | --- | --- |
              %s
            ||| % std.join('\n', appBadgeContent),
            description='A panel displaying badges for quick access to ArgoCD applications.'
          ),

        // By Application (grouped)
        appUnhealthyTable:
          mixinUtils.dashboards.tablePanel(
            'Unhealthy Applications',
            'short',
            queries.appUnhealthyCount,
            description='A table listing all unhealthy applications managed by ArgoCD.',
            sortBy={ name: 'Application', desc: false },
            transformations=
            [
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    dest_server: 'Cluster',
                    project: 'Project',
                    name: 'Application',
                    exported_namespace: 'Application Namespace',
                    health_status: 'Health Status',
                  },
                  indexByName: {
                    name: 0,
                    exported_namespace: 1,
                    project: 2,
                    health_status: 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    dest_server: true,
                    Value: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('health_status') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.color.withMode('fixed') +
                tbStandardOptions.color.withFixedColor('yellow') +
                tbCustom.cellOptions.TableColoredBackgroundCellOptions.withType()
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Application Namespace}/${__data.fields.Application}'
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        appOutOfSyncTable:
          mixinUtils.dashboards.tablePanel(
            'Out Of Sync Applications',
            'short',
            queries.appOutOfSyncCount,
            description='A table listing all unhealthy applications managed by ArgoCD.',
            sortBy={ name: 'Application', desc: false },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    dest_server: 'Cluster',
                    project: 'Project',
                    name: 'Application',
                    exported_namespace: 'Application Namespace',
                    sync_status: 'Sync Status',
                  },
                  indexByName: {
                    name: 0,
                    exported_namespace: 1,
                    project: 2,
                    sync_status: 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    dest_server: true,
                    Value: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('sync_status') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.color.withMode('fixed') +
                tbStandardOptions.color.withFixedColor('yellow') +
                tbCustom.cellOptions.TableColoredBackgroundCellOptions.withType()
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Application Namespace}/${__data.fields.Application}'
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        appSync7dTable:
          mixinUtils.dashboards.tablePanel(
            'Applications That Failed to Sync (7d)',
            'short',
            queries.appSyncFailed7dCount,
            description='A table listing all applications that failed to sync in the last 7 days managed by ArgoCD.',
            sortBy={ name: 'Application', desc: false },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    dest_server: 'Cluster',
                    project: 'Project',
                    name: 'Application',
                    exported_namespace: 'Application Namespace',
                    phase: 'Phase',
                    Value: 'Count',
                  },
                  indexByName: {
                    name: 0,
                    exported_namespace: 1,
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
            ],
            overrides=[
              tbOverride.byName.new('Value') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.color.withMode('fixed') +
                tbStandardOptions.color.withFixedColor('yellow') +
                tbCustom.cellOptions.TableColoredBackgroundCellOptions.withType()
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Application Namespace}/${__data.fields.Application}'
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        appAutoSyncDisabledTable:
          mixinUtils.dashboards.tablePanel(
            'Applications With Auto Sync Disabled',
            'short',
            queries.appAutoSyncDisabledCount,
            description='A table listing all applications with auto sync disabled managed by ArgoCD.',
            sortBy={ name: 'Application', desc: false },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    dest_server: 'Kubernetes Cluster',
                    project: 'Project',
                    name: 'Application',
                    exported_namespace: 'Application Namespace',
                    autosync_enabled: 'Auto Sync Enabled',
                  },
                  indexByName: {
                    name: 0,
                    exported_namespace: 1,
                    project: 2,
                    autosync_enabled: 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    dest_server: true,
                    Value: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('autosync_enabled') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.color.withMode('fixed') +
                tbStandardOptions.color.withFixedColor('yellow') +
                tbCustom.cellOptions.TableColoredBackgroundCellOptions.withType()
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withUrl(
              $._config.argoCdUrl + '/applications/${__data.fields.Application Namespace}/${__data.fields.Application}'
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        // By Application (detailed)
        appHealthStatusByAppTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Health Status by Application',
            'short',
            queries.appHealthStatusByAppCount,
            '{{ exported_namespace }}/{{ name }} - {{ health_status }}',
            description='A timeseries panel showing the health status of each application managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appSyncStatusByAppTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Sync Status by Application',
            'short',
            queries.appSyncStatusByAppCount,
            '{{ exported_namespace }}/{{ name }} - {{ sync_status }}',
            description='A timeseries panel showing the sync status of each application managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),

        appSyncByAppTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Application Sync Result by Application',
            'short',
            queries.appSyncByAppCount,
            '{{ exported_namespace }}/{{ name }} - {{ phase }}',
            description='A timeseries panel showing the sync result of each application managed by ArgoCD.',
            stack='normal',
            decimals=0
          ),
      };

      local rows =
        [
          row.new('Summary By Project') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.appHealthStatusTimeSeries,
            panels.appSyncStatusTimeSeries,
            panels.appSyncTimeSeries,
            panels.appAutoSyncStatusTimeSeries,
          ],
          panelWidth=if panels.appsDefined then 9 else 12,
          panelHeight=6,
          startY=1
        ) +
        (
          if panels.appsDefined then
            [
              panels.appBadgeTextPanel +
              textPanel.gridPos.withX(18) +
              textPanel.gridPos.withY(1) +
              textPanel.gridPos.withW(6) +
              textPanel.gridPos.withH(12),
            ] else []
        ) +
        [
          row.new('Applications (Unhealthy/OutOfSync/AutoSyncDisabled) Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(18) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.appUnhealthyTable,
            panels.appOutOfSyncTable,
            panels.appSync7dTable,
            panels.appAutoSyncDisabledTable,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=12
        ) +
        [
          row.new('Application ($application)') +
          row.withRepeat('application') +
          row.gridPos.withX(0) +
          row.gridPos.withY(25) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.appHealthStatusByAppTimeSeries,
            panels.appSyncStatusByAppTimeSeries,
            panels.appSyncByAppTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=27
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'ArgoCD / Application / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors ArgoCD with a focus on the applications of ArgoCD. %s' % mixinUtils.dashboards.dashboardDescriptionLink('argo-cd-mixin', 'https://github.com/adinhodovic/argo-cd-mixin')) +
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
