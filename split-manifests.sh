#!/bin/bash

set -e

usage() {
  echo "Usage: $0 [-f input_file] [-d target_directory]"
  echo "  -f: Path to k8s manifest file (default: manifests.yaml)"
  echo "  -d: Target directory for split files (default: ./split-manifests)"
  exit 1
}

INPUT_FILE="manifests.yaml"
TARGET_DIR="./split-manifests"

while getopts "f:d:" opt; do
  case $opt in
    f) INPUT_FILE="$OPTARG" ;;
    d) TARGET_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done

if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file $INPUT_FILE does not exist!"
  usage
fi

mkdir -p "$TARGET_DIR"

awk -v outdir="$TARGET_DIR" '
  function sanitize(str) {
    gsub("[^a-zA-Z0-9_-]", "_", str)
    return str
  }
  BEGIN {
    kind="unknown"
    name="unnamed"
    file_open=0
  }
  /^---/ {
    if (file_open) close(outfile)
    kind="unknown"
    name="unnamed"
    next
  }
  /^kind:/ {
    # Handles: kind: Deployment
    kind=$2
    # or: kind: "Deployment"
    gsub(/^kind:[ \t"]*/, "", $0)
    split($0, karr, /[ \t:"]+/)
    kind=karr[2]
    kind=sanitize(kind)
  }
  /^  name:/ {
    # Handles:   name: my-app
    gsub(/^[ \t]*name:[ \t"]*/, "", $0)
    split($0, narr, /[ \t:"]+/)
    name=narr[2]
    name=sanitize(name)
  }
  /^metadata:/ {
    in_metadata=1
    next
  }
  (in_metadata && /^  name:/) {
    gsub(/^[ \t]*name:[ \t"]*/, "", $0)
    split($0, narr, /[ \t:"]+/)
    name=narr[2]
    name=sanitize(name)
    in_metadata=0
  }
  {
    if (!file_open) {
      outfile = sprintf("%s/%s-%s.yaml", outdir, kind, name)
      file_open=1
    }
    print >> outfile
  }
  END {
    if (file_open) close(outfile)
  }
' "$INPUT_FILE"

echo "Split $INPUT_FILE into $TARGET_DIR/{kind}-{name}.yaml files."