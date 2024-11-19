# app/app.py
from flask import Flask, jsonify, Response, request, g as flask_g
import socket
import os
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
import time

app = Flask(__name__)

# Define Prometheus metrics
REQUEST_COUNT = Counter(
    'flask_request_count',
    'Number of requests received',
    ['endpoint', 'method']
)

REQUEST_LATENCY = Histogram(
    'flask_request_latency_seconds',
    'Request latency in seconds',
    ['endpoint']
)

@app.before_request
def before_request():
    flask_g.start_time = time.time()

@app.after_request
def after_request(response):
    if hasattr(flask_g, 'start_time'):
        latency = time.time() - flask_g.start_time
        REQUEST_LATENCY.labels(request.endpoint or 'none').observe(latency)
        REQUEST_COUNT.labels(request.endpoint or 'none', request.method).inc()
    return response

@app.route('/')
def hello():
    host_name = socket.gethostname()
    return jsonify({
        'message': 'Hello from Kubernetes!',
        'hostname': host_name
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype='text/plain')

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)