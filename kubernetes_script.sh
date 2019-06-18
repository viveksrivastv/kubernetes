#!/bin/bash

## Creating GKE Cluster
ADMIN_USER=viveksrivastv@gmail.com
CLUSTER_NAME="${CLUSTER_NAME:-standard-cluster-1}"
GKE_PROJECT="${GKE_PROJECT:-long-victor-168119}"
GKE_REGION="${GKE_REGION:-us-central1}"
GKE_ZONE="${GKE_ZONE:--a}"
IMAGE_TYPE="${IMAGE_TYPE:-COS}"
NUM_NODES="${NUM_NODES:-1}"

gcloud config set account $ADMIN_USER
gcloud config set project $GKE_PROJECT
gcloud config set compute/zone $GKE_REGION$GKE_ZONE
gcloud container clusters create $CLUSTER_NAME --region=$GKE_REGION --num-nodes=$NUM_NODES
gcloud components install kubectl
gcloud container clusters get-credentials $CLUSTER_NAME --zone $GKE_REGION$GKE_ZONE --project $GKE_PROJECT
kubectl create clusterrolebinding owner-cluster-admin-binding --clusterrole cluster-admin --user $ADMIN_USER


### Creating Nginx Ingress Controller

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
spec:
  replicas: 1
  revisionHistoryLimit: 3
  template:
    metadata:
      labels:
        k8s-app: nginx-ingress-lb
    spec:
      containers:
        - args:
            - /nginx-ingress-controller
            - "--default-backend-service="$POD_NAMESPACE"/default-http-backend"
            - "--default-ssl-certificate="$POD_NAMESPACE"/tls-certificate"
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          image: "gcr.io/google_containers/nginx-ingress-controller:0.9.0-beta.5"
          imagePullPolicy: Always
          livenessProbe:
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            timeoutSeconds: 5
          name: nginx-ingress-controller
          ports:
            - containerPort: 80
              name: http
              protocol: TCP
            - containerPort: 443
              name: https
              protocol: TCP
          volumeMounts:
            - mountPath: /etc/nginx-ssl/dhparam
              name: tls-dhparam-vol
      terminationGracePeriodSeconds: 60
      volumes:
        - name: tls-dhparam-vol
          secret:
            secretName: tls-dhparam
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
  selector:
    k8s-app: nginx-ingress-lb" >> nginx-ingress-controller.yml


# Creating namespace staging and production

kubectl create namespace staging
kubectl create namespace production


## Git Clone for Guestbook Application

git clone https://github.com/kubernetes/examples.git
cd examples/guestbook


## Creating Deployment and services in staging namespace

kubectl create -f frontend-deployment.yaml -n staging
kubectl create -f frontend-service.yaml -n staging
kubectl create -f redis-master-deployment.yaml -n staging
kubectl create -f redis-master-service.yaml -n staging
kubectl create -f redis-slave-deployment.yaml -n staging
kubectl create -f redis-slave-service.yaml -n staging


## Creating Deployment and services in production namespace

kubectl create -f frontend-deployment.yaml -n production
kubectl create -f frontend-service.yaml -n production
kubectl create -f redis-master-deployment.yaml -n production
kubectl create -f redis-master-service.yaml -n production
kubectl create -f redis-slave-deployment.yaml -n production
kubectl create -f redis-slave-service.yaml -n production


## Expose staging application on hostname staging-guestbook.mstakx.io

echo "apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-stage
  annotations:
     kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: staging-guestbook.mstakx.io
    http:
      paths:
      - path: /
        backend:
          serviceName: frontend
          servicePort: 80" >> ingress-stage.yaml

## Expose production application on hostname guestbook.mstakx.io

echo "apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-prod
  annotations:
     kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: guestbook.mstakx.io
    http:
      paths:
      - path: /
        backend:
          serviceName: frontend
          servicePort: 80" >> ingress-prod.yaml


kubectl create -f ingress-stage.yaml -n staging
kubectl create -f ingress-prod.yaml -n production


## Implemented a pod autoscaler on both namespaces

kubectl autoscale deployment frontend --min=3 --max=5 --cpu-percent=80 -n staging
kubectl autoscale deployment frontend --min=3 --max=5 --cpu-percent=80 -n production


## increasing/decreasing load on existing pods

kubectl run -i --tty load-generator --image=busybox /bin/sh -n staging
while true; do wget -q -O- http://frontend.staging.svc.cluster.local; done

kubectl run -i --tty load-generator --image=busybox /bin/sh -n production
while true; do wget -q -O- http://frontend.production.svc.cluster.local; done


