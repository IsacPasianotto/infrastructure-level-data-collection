# Data ETL (Extraction, Transformation, Loading) pipeline

In this folder is contained all the code related to the data ETL pipeline. 

In fact, even if a dataset is provided in through the `../02-get-data.sh` script and Zenodo records, with the deployment presented in the `../01-telegraf-deployment` it is possible to continuously collect data from the infrastructure and store it into QuestDB, hence the needing of a data ETL pipeline to automatically extract data and load it into a data catalog (e.g. Polaris Catalog) for later analysis and use in the case of study.

***NOTE:*** Many of the code and configuration present in this folder was anonymized and sanitized to remove any sensitive information (e.g. credentials, etc...) before being commited to the repository, so all the file present in this folder must be considered as a template, since there are some sensitive information that must be replaced with the correct one before applying the configuration to the cluster or running the code.

##  Directory Structure:

TBD.
```
.
├── 01-polaris-catalog-deployment       --> Polaris Catalog deployment in Kubernetes
├── 02-polaris-catalog-setup            --> Polaris Catalog configuration with REST API
├── 03-get-data-from-questdb.sh         --> Script to extract data from QuestDB and store it in Parquet format
├── 04-load-data                        --> Script to load data from Parquet files into Polaris Catalog
├── 05-query-catalog-example            --> Jupyter notebook with example of how to query the data stored in Polaris Catalog
└── README.md                           --> This file
```