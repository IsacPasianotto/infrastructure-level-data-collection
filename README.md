# infrastructure-level-data-collection

## Repository structure


```
.
├── 00-tsdb-bench                   --> Time-series database benchmark for data ingestion layer
├── 01-telegraf-deployment          --> Telegraf deployment and configuration for data collection
├── 02-get-data.sh                  --> Script to download data from Zenodo, used in the analysis of the case of study
├── 03-ior-bench                    --> I/O performance benchmark case of study
├── 04-llm-inference                --> LLM inference case of study
├── 05-data-etl                     --> Data Extraction, Transformation, and Loading pipeline
└── README.md                       --> This file
```


Notes:
- The istance of QuestDB used to ingestion in all the data the identical to the one deployed in the `00-tsdb-bench` directory, so the configuration and deployment instructions are the same.
- All the jupyter notebook will refers to data stored into a `data/` directory, which content is not included in the repository (due to the size of the data). The data can be downloaded using the `02-get-data.sh` script, which will download the data from Zenodo.
- The only exception is the content of a table `experiments` which is not part of the released dataset, but a helper table used to store the metadata of the experiments (e.g. configuration, etc...). This is provided as a `.parquet` file in the `data/` directory.


# TODOs:

- [~] 03-ior-bench:
  - [x] Aggiungere i notebook sistemati con il post-process dei dati
  - [ ] Aggiungere 1 notebook per la generazione dei grafici
- [ ] 04-llm-inference:
  - [ ] Aggiungere notebook con i risultati dell'inference
  - [ ] Aggiungere notebook per la generazione dei grafici
- [ ] 05-data-etl:
  - [ ] tutto (prednere da scratch orfeo)
    - [ ] download parquet from questdb
    - [ ] Sanity check dei dati (buchi, etc...)
    - [ ] polaris catalog setup
      - [ ] Kube deployment
      - [ ] Catalog configuration
    - [ ] Load data into polaris catalog
    - [ ] notebook con query di esempio
