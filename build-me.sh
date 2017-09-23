#!/bin/sh
PACKER_KEY_INTERVAL=10ms PACKER_LOG=1 CHECKPOINT_DISABLE=1 packer build obsd-build.json
