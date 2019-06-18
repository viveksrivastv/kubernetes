# kubernetes

Q. What was the node size chosen for the Kubernetes nodes? And why?
Ans: The number of nodes is 3 because of each node per zone of a region.

Q. What method was chosen to install the demo application and ingress controller on the cluster, justify the method used
Ans: First taken git clone for demo application then install the application using kubectl create -f command
     
Q. What would be your chosen solution to monitor the application on the cluster and why?
Ans: We can use prometheus to monitor the cluster. Prometheus monitor kubernetes, nodes. The Prometheus Operator simplifies Prometheus setup on Kubernetes, and allows to serve custom metrics API using Prometheus adapter. Prometheus provides a robust query language and a built-in dashboard for querying and visualizing data. Prometheus is also a supported data source for Grafana.

Q. What additional components / plugins would you install on the cluster to manage it better?
Ans: We can install multiple packages as belw,
1. Helm : It is a package manager to install any packages over kubernetes cluster
2. Prometheus / Grafana: To monitor application
3. Istio for service mesh etc
