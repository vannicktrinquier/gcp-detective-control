#!/bin/sh

echo 'Downloading CFT Scorecard'
curl -o cft https://storage.googleapis.com/cft-cli/latest/cft-linux-amd64
chmod +x cft

echo 'Downloading sample policy library'
git clone https://github.com/GoogleCloudPlatform/policy-library.git
cp policy-library/samples/storage_location.yaml policy-library/policies/constraints/
mkdir -p ./reports

./cft scorecard --policy-path ./policy-library --bucket ${CAI_BUCKET} --target-organization ${SCAN_ORGANIZATION_ID} --output-format json --output-path ./reports --refresh
gsutil cp ./reports/scorecard.json gs://${CAI_BUCKET}
