import os
from flask import Flask, jsonify
app = Flask(__name__)

@app.get("/")
def index():
    return jsonify(service="demo-app", message="Hello from the DevOps CI/CD rollback lab",
                   version=os.getenv("APP_VERSION", "local"))

@app.get("/health")
def health():
    if os.getenv("SIMULATE_UNHEALTHY", "false").lower() == "true":
        return jsonify(status="unhealthy", reason="rollback test flag enabled"), 503
    return jsonify(status="ok"), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
