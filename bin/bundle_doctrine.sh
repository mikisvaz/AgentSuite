#!/bin/env bash
mkdir -p doctrine_bundle/doctrines
cp doctrine scout society  doctrine_bundle/
for f in doctrines/*; do
  [ -f "$f" ] || continue
  cp "$f" doctrine_bundle/doctrines/
done
for a in */; do
  a="${a%/}"
  [ -f "$a/start_chat" ] || continue
  cp "$a/start_chat" "doctrine_bundle/$a.start_chat"
  [ -f "$a/README.md" ] && cp "$a/README.md" "doctrine_bundle/$a.README.md"
  [ -d "$a/doc" ] && cp  -R "$a/doc" "doctrine_bundle/$a.doc"
  [ -d "$a/skills" ] && cp  -R "$a/skills" "doctrine_bundle/$a.skills"
done
exit 0
