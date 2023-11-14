#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${ClusterName} --kubelet-extra-args "--node-labels=eks.amazonaws.com/nodegroup-image=${AmiId},eks.amazonaws.com/nodegroup=${GroupName}" --container-runtime containerd
