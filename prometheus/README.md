# Prometheus / Node-Exporter / cAdvisor / Grafana

[Prometheus](https://prometheus.io/docs/introduction/overview/) is an
open-source systems monitoring and alerting toolkit.

[node-exporter](https://github.com/prometheus/node_exporter) is a
collector for the Host system metrics, exported via HTTP for
prometheus to periodically poll.

[cAdvisor](https://github.com/google/cadvisor) is a collector of
performance metrics for docker containers, exported via HTTP for
prometheus to periodically poll.

[grafana](https://github.com/grafana/grafana) is a dashboard for
viewing graphs of the available metrics queried from prometheus.

## Setup

```
make config
```

* Set the metrics domainname for grafana.
* Choose whether to run node-exporter or not (For collecting the Host metrics).

```
make install
```

```
make open
```

Your web browser should open to the grafana login page. Login with the default credentials:

 * username: `admin`
 * password: `admin`

You will be prompted to change the admin password on first login.

## Dashboards

This configurations comes with the following dashboards preinstalled:

 * [Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
 * [cAdvisor Exporter](https://grafana.com/grafana/dashboards/14282-cadvisor-exporter/)

You can fine new dashboards on
[grafana.com](https://grafana.com/grafana/dashboards/). Add new
dashboards, by downloading the JSON file into the
[grafana/dashboards](grafana/dashboards) directory, and they will be
made available the next time you run `make install`.
