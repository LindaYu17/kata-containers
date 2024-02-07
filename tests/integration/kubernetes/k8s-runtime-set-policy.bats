#!/usr/bin/env bats
#
# Copyright (c) 2023 Microsoft.
#
# SPDX-License-Identifier: Apache-2.0
#

load "${BATS_TEST_DIRNAME}/../../common.bash"
load "${BATS_TEST_DIRNAME}/tests_common.sh"

setup() {
	get_pod_config_dir
	pod_name="runtime-set-policy"
	pod_yaml="${pod_config_dir}/k8s-runtime-set-policy.yaml"
	allow_all_rego="${pod_config_dir}/allow-all.rego"
	reject_exec_rego="${pod_config_dir}/reject-exec.rego"
}

@test "kubectl exec and logs enable/disable at runtime" {

	# Create the pod
	kubectl create -f "${pod_yaml}"

	# Wait for pod to start
	echo "timeout=${timeout}"
	kubectl wait --for=condition=Ready --timeout=$timeout pod "$pod_name"

	# Try executing a command in the Pod, it should be enabled for now
	exec_output=$(kubectl exec "$pod_name" -- date 2>&1) || true
	echo "$exec_output"
	echo "$exec_output" | grep -v "ExecProcessRequest is blocked by policy"

	# Get sandbox id
	sandbox_id=$(ps aux|grep sandbox-|awk {'print $13'}|awk -F- {'print $2'}|head -1)

	# Reject exec by kata-runtime policy set with a repo with ExecProcessRequest=false
	/opt/kata/bin/kata-runtime policy set "${reject_exec_rego}" --sandbox-id "${sandbox_id}"
	exec_output=$(kubectl exec "$pod_name" -- date 2>&1) || true
	echo "$exec_output"
	echo "$exec_output" | grep "ExecProcessRequest is blocked by policy"

	# Enable exec by kata-runtime policy set with a repo with all API allowed
	/opt/kata/bin/kata-runtime policy set "${allow_all_rego}" --sandbox-id "${sandbox_id}"
	exec_output=$(kubectl exec "$pod_name" -- date 2>&1) || true
	echo "$exec_output"
	echo "$exec_output" | grep -v "ExecProcessRequest is blocked by policy"
}

teardown() {
	# Debugging information
	kubectl describe "pod/$pod_name"

	kubectl delete pod "$pod_name"
}
