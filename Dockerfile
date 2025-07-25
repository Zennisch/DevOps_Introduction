FROM python:3.9-slim
WORKDIR /app
COPY website_app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY website_app/Server.py .
EXPOSE 30000
CMD ["python", "Server.py"]
