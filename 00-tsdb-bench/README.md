<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# TimeSeries DataBase Benchmarks

This repo will contain all the needed files to run the benchmark to choose which databse use for our timeseries

The candidates are:

- InfluxDB
- TimescaleDB
- QuestDB


## Repo structure:

```
.
├── kube_setup                     ==> folder containning the helm charts to deploy the DBs candidates
│   ├── 01-influxv2                     ==> InfluxDB v2 helm chart
│   ├── 02-timescale                    ==> TimescaleDB helm chart
│   ├── 03-questdb                      ==> QuestDB helm chart
├── README.md                      ==> This file
│── sbatch-files                   ==> folder containning the benchmark scripts
│   ├── 00-generate-data                ==> scripts to generate the data used for the load tests
│   │── 01-influx-benchmark             ==> InfluxDB benchmark scripts
│   │── 02-timescale-benchmark          ==> TimescaleDB benchmark scripts
│   └── 03-questdb-benchmark            ==> QuestDB benchmark scripts
└── results                       ==> folder containning the results of the benchmarks
    ├── influxdb
    ├── questdb
    └── timescaledb
```


The file name in the output dir shoulwd be self explanatory enought:

```
<db>_<benchmark-type>_cores<ncores>_ram<ram>_iter<iter>.out
```
