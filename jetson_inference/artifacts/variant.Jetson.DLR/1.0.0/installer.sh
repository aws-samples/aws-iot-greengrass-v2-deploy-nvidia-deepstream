#!/bin/bash
set -eux

##############  Common  ####################
# Install python3 libraries such as numpy and opencv.
install_python3_libraries() {
      # Check if opencv already exists on the machine. Otherwise, install it.
    opencv=$(python3 -c "$get_opencv_version_command")
    if [[ "$opencv" == *"No module named 'cv2'"* ]]; then
        echo "Installing opencv..."
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

##Setup a venv for all python library installations on armv7l due to limited conda support
setup_venv() {
  if [ ! -d "${ml_root_path}/greengrass_ml_dlr_venv" ]; then
    #If the venv does not exist already, create it
    python3 -m venv ${ml_root_path}/greengrass_ml_dlr_venv
  fi
  source ${ml_root_path}/greengrass_ml_dlr_venv/bin/activate
  cd ${ml_root_path}/greengrass_ml_dlr_venv
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
    sudo apt install git libatlas-base-dev python3-venv -y
    echo "Setting up Python virtual environment..."
    setup_venv
    install_python3_libraries
}

#For x86_64, download and install miniconda and create a miniconda environment from a provided `environment.yaml`
#argument with all necessary dependencies required by DLR
#This environment will be activated immediately after creation so that when DLR is installed afterwards, it will only
#exist inside this environment
install_conda_x86_64() {
    #Check if we have already installed and set up conda on this device; if so, skip the installation
    if [ -d "${ml_root_path}/greengrass_ml_dlr_conda" ]; then
      return 0
    fi
    environment_file="${1}"

    wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" -O "${ml_root_path}/miniconda.sh"
    bash "${ml_root_path}/miniconda.sh" -b -p "${ml_root_path}/greengrass_ml_dlr_conda"
    rm "${ml_root_path}/miniconda.sh"

    export PATH="${ml_root_path}/greengrass_ml_dlr_conda/bin:$PATH"
    #See https://github.com/conda/conda/issues/7980 for an explanation of the below line
    eval "$(${ml_root_path}/greengrass_ml_dlr_conda/bin/conda shell.bash hook)"
    conda env create -f $environment_file
    conda activate greengrass_ml_dlr_conda

    #Uncomment to make `awscam` accessible inside conda for AWS Deeplens (use with caution)
    #sudo ln -s /usr/lib/python3/dist-packages/awscam "${ml_root_path}/greengrass_ml_dlr_conda/envs/greengrass_ml_dlr_conda/lib/python3.7/site-packages/"
    #sudo ln -s /usr/lib/python3/dist-packages/awscamdldt.so "${ml_root_path}/greengrass_ml_dlr_conda/envs/greengrass_ml_dlr_conda/lib/python3.7/site-packages/"
}

version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}
################ debian-end ####################
################## centos ######################
install_py3_centos() {
    if [[ "$python_version" == *"command not found"* || "$python_version" < "$min_py_version" ]]; then
        echo "Installing python3..."
        sudo yum install -y python37
    else
        echo "Skipping python3 installation as it already exists..."
    fi
    install_pip3_centos
    echo "Setting up Python virtual environment..."
    setup_venv
}
# Check if pip3 already exists on the machine. Otherwise, install it.
install_pip3_centos() {
    if [[ "$pip3_version" == *"command not found"* || -z "$pip3_version" ]]; then
        echo "Installing pip3..."
        sudo yum install curl
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python3 get-pip.py
        rm get-pip.py
        pip3 install -U setuptools wheel
    else
        pip3 install -U pip setuptools wheel
    fi
}

install_libraries_centos() {
    install_python3_libraries
    sudo yum install mesa-libGL -y
}

