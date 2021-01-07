# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# This script sets up the call to inference.py with the proper model for your NVIDIA Jetson Device

import os.path
from os import path
from os import system
from pathlib import Path
import sys
import demjson  #this is more tolerant of bad json
import subprocess



def exec_full(filepath):
    global_namespace = {
        "__file__": filepath,
        "__name__": "__main__",
    }
    with open(filepath, 'rb') as file:
        exec(compile(file.read(), filepath, 'exec'), global_namespace)

def main():
    jetsonGPU = 0
    print("argv[0]=",sys.argv[0])
    print("argv[1]=",sys.argv[1])
    print("argv[2]=",sys.argv[2])
    print("argv[3]=",sys.argv[3])
    models = demjson.decode(sys.argv[3])
    print("models=",str(models))
    print("argv[4]=",sys.argv[4])
    print("argv[5]=",sys.argv[5])
    print("argv[6]=",sys.argv[6])
    hostname = os.getenv("AWS_GG_NUCLEUS_DOMAIN_SOCKET_FILEPATH_FOR_COMPONENT")
    print("hostname=", hostname)
    print("env vars:", os.environ)
    print("svcid=", os.getenv("SVCUID"))
    if path.exists('/sys/module/tegra_fuse/parameters/tegra_chip_id'):
       jetsonGPU = Path('/sys/module/tegra_fuse/parameters/tegra_chip_id').read_text().rstrip()
       print("Found Jetson GPU id:",str(jetsonGPU))
       currentPath = sys.argv[0][:sys.argv[0].rindex("/")]
       print("Current path:",currentPath)
       inferenceCall = f"TVM_TENSORRT_CACHE_DIR=/tmp python3 {currentPath}/inference.py -a {sys.argv[1]} -m {sys.argv[2]}/resnet18_v1-jetson/{models[str(jetsonGPU)]} -p {sys.argv[4]} -i {sys.argv[5]} -s {sys.argv[6]}"
       print("Calling inference:",inferenceCall)
       p = subprocess.Popen(inferenceCall, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
       while p.poll() is None:
          line = p.stdout.readline()
          print(line)
          line = p.stderr.readline()
          print(line)
    else:
       print("Cannot identify Jetson device! Falling existing. This is intended only for NVIDIA Jetson Devices.")


if __name__ == "__main__":
    main()
