FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

COPY clean-layer.sh /usr/local/bin/clean-layer.sh
RUN chmod +x /usr/local/bin/clean-layer.sh

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    vim \
    bzip2 \
    git \
    gnupg2 \
    curl \
    ca-certificates \
    nfs-common \
    awscli \
    rsyslog \
    lsof && \
    clean-layer.sh

# install node
RUN \
    curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://deb.nodesource.com/node_10.x bionic main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    clean-layer.sh


# required to make jupyter lab's terminal work properly
ENV SHELL=/bin/bash

COPY sandbox_env.yml /temp/sandbox.yml

# install miniconda
#ENV CONDA_VERSION=latest
ENV CONDA_VERSION=py37_4.8.2
ENV CONDA_DIR=/root/miniconda3
ENV CONDA_PYTHON_DIR=$CONDA_DIR/lib/python3.7
ENV PYTHON_VERSION=3.7

# Install miniconda3
RUN \
    wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-$CONDA_VERSION-Linux-x86_64.sh \
    -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm -f /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda config --add channels conda-forge && \
    # Update selected packages - install python 3.7.5
    $CONDA_DIR/bin/conda install -y --update-all python=$PYTHON_VERSION && \
    # Link Conda
    ln -s $CONDA_DIR/bin/python /usr/local/bin/python && \
    ln -s $CONDA_DIR/bin/conda /usr/bin/conda && \
    # Update pip
    $CONDA_DIR/bin/pip install --upgrade pip && \
    chmod -R a+rwx /usr/local/bin/  && \
    $CONDA_DIR/bin/conda init --all && \
    clean-layer.sh


# add nvidia repos
RUN \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list


ENV CUDA_VERSION=10.1.243

# this is the ubuntu package version
ENV CUDA_PKG_VERSION=10-1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN \
    apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-$CUDA_PKG_VERSION \
    cuda-compat-$CUDA_PKG_VERSION \
    cuda-libraries-$CUDA_PKG_VERSION \
    cuda-nvtx-$CUDA_PKG_VERSION && \
    apt-mark hold libnccl2 && \
    apt-mark hold libcudnn7 && \
    apt-get clean


RUN test -L /usr/local/cuda || ln -s cuda-10.1 /usr/local/cuda

RUN \
    echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility"
ENV NVIDIA_REQUIRE_CUDA="cuda>=10.1 brand=tesla,driver>=384,driver<385 brand=tesla,driver>=396,driver<397 brand=tesla,driver>=410,driver<411"

ENV NCCL_VERSION=2.4.8
ENV CUDNN_VERSION=7.6.4.38

ENV LD_LIBRARY_PATH=$CONDA_DIR/lib

RUN \
    $CONDA_DIR/bin/conda env update -n base -f /temp/sandbox.yml && \
    $CONDA_DIR/bin/conda install pytorch torchvision cudatoolkit=10.1 -c pytorch && \
    $CONDA_DIR/bin/conda install -c conda-forge jupytext && \
    $CONDA_DIR/bin/conda update -c conda-forge --all -y && \
    clean-layer.sh

RUN \
    $CONDA_DIR/bin/jupyter labextension update -y --all && \
    $CONDA_DIR/bin/jupyter labextension install @jupyter-widgets/jupyterlab-manager  --no-build && \
    $CONDA_DIR/bin/jupyter labextension install @jupyterlab/toc --no-build && \
    $CONDA_DIR/bin/jupyter labextension install jupyterlab-jupytext --no-build && \
    $CONDA_DIR/bin/jupyter labextension install qgrid --no-build && \
    clean-layer.sh && \
    $CONDA_DIR/bin/jupyter lab build

EXPOSE 8888

# setting NotebookApp.token to null disables tokens & passwords
CMD [ "jupyter-lab", "--ip=0.0.0.0", "--allow-root", "--NotebookApp.token=\"\"" ]

