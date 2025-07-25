FROM python:3.9-slim
WORKDIR /app
COPY webapp/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY webapp/Server.py .
EXPOSE 30000
CMD ["python", "Server.py"]
