import os
import time
import string
import random
import logging
import psycopg2
from psycopg2.extras import DictCursor
from flask import Flask, render_template, request, redirect, abort

app = Flask(__name__)

# Настраиваем логи для Loki
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("link_shortener")

# Берем настройки подключения к базе из переменных окружения (.env)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )

# Автоматически создаем таблицу при запуске приложения (с retry-механизмом)
def init_db():
    # Пробуем подключиться к базе несколько раз, давая ей время на раскачку
    for attempt in range(5):
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS urls (
                    id SERIAL PRIMARY KEY,
                    long_url TEXT NOT NULL,
                    short_code VARCHAR(10) NOT NULL UNIQUE,
                    clicks_count INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_short_code ON urls(short_code);
            """)
            conn.commit()
            cur.close()
            conn.close()
            logger.info("База данных проверена/инициализирована успешно.")
            return # Если всё прошло успешно, выходим из функции
        except psycopg2.OperationalError as e:
            logger.warning(f"База данных ещё не готова (попытка {attempt + 1}/5). Ожидание 2 секунды...")
            time.sleep(2)
    
    # Если за 5 попыток база не ответила — тогда уже сигнализируем о критической ошибке
    logger.critical("Не удалось подключиться к PostgreSQL после 5 попыток.")
    raise Exception("Database connection failed")

# Генерация случайного хвостика (например, aB3dE)
def generate_short_code(length=6):
    chars = string.ascii_letters + string.digits
    return "".join(random.choice(chars) for _ in range(length))

@app.route("/", methods=["GET", "POST"])
def index():
    short_url = None
    if request.method == "POST":
        long_url = request.form.get("url")
        if long_url:
            short_code = generate_short_code()
            
            # Сохраняем в PostgreSQL
            conn = get_db_connection()
            cur = conn.cursor()
            try:
                cur.execute(
                    "INSERT INTO urls (long_url, short_code) VALUES (%s, %s)",
                    (long_url, short_code)
                )
                conn.commit()
                short_url = f"{request.host_url}{short_code}"
                logger.info(f"SUCCESS: Ссылка сокращена: {long_url} -> {short_code}")
            except Exception as e:
                conn.rollback()
                logger.error(f"ERROR: Ошибка записи в базу: {e}")
            finally:
                cur.close()
                conn.close()
                
    return render_template("index.html", short_url=short_url)

@app.route("/<short_code>")
def redirect_to_url(short_code):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    cur.execute("SELECT long_url FROM urls WHERE short_code = %s", (short_code,))
    row = cur.fetchone()
    
    if row:
        # Увеличиваем счетчик кликов
        cur.execute(
            "UPDATE urls SET clicks_count = clicks_count + 1 WHERE short_code = %s",
            (short_code,)
        )
        conn.commit()
        long_url = row["long_url"]
        cur.close()
        conn.close()
        
        logger.info(f"REDIRECT: Переход по коду {short_code} на {long_url}")
        return redirect(long_url)
    
    cur.close()
    conn.close()
    logger.warning(f"404: Код {short_code} не найден в базе данных")
    return abort(404)

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
