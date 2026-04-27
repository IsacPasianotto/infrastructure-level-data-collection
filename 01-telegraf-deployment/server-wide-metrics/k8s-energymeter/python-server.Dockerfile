# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: CC-BY-4.0

FROM python:3.14.3-slim-trixie

LABEL maintainer="Orfeo Operations <orfeo.operations@areasciencepark.it>"

# copy the src directory
COPY src-py/ /app/
COPY requirements.txt /app/requirements.txt

WORKDIR /app

RUN pip install --no-cache-dir -r /app/requirements.txt

ENTRYPOINT ["/bin/bash"]
CMD ["/app/entrypoint.sh"]
