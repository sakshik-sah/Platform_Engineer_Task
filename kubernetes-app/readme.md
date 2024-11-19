# Flask Application Deployment on Kubernetes with Monitoring

A comprehensive example of deploying a Flask application on Kubernetes using Helm, with Prometheus and Grafana monitoring integration.

## 🚀 Overview

This project demonstrates how to deploy a Flask application on Kubernetes using Helm charts, complete with monitoring capabilities using Prometheus and Grafana. The setup includes automated metrics collection, visualization, and basic health checking.

## ✨ Features

- Flask REST API with health check endpoint
- Kubernetes deployment using Helm charts
- Prometheus metrics integration
- Grafana dashboards for visualization
- Docker containerization
- Kubernetes service configuration
- Automated monitoring setup

## 📌 Prerequisites

Make sure you have the following installed:

```bash
- Docker
- Kubernetes (Minikube or similar)
- Helm
- kubectl
- Python 3.9+
```

## 📁 Project Structure

```
kubernetes-app/
├── app/
│   ├── app.py                  # Flask application
│   └── requirements.txt        # Python dependencies
├── Dockerfile                  # Docker configuration
├── mychart/                    # Helm chart directory
│   ├── Chart.yaml             # Chart metadata
│   ├── values.yaml            # Chart values
│   └── templates/             # Kubernetes templates
│       ├── deployment.yaml    # Deployment configuration
│       └── service.yaml       # Service configuration
├── monitoring/                 # Monitoring configurations
│   ├── prometheus-values.yaml # Prometheus configuration
│   └── grafana-values.yaml    # Grafana configuration
└── README.md                  # Project documentation
```

## 🛠️ Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/flask-k8s-monitoring.git
cd flask-k8s-monitoring
```

2. **Start Minikube**
```bash
minikube start
```

3. **Build and deploy the application**
```bash
# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build Docker image
docker build -t flask-app:latest .

# Deploy application
helm install flask-demo ./mychart
```

## 📊 Monitoring Setup

1. **Add Helm repositories**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

2. **Deploy Prometheus and Grafana**
```bash
# Install Prometheus
helm install prometheus prometheus-community/prometheus -f monitoring/prometheus-values.yaml

# Install Grafana
helm install grafana grafana/grafana -f monitoring/grafana-values.yaml
```

3. **Access Grafana Dashboard**
```bash
# Get Grafana admin password
kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward Grafana service
kubectl port-forward service/grafana 3000:80
```

Visit `http://localhost:3000` and login with:
- Username: `admin`
- Password: (from above command)

## 🎯 Usage

1. **Access the Application**
```bash
# Get Minikube IP
minikube ip

# Access the application
curl http://$(minikube ip):30000
```

2. **Check Application Health**
```bash
curl http://$(minikube ip):30000/health
```

3. **View Metrics**
```bash
curl http://$(minikube ip):30000/metrics
```

## 📈 Metrics

The application exposes the following metrics:

- **Request Count**: Total number of HTTP requests
  ```prometheus
  flask_request_count_total{endpoint="endpoint_name",method="GET"}
  ```

- **Request Latency**: Request duration in seconds
  ```prometheus
  flask_request_latency_seconds{endpoint="endpoint_name"}
  ```

## 🧹 Cleanup

To remove all deployed resources:

```bash
# Uninstall applications
helm uninstall flask-demo
helm uninstall prometheus
helm uninstall grafana

# Stop port forwarding
pkill -f "kubectl port-forward"

# Stop Minikube
minikube stop
```