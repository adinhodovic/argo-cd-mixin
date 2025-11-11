local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    namespace: 'namespace=~"$namespace"',
    job: 'job=~"$job"',
    kubernetesCluster: 'dest_server=~"$kubernetes_cluster"',
    // This is an ArgoCD Inconsistency
    kubernetesClusterServer: 'server=~"$kubernetes_cluster"',
    project: 'project=~"$project"',

    base: |||
      %(cluster)s,
      %(namespace)s,
      %(job)s
    ||| % this,

    default: |||
      %(base)s
    ||| % this,

    withProject: |||
      %(default)s,
      %(kubernetesCluster)s,
      %(project)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new(
        config.clusterLabel,
        'label_values(argocd_app_info{}, cluster)',
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    namespace:
      query.new(
        'namespace',
        'label_values(argocd_app_info{%(cluster)s}, namespace)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    // We use operational metrics from multiple Argo CD jobs, hence we need to use a regex.
    job:
      query.new(
        'job',
        'label_values(argocd_app_info{%(cluster)s, %(namespace)s}, job)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true, '.*') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    kubernetesCluster:
      query.new(
        'kubernetes_cluster',
        'label_values(argocd_app_info{%(cluster)s, %(namespace)s, %(job)s}, dest_server)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Kubernetes Cluster') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    project:
      query.new(
        'project',
        'label_values(argocd_app_info{%(cluster)s, %(namespace)s, %(job)s, %(kubernetesCluster)s}, project)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Project') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
