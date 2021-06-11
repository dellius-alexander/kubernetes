#!/usr/bin/env bash
##########################################################################
export $(cat cert-manager.env | grep -v '#' | awk '/=/ {print $1}')
# Generate a ca.key with 2048bit:
openssl genrsa -out ca.key 2048 && \
# According to the ca.key generate a ca.crt (use -days to set the certificate effective time):
openssl req -x509 -new -nodes -key ca.key -subj "/CN=*.dellius.app" -days 365 -out ca.crt && \
# Generate a server.key with 2048bit:
openssl genrsa -out server.key 2048 && \
# Generate the certificate signing request based on the config file:
openssl req -new -key server.key -out server.csr -config csr.conf && \
# Generate the server certificate using the ca.key, ca.crt and server.csr:
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
-CAcreateserial -out server.crt -days 10000 \
-extensions v3_ext -extfile csr.conf && \
# View the certificate:
openssl x509  -noout -text -in ./server.crt && \
# create a Secret containing a signing key pair in the default namespace:
kubectl create secret tls dellius-app-tls \
--cert=ca.crt \
--key=ca.key \
--namespace=default && \
##########################################################################
# https://docs.cert-manager.io/en/release-0.8/getting-started/install/kubernetes.html
#  Install the CustomResourceDefinition resources separately
kubectl apply -f 00-crds.yaml && \
# Create a namespace to run cert-manager in
kubectl create namespace cert-manager && \
# Disable resource validation on the cert-manager namespace
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true && \
#kubectl label namespace default certmanager.k8s.io/disable-validation=true
# Install the CustomResourceDefinitions and cert-manager itself
kubectl apply -f cert-manager.yaml
kubectl apply -f letsencrypt.yaml
# kubectl apply -f ./cert-manager/cert-manager-crds.yaml
