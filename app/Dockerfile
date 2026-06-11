# 1. Используем свежую, стабильную и безопасную версию Python
FROM python:3.12-slim

# 2. Настраиваем переменные окружения для Python
# PYTHONUNBUFFERED=1 — логи отправляются в консоль мгновенно (важно для Loki/Grafana)
# PYTHONDONTWRITEBYTECODE=1 — не плодим лишние файлы .pyc внутри контейнера
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем зависимости и устанавливаем их (кэшируемый слой)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем исходный код приложения
COPY . .

# Вручную создаем системную группу и пользователя 'appuser'
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Отдаем права новому пользователю на рабочую директорию
RUN chown -R appuser:appuser /app

# Переключаемся на безопасного пользователя
USER appuser

# Указываем порт и команду запуска
EXPOSE 5000
CMD ["python", "app.py"]