#!/bin/bash
#
# Install janus requirements.

# Download and install miniconda.
CONDA_SCRIPT=Miniconda3-latest-Linux-x86_64.sh
CONDA_DIR=$HOME/miniconda3
wget https://repo.continuum.io/miniconda/$CONDA_SCRIPT
bash $CONDA_SCRIPT -b -p $CONDA_DIR

# Create the miniconda Python 3 environment required to run janus.
CONDA_BIN_DIR=$CONDA_DIR/bin
PATH=$CONDA_BIN_DIR:$PATH
conda env create -f envs/anaconda.python3.yaml

# Create the miniconda Python 2 environment required to run fauna and augur.
conda env create -f envs/anaconda.python2.yaml
source activate janus_python2
CONDA_BIN_DIR=$(dirname `which conda`)
ln -s ${CONDA_BIN_DIR}/raxmlHPC ${CONDA_BIN_DIR}/raxml
ln -s ${CONDA_BIN_DIR}/FastTree ${CONDA_BIN_DIR}/fasttree

# Clean up after installation.
rm -f $CONDA_SCRIPT
