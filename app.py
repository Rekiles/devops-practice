from flask import Flask
import psycopg2
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello, DevOps World! My database is ready."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)