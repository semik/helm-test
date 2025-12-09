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
  exit 2
fi

mkdir -p "$TARGET_DIR"

awk -v outdir="$TARGET_DIR" '
  function sanitize(str) {
    gsub("[^a-zA-Z0-9_-]", "_", str)
    return str
  }
  function flush() {
    if (file_open) {
      close(outfile)
      file_open=0
    }
  }
  BEGIN {
    kind="unknown"; name="unnamed"; in_metadata=0; file_open=0;
  }
  /^---/ {
    flush(); kind="unknown"; name="unnamed"; in_metadata=0; next;
  }
  /^[ ]*kind:[ ]*/ {
    # kind can be: kind: Something or kind: "Something"
    sub(/^[ ]*kind:[ ]*"?/, "", $0)
    sub(/"$/, "", $0)
    kind=sanitize($0)
    next
  }
  /^[ ]*metadata:[ ]*$/ {
    in_metadata=1
    next
  }
  (in_metadata && /^[ ]*name:[ ]*/) {
    # name can be: name: foo or name: "foo"
    sub(/^[ ]*name:[ ]*"?/, "", $0)
    sub(/"$/, "", $0)
    name=sanitize($0)
    in_metadata=0
    next
  }
  NF {
    if (!file_open) {
      outfile = sprintf("%s/%s-%s.yaml", outdir, kind, name)
      file_open=1
    }
    print >> outfile
  }
  END { flush() }
' "$INPUT_FILE"

echo "Split $INPUT_FILE into $TARGET_DIR/{kind}-{name}.yaml files."