## Introduction

The nextstrain project is an attempt to make flexible informatic pipelines and visualization tools to track ongoing pathogen evolution as sequence data emerges. The nextstrain project derives from [nextflu](https://github.com/blab/nextflu), which was specific to influenza evolution.

nextstrain is comprised of four components:

* [fauna](https://github.com/nextstrain/fauna): database and IO scripts for sequence and serological data
* [augur](https://github.com/nextstrain/augur): informatic pipelines to conduct inferences from raw data
* [auspice](https://github.com/nextstrain/auspice): web app to visualize resulting inferences
* [janus](https://github.com/nextstrain/janus): build and deploy scripts

## Janus

*Definition: Roman god of beginnings and passages.*

This repo is intended to ease deployment of nextstrain instances. It's goal is to provide deploy scripts for augur builds.

## Docker commands

Build base Docker image

    docker build -t nextstrain/base:latest -f Dockerfile.base .

Push base image to hub

    docker push nextstrain/base:latest

Build janus Docker image

    docker build -t nextstrain/janus:latest .

Push janus image to hub

    docker push nextstrain/janus:latest

Run a shell from within the container

    docker run -t -i nextstrain/janus /bin/bash

Run a shell from within the container, including environment variables

    docker run -t -i --env-file environment_janus.env nextstrain/janus /bin/bash

## Testing

Enter shell

    docker run -t -i --env-file environment_janus.env nextstrain/janus /bin/bash

Build Zika

    python build.py

## Building with Snakemake

### Installation

Check out the code and branch.

```bash
git clone --recursive https://github.com/nextstrain/janus.git
cd janus
git checkout rhino-deploy
git submodule update --init --recursive
```

Download and install miniconda.

```bash
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b
```

Setup the Anaconda environment.

```bash
conda env create -f envs/anaconda.python3.yaml
```

Create symlinks for binaries with non-standard names.

```bash
export CONDA_BIN_DIR=$(dirname `which conda`)
ln -s ${CONDA_BIN_DIR}/raxmlHPC ${CONDA_BIN_DIR}/raxml
ln -s ${CONDA_BIN_DIR}/FastTree ${CONDA_BIN_DIR}/fasttree
```

### Usage

Export rethinkdb environment variables and load Anaconda environment. The
`environment_rethink.sh` script exists outside of version control and defines
variables for connecting to the RethinkDB.

```bash
# Setup the RethinkDB environment.
. environment_rethink.sh

# Setup the Python environment.
source activate janus_python3
```

Configure which viruses, lineages, and resolutions to build in
`config.json`. Perform a dry-run of the builds by printing the commands that
will be executed for the configuration.

```bash
snakemake -npq
```

If everything looks good, run builds on the cluster. For example, the following
command runs no more than 4 builds at a time.

```bash
snakemake -w 30 -j 4 --cluster-config cluster.json --cluster "sbatch --nodes=1 --ntasks=1 --mem={cluster.memory} --cpus-per-task={cluster.cores} --tmp={cluster.disk} --time={cluster.time} --job-name='{cluster.name}' --output='{cluster.stdout}' --error='{cluster.stderr}'"
```

Alternately, jobs can be submitted using the DRMAA interface as follows.

```bash
snakemake -w 30 -j 4 --cluster-config cluster.json --drmaa " --nodes=1 --ntasks=1 --mem={cluster.memory} --cpus-per-task={cluster.cores} --tmp={cluster.disk} --time={cluster.time}" --jobname "{rulename}.{jobid}.sh"
```

By default, all augur builds defined in `config["builds"]` will be built locally
and not synced to S3. Use the `push` rule to build one or more specific viruses
and push them to S3. Note that the AWS CLI expects credentials to be defined in
`~/.aws/credentials` under the profile `nextstrain`.

The following command builds seasonal flu, Zika, and Ebola files and pushes the
corresponding auspice output to the development data bucket on S3. A
`cloudfront` argument can be added to create an invalidation request for the
corresponding development CloudFront account (e.g., `cloudfront=dev`).

```bash
# Build all flu, zika, and ebola sites and push their JSONs to the development
# S3 bucket.
snakemake push --config builds="flu,zika,ebola" s3_bucket=nextstrain-dev-data
```

Use the `clean` rule to delete prepared, processed, and auspice files from one
or more builds.

```bash
snakemake clean --config builds="flu,zika,ebola"
```

## License and copyright

Copyright 2016 Trevor Bedford.

Source code to nextstrain is made available under the terms of the [GNU Affero General Public License](LICENSE.txt) (AGPL). nextstrain is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.
