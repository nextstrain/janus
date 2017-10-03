#!/bin/bash
#
# Install janus requirements.

# Download and install miniconda for this operating system if conda is not on
# the current PATH.
if [[ -z "$(which conda)" ]]
then
    echo "Installing miniconda"

    if [[ "$(uname -s)" -eq "Darwin" ]]
    then
        CONDA_SCRIPT=Miniconda3-latest-MacOSX-x86_64.sh
    else
        CONDA_SCRIPT=Miniconda3-latest-Linux-x86_64.sh
    fi

    CONDA_DIR=$HOME/miniconda3
    wget https://repo.continuum.io/miniconda/$CONDA_SCRIPT
    bash $CONDA_SCRIPT -b -p $CONDA_DIR

    CONDA_BIN_DIR=$CONDA_DIR/bin
    PATH=$CONDA_BIN_DIR:$PATH

    # Clean up after installation.
    rm -f $CONDA_SCRIPT
else
    echo "miniconda already installed, skipping installation"
fi

# Create the miniconda Python 3 environment required to run janus.
conda env create -f envs/anaconda.python3.yaml

# Create the miniconda Python 2 environment required to run fauna and augur.
conda env create -f envs/anaconda.python2.yaml
source activate janus_python2
CONDA_BIN_DIR=$(dirname `which conda`)
rm -f ${CONDA_BIN_DIR}/raxml ${CONDA_BIN_DIR}/fasttree
ln -s ${CONDA_BIN_DIR}/raxmlHPC-PTHREADS ${CONDA_BIN_DIR}/raxml
ln -s ${CONDA_BIN_DIR}/FastTree ${CONDA_BIN_DIR}/fasttree
