FROM python:3.9-slim

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .

ENV PORT=5000
EXPOSE 5000

CMD ["python", "-u", "app.py"]