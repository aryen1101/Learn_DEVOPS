# Session 15 - Helm (Practice)

## 01-what-is-helm

```bash
helm version
helm list
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-nginx bitnami/nginx
kubectl get pods
kubectl get services
helm uninstall my-nginx
```

![alt text](images/image.png)

## 02-helm-charts

```bash
helm create demo-chart
ls demo-chart/
ls demo-chart/templates/
helm template my-release demo-chart
helm install demo-release demo-chart
kubectl get pods
helm list
helm uninstall demo-release
```

![alt text](images/image-1.png)
![alt text](images/image-2.png)
![alt text](images/image-3.png)

## 03-chart-structure

```bash
mkdir -p simple-chart/templates
helm template my-release simple-chart
helm install my-release simple-chart
kubectl get pods
kubectl get services
helm uninstall my-release
```

![alt text](images/image-4.png)
![alt text](images/image-5.png)

## 04-chart-yaml

```bash
helm lint my-app/
```

![alt text](images/image-6.png)

## 05-values-yaml

```bash
helm install my-app ./chart --set replicaCount=3
helm install my-app ./chart -f values-prod.yaml
helm template my-app ./chart | grep "replicas:"
helm template my-app ./chart --set replicaCount=3 | grep "replicas:"
```

![alt text](images/image-7.png)
![alt text](images/image-8.png)
![alt text](images/image-9.png)

## 06-templates

```bash
mkdir -p template-demo/templates
helm template my-release template-demo
helm template my-release template-demo --set replicaCount=5 | grep "replicas:"
```

![alt text](images/image-10.png)

## 07-install-upgrade

```bash
mkdir -p app-chart/templates
helm install web-app ./app-chart
kubectl get pods
helm list
helm upgrade web-app ./app-chart --set replicaCount=3
kubectl get pods
helm upgrade --install web-app ./app-chart
helm uninstall web-app
```

![alt text](images/image-11.png)

## 08-rollback

```bash
helm install rollback-demo ./app-chart
helm upgrade rollback-demo ./app-chart --set image.tag=doesnotexist
kubectl get pods
helm history rollback-demo
helm rollback rollback-demo 1
kubectl get pods
helm history rollback-demo
helm upgrade rollback-demo ./app-chart --set image.tag=doesnotexist --atomic --timeout 60s
helm uninstall rollback-demo
```

![alt text](images/image-12.png)
![alt text](images/image-13.png)

## 09-deploying-application

```bash
mkdir -p guestbook-chart/templates
helm lint guestbook-chart
helm template my-guestbook guestbook-chart
helm install my-guestbook guestbook-chart
kubectl get pods
kubectl get services
kubectl get configmaps
helm upgrade my-guestbook guestbook-chart --set replicaCount=3
kubectl get pods
helm history my-guestbook
helm rollback my-guestbook 1
helm uninstall my-guestbook
```

![alt text](images/image-14.png)
![alt text](images/image-15.png)
![alt text](images/image-16.png)

## 10-mini-project

```bash
mkdir -p notes-chart/templates
helm lint notes-chart
helm template notes-dev notes-chart
helm install notes-dev notes-chart
kubectl get pods
kubectl get services
kubectl get configmaps
helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml
kubectl get pods
helm history notes-dev
helm upgrade notes-dev notes-chart --set image.tag=broken-tag-does-not-exist
kubectl get pods
helm rollback notes-dev 2
kubectl get pods
helm uninstall notes-dev
kubectl get pods
kubectl get services
```

![alt text](images/image-17.png)
![alt text](images/image-18.png)
![alt text](images/image-19.png)
