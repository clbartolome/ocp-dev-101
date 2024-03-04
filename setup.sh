#!/bin/bash

# GitOps Configuration
oc adm policy add-cluster-role-to-user cluster-admin  system:serviceaccount:openshift-gitops-operator:openshift-gitops-operator-argocd-application-controller -n openshift-gitops-operator

# Create environment using GitOps
oc apply -f demo-environment/demo-environment.yaml

# Instructions
ARGO_USER=admin
ARGO_PASS=$(oc get secret openshift-gitops-operator-cluster -n openshift-gitops-operator -ojsonpath='{.data.admin\.password}' | base64 -d)
ARGO_ROUTE=$(oc get route openshift-gitops-operator-server -n openshift-gitops-operator -o jsonpath='{.status.ingress[0].host}')

echo "Login into ArgoCD using the following info:"
echo ""
echo "    URL: https://$ARGO_ROUTE"
echo "    User: $ARGO_USER"
echo "    Pass: $ARGO_PASS"
echo ""
echo "Review the created resources inside demo-environment app and press SYNC"
