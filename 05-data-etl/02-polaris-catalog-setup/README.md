# Polaris catalog setup

Once the polaris instance is deployed in the cluster, before being able to use it as a data catalog for the data collected from the infrastructure, it is needed to be configured. 

All the configuration is done leveraging the REST API provided by Polaris Catalog, so all the configuration is done through a series of `curl` commands.

In particular, the configuration is divided in two main steps:

```bash
./01-create-catalog.sh
./02-create-account-and-rbac.sh
```

In both of the scripts, there are some sensitive information (e.g. credentials, etc...) that must be replaced with the correct one before applying the configuration to the cluster or running the code, so all the file present in this folder must be considered as a template. All the TODOs are marked in the file with a `# <-- TODO: replace this` comment, so it should be easy to find and replace all the necessary information before applying the configuration to the cluster or running the code.