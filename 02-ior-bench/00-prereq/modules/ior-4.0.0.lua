-- -*- lua -*-

local name      = "IOR"
local version   = "4.0.0"
whatis("Name         : " .. name)
whatis("Version      : " .. version)
whatis("Description  : IOR and mdtest benchmarks for parallel I/O")

-- IOR richiede MPI e HDF5
depends_on("openMPI/5.0.5")
depends_on("hdf5/1.14.6")

-- Directory di installazione
local home = os.getenv("HOME") .. "/.local/ior/" .. version

-- Aggiungi i path
prepend_path("PATH", home .. "/bin")

-- Variabili d'ambiente utili
setenv("IOR_HOME", home)

-- Messaggio informativo
if (mode() == "load") then
    LmodMessage("Loaded " .. name .. " " .. version)
    LmodMessage("Available commands: ior, mdtest, md-workbench")
end