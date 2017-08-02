#!/bin/bash

# Setup the environment.
PATH="$HOME/miniconda3/bin:$PATH"
source activate janus_python3

# Run multiple build jobs at a time on the cluster.
snakemake --use-conda -w 60 --cluster-config cluster.json --cluster "sbatch --nodes=1 --ntasks=1 --mem={cluster.memory} --cpus-per-task={cluster.cores} --tmp={cluster.disk} --time={cluster.time} --job-name='{cluster.name}' --output='{cluster.stdout}' --error='{cluster.stderr}'" $*
