#!/bin/bash
set -ex

# --- Function to process package.resolved ---
process_package_resolved() {

  if [ -e "$PACKAGE_RESOLVED_FILE" ]; then
    echo "Processing '$PACKAGE_RESOLVED_FILE'"
  else
    echo "'$PACKAGE_RESOLVED_FILE' is either not a regular file or it doesn't exist. Skipping process package resolved."
    return
  fi

  jq -r '.pins[] | [.identity, .state.version, .state.version, .location, "SPM"] | @csv' "$PACKAGE_RESOLVED_FILE"
}

# --- Function to process swift-outdated output ---
process_swift_outdated() {

  if [ -e "$PACKAGE_RESOLVED_FILE" ]; then
    echo "Process swift outdated for '$PACKAGE_RESOLVED_FILE'"
  else
    echo "'$PACKAGE_RESOLVED_FILE' is either not a regular file or it doesn't exist. Skipping process swift outdated."
    return
  fi

  swift-outdated --format json $PACKAGE_RESOLVED_DIR > "$OUTPUT_JSON"

  jq -r '.outdatedPackages[] | [.package, .currentVersion, .latestVersion, .url, "SPM"] | @csv' "$OUTPUT_JSON"
}

# --- Function to process pod outdated output ---
process_pod_outdated() {

  POD_FILE=$PROJECT_SOURCE_DIR/Podfile
  PODLOCK_FILE=$PROJECT_SOURCE_DIR/Podfile.lock

  if [ -e "$POD_FILE" ]; then
    echo "'$POD_FILE' exists"
  else
    echo "'$POD_FILE' is either not a regular file or it doesn't exist. Skipping process pod outdated."
    return
  fi
  
  if [ -e "$PODLOCK_FILE" ]; then
    echo "'$PODLOCK_FILE' exists"
  else
    echo "'$PODLOCK_FILE' is either not a regular file or it doesn't exist. Skipping process pod outdated."
    return
  fi

  OUTPUT_PODS_TXT=$BITRISE_DEPLOY_DIR/outdated.txt

  pod outdated --project-directory=$PROJECT_SOURCE_DIR > $OUTPUT_PODS_TXT

  grep '\->' "$OUTPUT_PODS_TXT" | while read -r line; do
    # Example input: "- AFNetworking 3.2.1 -> 4.0.1 (latest version 4.0.1)"
    packageName=$(echo "$line" | awk '{print $2}')
    currentVersion=$(echo "$line" | awk '{print $3}')
    latestVersion=$(echo "$line" | sed -E 's/.*\(latest version ([0-9\.]+)\).*/\1/')
    echo "$packageName,$currentVersion,$latestVersion,,PODS" >> "$OUTPUT_CSV"
  done
}

# --- Main Script Logic ---

# write your script here
echo "Running Dependency Version Checking!"

PACKAGE_RESOLVED_DIR=${package_resolved_path}
PACKAGE_RESOLVED_FILE=${package_resolved_path}/Package.resolved
PROJECT_SOURCE_DIR=${project_source_path}

OUTPUT_CSV=$BITRISE_DEPLOY_DIR/sbom.csv

OUTPUT_JSON=$BITRISE_DEPLOY_DIR/outdated.json

# Output CSV header
echo "Name,Current Version,Latest Version,Source,Package Manager" > "$OUTPUT_CSV"

# Process data and use awk to merge and deduplicate
{
  process_package_resolved
  process_swift_outdated
} | awk -F, '
  {
      key = $1;
      data[key] = $0; # Overwrite with latest info
    }
    END {
      for (k in data) {
        print data[k];
      }
    }' >> "$OUTPUT_CSV"

process_pod_outdated

if [ -e "$OUTPUT_CSV" ]; then
  echo "'$OUTPUT_CSV' exists"
else
  echo "Failed to process any dependency files!"
  exit 1
fi

envman add --key DEPENDENCY_VERSION_CHECK_RESULT_FILE --value $OUTPUT_CSV

echo "Combined and deduplicated SPM + PODS SBOM data written to '$OUTPUT_CSV'"

exit 0