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
  function write_manifest(lines, kind, name, outdir) {
    kind = kind ? sanitize(kind) : "unknown"
    name = name ? sanitize(name) : "unnamed"
    file = outdir "/" kind "-" name ".yaml"
    print "Writing file: " file > "/dev/stderr"
    for (i=1; i<=lines; i++) {
      if (saved[i] ~ /^# Source:/)
        continue
      print saved[i] > file
    }
    close(file)
  }
  BEGIN {
    in_metadata = 0
    kind = ""
    name = ""
    saved_count = 0
    manifest_num = 0
  }
  /^---[ \t]*$/ {
    if (saved_count > 0) {
      write_manifest(saved_count, kind, name, outdir)
      kind = ""
      name = ""
      saved_count = 0
      in_metadata = 0
    }
    next
  }
  {
    saved_count++
    saved[saved_count] = $0
    if ($0 ~ /^[ ]*kind:[ ]*/) {
      sub(/^[ ]*kind:[ ]*"?/, "", $0)
      sub(/"$/, "", $0)
      kind = $0
    }
    else if ($0 ~ /^[ ]*metadata:[ ]*$/) {
      in_metadata = 1
    }
    else if (in_metadata && $0 ~ /^[ ]*name:[ ]*/) {
      sub(/^[ ]*name:[ ]*"?/, "", $0)
      sub(/"$/, "", $0)
      name = $0
      in_metadata = 0
    }
    else if ($0 !~ /^[ ]/ && in_metadata) {
      in_metadata = 0
    }
  }
  END {
    if (saved_count > 0) {
      write_manifest(saved_count, kind, name, outdir)
    }
  }
' "$INPUT_FILE"
