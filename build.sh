#!/usr/bin/env bash

export http_proxy=http://0.0.0.0:3142/
docker build -t ghcr.io/trenchboot/trenchboot-sdk:latest .
