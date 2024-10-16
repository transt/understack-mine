#!/bin/bash

# ubuntu version
export DIB_RELEASE=noble

# devuser element - https://github.com/openstack/diskimage-builder/tree/master/diskimage_builder/elements/devuser

diskimage-builder keekz-ubuntu-extras.yaml