################ centos-end ####################
##################  darwin  ####################
install_libraries_darwin() {
    install_brew_darwin
    install_cmake_darwin
    install_gcc_darwin
}
install_cmake_darwin() {
    if [ -z "$(cmake --version)" ]; then
        echo "Installing cmake..."
        brew install cmake
    fi
}
install_gcc_darwin() {
    if [ -z "$(gcc --version)" ]; then
        echo "Installing gcc@8..."
        brew install gcc@8
    fi
}
install_brew_darwin() {
    if [ -z "$(brew --version)" ]; then
        echo "Installing brew..."
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh
        export PATH="/usr/local/opt/python/libexec/bin:$PATH"
    fi
}
############### darwin-end #####################
################  windows  #####################
################ windows-end ###################
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
    jetsonGPU=
    if [[ "$machine" == "x86_64" ]]; then
      #Activate the conda environment before we check the DLR installation (x86_64)
      if [ -d "${ml_root_path}/greengrass_ml_dlr_conda" ]; then
        #Activate conda
        export PATH="${ml_root_path}/greengrass_ml_dlr_conda/bin:$PATH"
        #See https://github.com/conda/conda/issues/7980 for an explanation of the below line
        eval "$(${ml_root_path}/greengrass_ml_dlr_conda/bin/conda shell.bash hook)"
        conda activate greengrass_ml_dlr_conda
      else
        return 1
      fi
    else
      #Activate the venv environment before we check the DLR installation (other platforms)
      if [ -d "${ml_root_path}/greengrass_ml_dlr_venv" ]; then
        #Activate venv
        source ${ml_root_path}/greengrass_ml_dlr_venv/bin/activate
      else
        return 1
      fi
    fi

    get_dlr_version=$(python3 -c "$get_dlr_version_command")
    if [[ "$get_dlr_version" == "$dlr_version" ]]; then
        return 0
    else
        return 1
    fi
}
make_and_install() {
    make -j"$(($(nproc) + 1))"
    cd ../python
    python3 setup.py install
}
remove_cloned_directory() {
    current_path=$(dirname $(realpath $0))
    if [[ "$current_path" == *"$dlr_directory"* ]]; then
        arr=(${current_path//"$dlr_directory"/ })
        sudo rm -rf ${arr[0]}"$dlr_directory"
    else
        sudo rm -rf "$dlr_directory"
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
is_centos() {
    centos_yum=$(type yum &>/dev/null && echo "yum")
    if [[ "$centos_yum" == "yum" ]]; then
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
if [[ "$accelerator" == "cpu" ]]; then
    case "$kernel" in
    "Linux")
        if is_debian; then
            sudo apt install wget -y
            if check_dlr "$machine"; then
                echo "Skipping DLR installation as it already exists."
            else
                if [[ "$machine" == "x86_64" ]]; then
                    echo "Installing Miniconda and creating virtual environment..."
                    install_conda_x86_64 "$environment_file"
                    echo "Installing DLR..."
                    pip3 install dlr=="$dlr_version"
                else
                    install_libraries_debian
                    if [ "$machine" == "armv7l" ]; then
                        echo "Installing Raspberry Pi 3+/4 DLR..."
                        pip3 install https://neo-ai-dlr-release.s3-us-west-2.amazonaws.com/v1.3.0/pi-armv7l-raspbian4.14.71-glibc2_24-libstdcpp3_4/dlr-1.3.0-py3-none-any.whl
                    else
                        if ["$machine" == "aarch64" ] && ["$jetsonGPU" != "0"]; then
                            echo "Installing Jetson DLR for GPU ID $jetsonGPU"
                            pip3 install https://neo-ai-dlr-release.s3-us-west-2.amazonaws.com/v1.7.0/jetpack4.4/dlr-1.7.0-py3-none-any.whl
                        else
                            echo "Installing DLR from source..."
                            sudo apt-get install -y build-essential cmake ca-certificates git
                            clone_repo
                            cmake ..
                            make_and_install
                        fi
                    fi

                fi
            fi
        elif is_centos; then
            if check_dlr "$machine"; then
                echo "Skipping DLR installation as it already exists."
            else
                if [[ "$machine" == "x86_64" ]]; then
                    echo "Installing Miniconda and creating virtual environment..."
                    install_conda_x86_64 "$environment_file"
                    install_libraries_centos
                    echo "Installing DLR..."
                    pip3 install dlr=="$dlr_version"
                else
                    install_py3_centos
                    install_libraries_centos
                    echo "Installing DLR from source..."
                    sudo yum install -y cmake3 ca-certificates git gcc-c++ gcc make
                    clone_repo
                    cmake3 ..
                    make_and_install
                fi
            fi

        fi
        ;;
    "Darwin")
        install_libraries_darwin
        if check_dlr "$machine"; then
            echo "Skipping DLR installation as it already exists."
        else
            echo "Installing Miniconda and creating virtual environment..."
            install_conda_x86_64 "$environment_file"
            echo "Installing DLR..."
            clone_repo
            CC=gcc-8 CXX=g++-8 cmake ..
            make_and_install
        fi
        ;;
    "Windows")
        echo "Install like Windows..."
        ;;
    esac
fi
