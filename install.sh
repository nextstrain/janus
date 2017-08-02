#!/bin/bash
#
# Install janus requirements.

# Download and install miniconda.
CONDA_SCRIPT=Miniconda3-latest-Linux-x86_64.sh
CONDA_DIR=$HOME/miniconda3
wget https://repo.continuum.io/miniconda/$CONDA_SCRIPT
bash $CONDA_SCRIPT -b -p $CONDA_DIR

# Create the miniconda environment required to run janus.
CONDA_BIN_DIR=$CONDA_DIR/bin
PATH=$CONDA_BIN_DIR:$PATH
conda env create -f envs/anaconda.python3.yaml

ln -s ${CONDA_BIN_DIR}/raxmlHPC ${CONDA_BIN_DIR}/raxml
ln -s ${CONDA_BIN_DIR}/FastTree ${CONDA_BIN_DIR}/fasttree

# Clean up after installation.
rm -f $CONDA_SCRIPT
