<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# IOR compilation

In order to build IOR, with parallel HDF5 support, we need to first build HDF5 with the right options.
This is the logbook of the process to getting ready to run the benchmarks on Orfeo.


#### Step 0:

Request the resources (this part is ORFEO-specific, but the rest of the process should be similar on any HPC cluster) and load the needed modules.

```bash
srun -p THIN -A lade --cpus-per-task=8 --tasks-per-node=1 --mem=32G --time=02:00:00 --pty /bin/bash
module load openMPI/5.0.5
```

#### Step 1: Compile HDF5

Clone the repository:

```bash
cd $HOME/src
git clone --depth=1 git@github.com:HDFGroup/hdf5.git -b hdf5_1.14.6 --single-branch hdf5
cd hdf5
```

The [official docs](https://github.com/HDFGroup/hdf5/blob/develop/release_docs/README_HPC.md) suggest to use `cmake` to build HDF5, so we will follow that approach.

```bash
mkdir build && cd build
# ! Be very careful to not add extra spaces here!
cmake3 -DCMAKE_C_COMPILER=mpicc \
      -DCMAKE_Fortran_COMPILER=mpif90 \
      -DHDF5_ENABLE_PARALLEL=ON \
      -DHDF5_ENABLE_SUBFILING_VFD=ON \
      -DBUILD_TESTING=ON \
      ..

cmake3 --build . --config Release
cmake3 --install . --prefix ${HOME}/.local/hdf5/1.14.6
```

Then create a file at `${HOME}/.local/modules/hdf5/1.14.6.lua` with [this content](./modules/hdf5-1.14.6.lua) to be able to load the module in the future.

#### Step 2: Compile IOR

Load the previously built module:

```bash
module load hdf5/1.14.6
```

Then clone the repository:

```bash
cd $HOME/src
git clone --depth=1 https://github.com/hpc/ior.git -b 4.0.0 --single-branch ior
cd ior
```

And build it:

```bash
./bootstrap
export HDF5_CFLAGS="-I${HDF5_HOME}/include"
export HDF5_LIBS="-L${HDF5_HOME}/lib -lhdf5"

./configure --with-mpiio --with-posix --with-cephfs \
            --with-hdf5 \
            CC=mpicc \
            CFLAGS="${HDF5_CFLAGS}" \
            LDFLAGS="${HDF5_LIBS}"

make -j 8
make install prefix=${HOME}/.local/ior/4.0.0
```
And again, create a module file at `${HOME}/.local/modules/ior/4.0.0.lua` with [this content](./modules/ior-4.0.0.lua) to be able to load the module in the future.

