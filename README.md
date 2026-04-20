# infrastructure-level-data-collection

## Repository structure


```
.
├── 00-tsdb-bench                   --> Time-series database benchmark for data ingestion layer
├── 01-telegraf-deployment          --> Telegraf deployment and configuration for data collection
├── 02-ior-bench                    --> I/O performance benchmark case of study
├── 03-llm-inference                --> LLM inference case of study
├── 04-data-etl                     --> Data Extraction, Transformation, and Loading pipeline
└── README.md                       --> This file
```


Notes:
- The istance of QuestDB used to ingestion in all the data the identical to the one deployed in the `00-tsdb-bench` directory, so the configuration and deployment instructions are the same.


# TODOs:

- [ ] 02-ior-bench:
  - [ ] Aggiungere i notebook sistemati con il post-process dei dati
- [ ] 03-llm-inference:
  - [ ] tutto
- [ ] 04-data-etl:
  - [ ] tutto (prednere da scratch orfeo)
