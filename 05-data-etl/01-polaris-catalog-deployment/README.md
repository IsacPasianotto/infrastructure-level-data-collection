<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# Polaris catalog Kubernetes deployment

This folder contains all the code used to deploy an apache polaris catalog on a bare-metal Kubernetes cluster, with the aim of using it as a data catalog for the data collected from the infrastructure.

All the file present in this folder must be considered as a template, since there are some sensitive information (e.g. credentials, etc...) that must be replaced with the correct one before applying the configuration to the cluster. Other than that also the `StorageClass` can vary across different cluster, so it should be edited. 

All the TODOs are marked in the file with a `# <-- TODO: replace this` comment, so it should be easy to find and replace all the necessary information before applying the configuration to the cluster.