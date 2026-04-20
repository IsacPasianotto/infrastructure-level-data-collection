# IOR benchmark case of study

***Step 0: Prerequisites***:  Follow the instructions in [this README](./00-prereq/README.md) to build the required dependencies (IOR) and create the corresponding modules.

***Step 1: Run the benchmark***

Edit the `*.ini` file in the `config` folder to match the configuration of your cluster (expecially the path where to write and read the files), then submit the job with:

```bash
sbatch sbatcher.sh
```
