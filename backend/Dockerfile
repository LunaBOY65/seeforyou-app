FROM python:3.9

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ตั้งค่า Directory 
WORKDIR /code

# Copy requirements และติดตั้ง
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Copy all code
COPY . .

# สั่งรัน FastAPI (Hugging Face บังคับใช้ Port 7860)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]