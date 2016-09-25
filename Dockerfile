
# nextstrain/janus dockerfile

FROM ubuntu:14.04
MAINTAINER Trevor Bedford <trevor@bedford.io>
RUN apt-get -y update

# wget
RUN apt-get install -y wget

# git
RUN apt-get install -y git

# python
RUN apt-get install -y python python-dev python-pip python-virtualenv
RUN apt-get install -y python-numpy python-scipy
RUN apt-get install -y libpng-dev libfreetype6-dev pkg-config
RUN apt-get install -y libatlas-base-dev

# mafft
RUN apt-get install -y mafft

# fasttree
RUN apt-get install -y fasttree

# raxml
RUN apt-get install -y raxml
RUN cp /usr/bin/raxmlHPC /usr/bin/raxml

# python modules
RUN pip install rethinkdb==2.2.0.post2
RUN pip install biopython==1.68
RUN pip install geopy==1.11.0
RUN pip install cvxopt --user
RUN pip install DendroPy==3.12.0
RUN pip install boto==2.38.0
RUN pip install matplotlib==1.5.1
RUN pip install pandas==0.16.2
RUN pip install seaborn==0.6.0

# treetime
RUN git clone https://github.com/neherlab/treetime.git /TreeTime
WORKDIR /TreeTime/
RUN python setup.py install
WORKDIR /

# janus (with fauna and augur)
RUN git clone --recursive https://github.com/nextstrain/janus.git /janus
WORKDIR /janus

# update
ADD http://www.timeapi.org/utc/now /tmp/bustcache
RUN git pull
RUN git submodule update --recursive --remote

# default process
CMD /bin/bash
