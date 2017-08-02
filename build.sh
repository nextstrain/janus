#!/bin/bash

# Setup the environment.
source activate janus_python3

# Run multiple build jobs at a time on the cluster.
snakemake -w 60 -j 4 --cluster-config cluster.json --cluster "sbatch --nodes=1 --ntasks=1 --mem={cluster.memory} --cpus-per-task={cluster.cores} --tmp={cluster.disk} --time={cluster.time} --job-name='{cluster.name}' --output='{cluster.stdout}' --error='{cluster.stderr}'"
