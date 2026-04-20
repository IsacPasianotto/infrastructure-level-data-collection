-- -*- lua -*-
local name      = "HDF5"
local version   = "1.14.6"
whatis("Name         : " .. name)
whatis("Version      : " .. version)
whatis("Description  : HDF5 parallel library with MPI support")

-- HDF5 richiede MPI se compilato con supporto parallelo
depends_on("openMPI/5.0.5")

-- Directory di installazione
local home = os.getenv("HOME") .. "/.local/hdf5/" .. version

-- Aggiungi i path
prepend_path("PATH", home .. "/bin")
prepend_path("LD_LIBRARY_PATH", home .. "/lib")
prepend_path("LIBRARY_PATH", home .. "/lib")
prepend_path("PKG_CONFIG_PATH", home .. "/lib/pkgconfig")
prepend_path("CPATH", home .. "/include")
prepend_path("MANPATH", home .. "/share/man")

-- Variabili d'ambiente utili
setenv("HDF5_HOME", home)
setenv("HDF5_DIR", home)
setenv("HDF5_ROOT", home)