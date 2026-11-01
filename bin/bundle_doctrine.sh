#!/bin/env bash
cp doctrine scout society  doctrine_bundle/
mkdir -p doctrine_bundle/doctrines
cp doctrines/*  doctrine_bundle/doctrines/
for a in *; do cp $a/start_chat doctrine_bundle/$a.start_chat; done
for a in *; do cp $a/README.md doctrine_bundle/$a.README.md; done
