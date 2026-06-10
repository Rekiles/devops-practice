# Используем легковесный образ Python
FROM python:3.9-slim

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем зависимости и устанавливаем их
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем абсолютно ВСЁ содержимое папки app (включая templates/)
COPY . .

# Указываем порт и команду запуска
EXPOSE 5000
CMD ["python", "app.py"]