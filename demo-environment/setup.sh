#!/bin/bash

# GitOps Configuration
oc adm policy add-cluster-role-to-user cluster-admin  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller -n openshift-gitops

# Create environment using GitOps
oc apply -f demo-environment/demo-environment.yaml