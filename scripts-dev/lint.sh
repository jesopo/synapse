#!/usr/bin/env bash
#
# Runs linting scripts over the local Synapse checkout
# isort - sorts import statements
# black - opinionated code formatter
# flake8 - lints and finds mistakes

set -e

usage() {
  echo
  echo "Usage: $0 [-h] [-d] [paths...]"
  echo
  echo "-d"
  echo "  Lint files that have changed since the last git commit."
  echo
  echo "  If paths are provided and this option is set, both provided paths and those"
  echo "  that have changed since the last commit will be linted."
  echo
  echo "  If no paths are provided and this option is not set, all files will be linted."
  echo
  echo "  Note that paths with a file extension that is not '.py' will be excluded."
  echo "-h"
  echo "  Display this help text."
}

USING_DIFF=0
files=()

while getopts ":dh" opt; do
  case $opt in
    d)
      USING_DIFF=1
      ;;
    h)
      usage
      exit
      ;;
    \?)
      echo "ERROR: Invalid option: -$OPTARG" >&2
      usage
      exit
      ;;
  esac
done

# Strip any options from the command line arguments now that
# we've finished processing them
shift "$((OPTIND-1))"

if [ $USING_DIFF -eq 1 ]; then
  # Check both staged and non-staged changes
  for path in $(git diff HEAD --name-only); do
    filename=$(basename "$path")
    file_extension="${filename##*.}"

    # If an extension is present, and it's something other than 'py',
    # then ignore this file
    if [[ -n ${file_extension+x} && $file_extension != "py" ]]; then
      continue
    fi

    # Append this path to our list of files to lint
    files+=("$path")
  done
fi

# Append any remaining arguments as files to lint
files+=("$@")

if [[ $USING_DIFF -eq 1 ]]; then
  # If we were asked to lint changed files, and no paths were found as a result...
  if [ ${#files[@]} -eq 0 ]; then
    # Then print and exit
    echo "No files found to lint."
    exit 0
  fi
else
  # If we were not asked to lint changed files, and no paths were found as a result,
  # then lint everything!
  if [[ -z ${files+x} ]]; then
      # CI runs each linter on the entire checkout, e.g. `black .`. So don't
      # rely on this list to *find* lint targets if that misses a file; instead;
      # use it to exclude files from linters when this can't be done by config.
      #
      # To check which files the linters examine, use:
      #     black --verbose . 2>&1 | \grep -v ignored
      #     isort --show-files .
      #     flake8 --verbose .  # This isn't a great option
      #     mypy has explicit config in mypy.ini; there is also mypy --verbose
      files=(
          "synapse" "docker" "tests"
          "scripts-dev"
          "contrib" "setup.py" "synmark" "stubs" ".ci"
      )
  fi
fi

echo "Linting these paths: ${files[*]}"
echo

# Print out the commands being run
set -x

isort "${files[@]}"
python3 -m black "${files[@]}"
./scripts-dev/config-lint.sh
flake8 "${files[@]}"
mypy
