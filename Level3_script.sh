## Creating GCP Cluster

echo "variable "admin_username" {
    type        = "string"
    description = "User name for authentication to the Kubernetes linux agent virtual machines in the cluster."
}
variable "admin_password" {
    type ="string"
    description = "The password for the Linux admin account."
}

variable "gcp_cluster_count" {
    type = "string"
    description = "Count of cluster instances to start."
}
variable "cluster_name" {
    type = "string"
    description = "Cluster name for the GCP Cluster."
}

output "gcp_cluster_endpoint" {
    value = "${google_container_cluster.gcp_kubernetes.endpoint}"
}
output "gcp_ssh_command" {
    value = "ssh ${var.admin_username}@${google_container_cluster.gcp_kubernetes.endpoint}"
}
output "gcp_cluster_name" {
    value = "${google_container_cluster.gcp_kubernetes.name}"
}" >> variables.tf 


echo "cluster_name = "my-cluster"
gcp_cluster_count = 1
admin_username = "viveksrivastv@gmail.com"
admin_password = "password@123" >> terraform.tfvars


echo "resource "google_container_cluster" "gcp_kubernetes" {
    name               = "${var.cluster_name}"
    zone               = "us-west1-a"
    initial_node_count = "${var.gcp_cluster_count}"
    additional_zones = [
        "us-west1-b",
        "us-west1-c",
    ]
    master_auth {
        username = "${var.admin_username}"
        password = "${var.admin_password}}"
    }
    node_config {
        oauth_scopes = [
          "https://www.googleapis.com/auth/compute",
          "https://www.googleapis.com/auth/devstorage.read_only",
          "https://www.googleapis.com/auth/logging.write",
          "https://www.googleapis.com/auth/monitoring",
        ]
        labels {
            this-is-for = "my-cluster"
        }
        tags = ["dev", "work"]
    }
}" >> main.tf


terraform plan
terraform apply



## Create DockerFile to create Jenkins Master

echo "FROM jenkins/jenkins:lts
USER root
RUN apt-get update -y
RUN apt-get install -y vim
RUN /usr/local/bin/install-plugins.sh email-ext
RUN /usr/local/bin/install-plugins.sh mailer
RUN /usr/local/bin/install-plugins.sh slack
RUN /usr/local/bin/install-plugins.sh htmlpublisher
RUN /usr/local/bin/install-plugins.sh greenballs
RUN /usr/local/bin/install-plugins.sh simple-theme-plugin
RUN /usr/local/bin/install-plugins.sh ssh-slaves
RUN /usr/local/bin/install-plugins.sh kubernetes
USER jenkins" >> Dockerfile


## Build Jenkins Image with DockerFile and push to DockerHub

docker build -t jenkins:latest .
docker login --username=vivek12 --email=viveksrivastv@gmail.com
docker tag jenkins:latest vivek12/jenkins:latest
docker push vivek12/jenkins:latest 



## Deploy a private local registry

docker run -d -p 5000:5000 --restart=always --name registry registry:2

docker pull vivek12/jenkins:latest 
docker tag jenkins:latest localhost:5000/jenkins:latest
docker push localhost:5000/jenkins:latest



## Setup CI Server on Kubernetes Master

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: jenkins
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
        - name: jenkins
          image: jenkins:latest
          resources:
            limits:
              memory: "512Mi"
          ports:
            - name: http-port
              containerPort: 8080
              hostPort: 8080
            - name: jnlp-port
              containerPort: 50000
              hostPort: 50000
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
      volumes:
        - name: jenkins-home
          emptyDir: {}" >> jenkins-deployment.yaml


kubectl create -f jenkins-deployment.yaml


## Deploy an open source vulnerability scanner for docker images

cd web_image
docker build -t web_image:latest .
cd ../db_image
docker build -t db_image:latest .
cd ..
mkdir images/

docker save web_image:latest -o images/web_image+latest.tar
docker save db_image:latest -o images/db_image+latest.tar
curl -s https://ci-tools.anchore.io/inline_scan-v0.3.3 | bash -s -- -v ./images -t 500




## Create a namespace and deploy the mediawiki application on the cluster.

kubectl create namespace dev
helm install stable/mediawiki


## Setup Nginx Ingress Controller

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




## Installing Istio

cd $HOME
curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.0.0 sh 
cd istio-1.0.0
echo "export PATH="$PATH:$PWD/bin"" | tee -a ~/.bashrc
source ~/.bashrc


## Installing Kiali

KIALI_USERNAME=$(read -p 'Kiali Username: ' uval && echo -n $uval | base64)
KIALI_PASSPHRASE=$(read -sp 'Kiali Passphrase: ' pval && echo -n $pval | base64)

NAMESPACE=istio-system
kubectl create namespace $NAMESPACE

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: $NAMESPACE
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF


## Installing zipkin

kubectl create -f http://repo1.maven.org/maven2/io/fabric8/zipkin/zipkin-starter/0.1.5/zipkin-starter-0.1.5-kubernetes.yml


## Srtup mtls for istio mesh

mkdir ssl && cd ssl && mkdir client && mkdir server
openssl req -x509 -newkey rsa:4096 -keyout server/serverPrivateKey.pem -out server/server.crt -days 3650 -nodes
openssl pkcs12 -export -out server/keyStore.p12 -inkey server/serverPrivateKey.pem -in server/server.crt
keytool -import -trustcacerts -alias root -file server/server.crt -keystore server/trustStore.jks


openssl req -new -newkey rsa:4096 -out client/request.csr -keyout client/myPrivateKey.pem -nodes
openssl x509 -req -days 360 -in request.csr -CA server/server.crt -CAkey server/serverPrivateKey.pem -CAcreateserial -out client/pavel.crt -sha256
openssl x509 -text -noout -in client/pavel.crt
openssl pkcs12 -export -out client/client_pavel.p12 -inkey client/myPrivateKey.pem -in client/pavel.crt -certfile server/myCertificate.crt

kubectl exec $(kubectl get pod -l app=httpbin -o jsonpath={.items..metadata.name}) -c istio-proxy -- cat client/myPrivateKey.pem | openssl x509 -text -noout  | grep Validity -A 2


## Creating Kubernetes Dashboard
 
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml


echo "apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system" >> dashboard-admin.yaml


kubectl create -f dashboard-admin.yaml

## Access Dashboard URL: http://192.168.0.25:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login
 

kubectl proxy --address 0.0.0.0 --accept-hosts '.*' &

 
## Kubernetes Dashbaord Authentication using Token

kubectl create serviceaccount k8sadmin -n kube-system
kubectl create clusterrolebinding k8sadmin --clusterrole=cluster-admin --serviceaccount=kube-system:k8sadmin
kubectl get secret -n kube-system | grep k8sadmin | cut -d " " -f1 | xargs -n 1 | xargs kubectl get secret  -o 'jsonpath={.data.token}' -n kube-system | base64 --decode
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrOHNhZG1pbi10b2tlbi1tZmpubSIsI


 


