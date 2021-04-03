#!/usr/bin/env bash

# example: ROOK_IMAGE=build-e858f56d/ceph-amd64:latest OCS_IMAGE=placeholder CSV_VERSION=1.1.1 hack/generate-manifests.sh

set -e

source hack/common.sh

function help_txt() {
	echo "Environment Variables"
	echo "    ROOK_IMAGE:           (required) The rook operator container image to integrate with"
	echo ""
	echo "Example usage:"
	echo "    ROOK_IMAGE=<image> $0"
}

# check required env vars
if [ -z "$ROOK_IMAGE" ]; then
	help_txt
	echo ""
	echo "ERROR: Missing required environment variables"
	exit 1
fi

# always start fresh and remove any previous artifacts that may exist.
mkdir -p $OUTDIR_TEMPLATES

mkdir -p $OUTDIR_CRDS


# ==== DUMP OCS YAMLS ====
# Generate an OCS CSV using the operator-sdk.
# This is the base CSV everything else gets merged into later on.
function gen_ocs_csv() {
	echo "Generating OpenShift Container Storage CSV"
	rm -rf "$(dirname $OCS_FINAL_DIR)"
	ocs_crds_outdir="$OUTDIR_CRDS/ocs"
    # zhou: "deploy/csv-templates/manifests/ocs-operator.clusterserviceversion.yaml"
	rm -rf $OUTDIR_TEMPLATES/manifests/ocs-operator.clusterserviceversion.yaml
    # zhou: "deploy/csv-templates/ocs-operator.csv.yaml.in"    
	rm -rf $OCS_CSV
    # zhou: "deploy/csv-templates/crds/ocs"
	rm -rf $ocs_crds_outdir
	mkdir -p $ocs_crds_outdir

	gen_args="generate kustomize manifests --input-dir config/manifests/ocs-operator --output-dir config/manifests/ocs-operator --package ocs-operator -q"
	# shellcheck disable=SC2086
	$OPERATOR_SDK $gen_args
	pushd config/manager
    # zhou: export OCS_IMAGE=${OCS_IMAGE:-"${IMAGE_REGISTRY}/${REGISTRY_NAMESPACE}/${OPERATOR_IMAGE_NAME}:${IMAGE_TAG}"}
	$KUSTOMIZE edit set image ocs-dev/ocs-operator="$OCS_IMAGE"
	popd
	$KUSTOMIZE build config/manifests/ocs-operator | $OPERATOR_SDK generate bundle -q --overwrite=false --output-dir deploy/ocs-operator --kustomize-dir config/manifests/ocs-operator --package ocs-operator --version "$CSV_VERSION" --extra-service-accounts=ux-backend-server
	mv deploy/ocs-operator/manifests/*clusterserviceversion.yaml $OCS_CSV
	cp config/crd/bases/* $ocs_crds_outdir
}

gen_ocs_csv

echo "Manifests sourced into $OUTDIR_TEMPLATES directory"

mv bundle.Dockerfile Dockerfile.bundle
