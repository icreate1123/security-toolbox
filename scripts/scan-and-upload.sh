#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

repo_dir="${workdir}/repo"
report="${workdir}/snyk-code.sarif"

echo "Cloning ${TARGET_FULL_NAME} (${TARGET_BRANCH})"
git clone --depth=1 --branch "${TARGET_BRANCH}" \
  "https://x-access-token:${GH_TOKEN}@github.com/${TARGET_FULL_NAME}.git" \
  "${repo_dir}"

cd "${repo_dir}"

commit_sha="$(git rev-parse HEAD)"
ref="refs/heads/${TARGET_BRANCH}"

echo "Running Snyk Code on ${TARGET_FULL_NAME}"
set +e
snyk code test --severity-threshold=low --sarif-file-output="${report}" .
snyk_exit=$?
set -e

# Snyk Code exit meanings:
# 0 = no vulns
# 1 = vulns found
# 2 = scanner failure
# 3 = no supported files
if [ ! -f "${report}" ]; then
  printf '{"version":"2.1.0","runs":[]}' > "${report}"
fi

case "${snyk_exit}" in
  0) echo "No vulnerabilities found" ;;
  1) echo "Vulnerabilities found" ;;
  3)
    echo "No supported files detected; uploading empty SARIF"
    printf '{"version":"2.1.0","runs":[]}' > "${report}"
    ;;
  *)
    echo "Snyk failed with exit code ${snyk_exit}; uploading empty SARIF"
    printf '{"version":"2.1.0","runs":[]}' > "${report}"
    ;;
esac

sarif_b64="$(gzip -c "${report}" | base64 -w0)"

payload="$(jq -n \
  --arg commit_sha "${commit_sha}" \
  --arg ref "${ref}" \
  --arg sarif "${sarif_b64}" \
  --arg tool_name "snyk-code" \
  '{
    commit_sha: $commit_sha,
    ref: $ref,
    sarif: $sarif,
    tool_name: $tool_name
  }'
)"

echo "Uploading SARIF to ${TARGET_FULL_NAME}"
upload_resp="$(curl -fsSL -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  "https://api.github.com/repos/${TARGET_OWNER}/${TARGET_REPO}/code-scanning/sarifs" \
  -d "${payload}")"

sarif_id="$(echo "${upload_resp}" | jq -r '.id')"
echo "SARIF upload id: ${sarif_id}"

for attempt in $(seq 1 12); do
  status_resp="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    "https://api.github.com/repos/${TARGET_OWNER}/${TARGET_REPO}/code-scanning/sarifs/${sarif_id}")"

  status="$(echo "${status_resp}" | jq -r '.processing_status')"
  echo "Processing status: ${status}"

  if [ "${status}" = "complete" ]; then
    echo "Done"
    exit 0
  fi

  sleep 5
done

echo "Timed out waiting for SARIF processing"
exit 1
