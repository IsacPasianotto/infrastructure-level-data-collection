<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# Query catalog example

This folder contains a simple example of how to query the catalog using the Python Iceberg client. The example is implemented in the `01-simple-query.ipynb` notebook, which can be run in a Jupyter environment.

Before running the notebook, make sure to create an (at least) read-only profile in iceberg.
An example, with some placeholder values is provided in the `00-create-read-only-user.sh` script, which will generate a `read-only-user-creds.env` file with all the needed information to connect to the catalog and run the notebook's cells.