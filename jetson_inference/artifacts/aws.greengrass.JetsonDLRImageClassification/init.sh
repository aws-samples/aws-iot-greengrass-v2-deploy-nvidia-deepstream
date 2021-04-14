#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -ex

sampleImagePath=$1
mlRootPath=$2

if [[ ! -d $mlRootPath/images ]]; then
      mkdir -p $mlRootPath/images
fi

if [[ ! -d $mlRootPath/inference_log ]]; then
      mkdir -p $mlRootPath/inference_log
fi

cp -r "$sampleImagePath"/* $mlRootPath/images