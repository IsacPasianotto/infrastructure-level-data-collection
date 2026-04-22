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
- All the python code present in the repository is tested with `python3.13.2` and used the `venv` module for the creation of a virtual environment. The dependencies are listed in the `requirements.txt` file. To create a virtual environment and install the dependencies, you can run the following commands:
```bash
pushd $(git rev-parse --show-toplevel) > /dev/null || exit 1
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
popd > /dev/null || exit 1
```

# TODOs:

- [~] 03-ior-bench:
  - [x] Aggiungere i notebook sistemati con il post-process dei dati
  - [ ] Aggiungere 1 notebook per la generazione dei grafici
- [ ] 04-llm-inference:
  - [ ] Codice di come abbiamo fatto lo stress test
  - [ ] Aggiungere notebook con i risultati dell'inference
  - [ ] Aggiungere notebook per la generazione dei grafici
- [~] 05-data-etl:
  - [x] download parquet from questdb
  - [X] Sanity check dei dati (buchi, etc...)
  - [x] polaris catalog setup
    - [x] Kube deployment
    - [x] Catalog configuration
  - [ ] Load data into polaris catalog
  - [ ] notebook con query di esempio
- [ ] Fare un giro in tutto il repository per sistemare le licenze con `reuse`