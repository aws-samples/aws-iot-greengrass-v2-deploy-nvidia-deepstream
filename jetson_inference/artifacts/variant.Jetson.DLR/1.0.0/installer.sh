#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# This script installs the correct Sagemaker NEO DLR for your NVIDIA Jetson Device
set -eux

##############  Common  ####################
# Install python3 libraries such as numpy and opencv.
install_python3_libraries() {
      # Check if opencv already exists on the machine. Otherwise, install it.
    opencv=$(python3 -c "$get_opencv_version_command")
    pip3 install demjson
    pip3 install awsiotsdk
    if [[ "$opencv" == *"No module named 'cv2'"* ]]; then
        echo "Installing opencv..."
        pip3 install scikit-build
        pip3 install opencv-python
    else
        echo "Skipping opencv installation as it already exists."
    fi
    # Check if numpy already exists on the machine. Otherwise, install it.
    numpy=$(python3 -c "$get_numpy_version_command")
    if [[ "$numpy" == *"No module named 'numpy'"* ]]; then
        echo "Installing numpy..."
        pip3 install numpy
    else
        echo "Skipping numpy installation as it already exists."
    fi
}



##############  debian  ####################
# Check if python3 already exists on the machine. Otherwise, install it.
install_py3_debian() {
    if [[ "$(version $python_version)" -ge "$(version $min_py_version)" ]] && [[ "$python_version" != *"command not found"* ]]; then
        echo "Skipping python3 installation as it is already installed"
    else
        echo "Installing python3..."
        sudo apt-get install -y python3 python3-distutils
    fi
    install_pip3_debian
}
# Check if pip3 already exists on the machine. Otherwise, install it.
install_pip3_debian() {
    if [[ "$(version $pip3_version)" -ge "$(version $min_pip_version)" ]] && [[ "$pip3_version" != *"command not found"* ]]; then
        echo "Skipping pip3 installation as it is already installed"
    else
        echo "Installing pip3..."
        sudo apt-get install -y python3-pip
        pip3 install -U pip setuptools wheel
    fi
}
# Install python3, pip3, setuptools, utils and wheel packages for debian on architectures other than x86_64 inside a venv.
# Install libraries needed for building from source such as git, cmake and build-essential.
install_libraries_debian() {
    install_py3_debian
    sudo apt install git libatlas-base-dev -y
    #echo "Setting up Python virtual environment..."
    #setup_venv
    install_python3_libraries
}


version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}
################ debian-end ####################
################  utils  #####################
get_dlr_version_command=$(
    cat <<END
try:
    import dlr
    print(dlr.__version__)
except Exception as e:
    print(e)
END
)
get_opencv_version_command=$(
    cat <<END
try:
    import cv2
    print(cv2.__version__)
except Exception as e:
    print(e)
END
)
get_numpy_version_command=$(
    cat <<END
try:
    import numpy as np
    print(np.__version__)
except Exception as e:
    print(e)
END
)
# disable metrics data collection feature of amazon (DLR version >= 1.4.0)
disable_metric_collection_command=$(
    cat <<END
try:
    import dlr
    version = dlr.__version__
    if int(version.replace(".","")) >= 140 :
        from dlr.counter.phone_home import PhoneHome
        PhoneHome.disable_feature()
except Exception as e:
    print(e)
END
)
clone_repo() {
    if [[ -d $(dirname $(realpath $0))/"$dlr_directory" ]]; then
        echo "Removing the existing directory of the neo-ai-dlr repo.."
        sudo rm -rf $(dirname $(realpath $0))/"$dlr_directory"
    fi
    git clone --recursive https://github.com/neo-ai/"$dlr_directory"
    cd "$dlr_directory"
    git checkout release-"$dlr_version"
    git submodule update --init --recursive
    mkdir build
    cd build
}
check_dlr() {
    machine="${1}"
    get_dlr_version=$(python3 -c "$get_dlr_version_command")
    if [[ "$get_dlr_version" == "$dlr_version" ]]; then
        return 0
    else
        return 1
    fi
}

is_debian() {
    debian=$(sudo apt-get -v &>/dev/null && echo "apt-get")
    if [[ "$debian" == "apt-get" ]]; then
        return 0
    else
        return 1
    fi
}

################ utils-end ###################
# Get the parameters
while getopts ":a:p:e:" opt; do
    case $opt in
    a)
        accelerator="$OPTARG"
        ;;
    p)
        ml_root_path="$OPTARG"
        ;;
    e)
        environment_file="$OPTARG"
        ;;
    \?)
        echo "Invalid option -$OPTARG" >&2
        ;;
    esac
done
kernel=$(uname -s)
dlr_version="1.3.0"
min_py_version="3.0.0"
dlr_directory="neo-ai-dlr"
min_kernel_version="4.9.9"
min_pip_version="20.2.4"
machine=$(uname -m)
jetsonGPU=0
if [ -e /sys/module/tegra_fuse/parameters/tegra_chip_id ]
then
    jetsonGPU=$(cat /sys/module/tegra_fuse/parameters/tegra_chip_id)
    echo "Jetson Detected GPU ID ${jetsonGPU}"
else
    echo "Jetson Not Detected"
fi

python_version=$(echo $(python3 --version) | cut -d' ' -f 2)
pip3_version=$(echo $(pip3 --version) | cut -d' ' -f 2)
if [[ "$accelerator" == "gpu" ]]; then
    case "$kernel" in
    "Linux")
        if is_debian; then
            sudo apt install wget -y
            if check_dlr "$machine"; then
                echo "Skipping DLR installation as it already exists."
            else
                    install_libraries_debian
                    if [[ "$machine" == "aarch64" ]]; then
		        if [[ "$jetsonGPU" != "0" ]]; then
                          echo "Installing Jetson DLR for GPU ID $jetsonGPU"
                          pip3 install https://neo-ai-dlr-release.s3-us-west-2.amazonaws.com/v1.7.0/jetpack4.4/dlr-1.7.0-py3-none-any.whl
			fi
                    fi
            fi
        fi
    ;;
    esac
else
  echo "No Jetson GPU Detected, this installation is only for Jetson Devices with Jetpack 4.4+ exiting.."
fi
