from flask import Flask
import psycopg2
import os
import sys

app = Flask(__name__)

def check_db_connection():
    try:
        # Читаем переменные, которые Docker подставит в систему
        connection = psycopg2.connect(
            host="db", # Имя сервиса базы данных в docker-compose
            database=os.environ.get("POSTGRES_DB"),
            user=os.environ.get("POSTGRES_USER"),
            password=os.environ.get("POSTGRES_PASSWORD")
        )
        connection.close()
        return True
    except Exception as e:
        print(f"Ошибка подключения к базе: {e}", file=sys.stderr)
        return False

@app.route('/')
def hello():
    if check_db_connection():
        return "Hello, DevOps World! My database is CONNECTED and ready. 🎉"
    else:
        return "Hello, DevOps World! But... Database connection FAILED. ❌", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)