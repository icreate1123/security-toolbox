#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

repo_dir="${workdir}/repo"
report_dir="/work/reports"
report="${report_dir}/${TARGET_OWNER}-${TARGET_REPO}.sarif"

mkdir -p "${report_dir}"

echo "Cloning ${TARGET_FULL_NAME} (${TARGET_BRANCH})"
git clone --depth=1 --branch "${TARGET_BRANCH}" \
  "https://x-access-token:${GH_TOKEN}@github.com/${TARGET_FULL_NAME}.git" \
  "${repo_dir}"

cd "${repo_dir}"

echo "Running Snyk Code on ${TARGET_FULL_NAME}"
set +e
snyk code test --severity-threshold=low --sarif-file-output="${report}" .
snyk_exit=$?
set -e

if [ ! -f "${report}" ]; then
  printf '{"version":"2.1.0","runs":[]}' > "${report}"
fi

case "${snyk_exit}" in
  0) echo "No vulnerabilities found" ;;
  1) echo "Vulnerabilities found" ;;
  3)
    echo "No supported files detected; writing empty SARIF"
    printf '{"version":"2.1.0","runs":[]}' > "${report}"
    ;;
  *)
    echo "Snyk failed with exit code ${snyk_exit}; writing empty SARIF"
    printf '{"version":"2.1.0","runs":[]}' > "${report}"
    ;;
esac

echo "SARIF written to ${report}"
