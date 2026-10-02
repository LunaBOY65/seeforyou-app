import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import cv2
import re
import requests
from datetime import datetime
import time
from paddleocr import PaddleOCR
from ultralytics import YOLO

# ตั้งค่าระบบ Setup
app = FastAPI()

# เปิดให้หน้าเว็บอื่นๆ เข้ามาเรียกใช้งาน API นี้ได้
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"status": "online", "message": "SeeForYou API is running"}

print("กำลังโหลด AI อ่านข้อความ (PaddleOCR)...")
ocr = PaddleOCR(
    use_angle_cls=False,
    lang='en',
    ocr_version='PP-OCRv4',
    show_log=False,
    use_gpu=False,          # ปิดการหา GPU เพื่อลด Overhead
    enable_mkldnn=True,     # เปิดใช้ MKLDNN เพื่อให้ CPU ประมวลผลเลขคณิตได้เร็วขึ้น
    rec_batch_num=1         # ลด Batch size เพื่อประหยัด RAM
)

print("กำลังโหลด AI ค้นหาป้าย (YOLO)...")
try:
    yolo_model = YOLO("best.pt", task="detect")
except Exception as e:
    print("หาไฟล์ best.pt ไม่เจอ ใช้ภาพเต็มในการหาข้อความแทน")
    yolo_model = None

BOTNOI_TOKEN = "bHZrbE5WS3lYSGJ6YThXbnNOS1BiMkMxZk1OMjU2MTg5NA==" 

def get_botnoi_voice(text_message):
    """ส่งข้อความไปให้ Botnoi สร้างเป็นไฟล์เสียง"""
    if not text_message:
        return ""   
        
    url = "https://api-voice.botnoi.ai/openapi/v1/generate_audio"

    payload = {
        "text": text_message,
        "speaker": "6", # Siren
        "volume": 1,
        "speed": 1,
        "type_media": "mp3",
        "save_file": "true",
        "language": "th",
        "page": "user"
    }

    headers = {
        "Botnoi-Token": BOTNOI_TOKEN,
        "Content-Type": "application/json"
    }
    
    try:
       # เกิน 10 วินาทีให้เลิกรอ
       response = requests.post(url, json=payload, headers=headers, timeout=10)
       
       if response.status_code == 200:
           
           data = response.json()
           
           # เช็คว่ามีข้อมูล audio_url ส่งมาไหม
           if "audio_url" in data:
               return data["audio_url"]
           else:
               print("สร้างเสียงไม่ได้: Botnoi ไม่ได้ส่งลิงก์มาให้")
               return "" # ส่งค่าว่างกลับไป
       else:
           print(f"สร้างเสียงไม่ได้: เซิร์ฟเวอร์ Botnoi มีปัญหา รหัส Error: {response.status_code}")
           return ""
    except Exception as e:
        print(f"สร้างเสียงไม่สำเร็จ: {e}")
        return ""

def get_valid_dates(text_list):
    """ค้นหาวันที่จากข้อความที่ OCR อ่านได้"""

    # list(date object)
    valid_dates = []

    # เตรียมข้อความ
    # เอาข้อความทั้งหมดมาต่อกันด้วยช่องว่าง และทำเป็นตัวพิมพ์ใหญ่
    all_text = " ".join(text_list).upper()
    
    # มักจะอ่านผิดให้กลายเป็นตัวเลข
    all_text = all_text.replace('O', '0')
    all_text = all_text.replace('I', '1')
    all_text = all_text.replace('B', '8')
    all_text = all_text.replace('S', '5')
    all_text = all_text.replace('Z', '2')
    all_text = all_text.replace('.', ' ')
    all_text = all_text.replace(':', ' ')

    """ ดึงเฉพาะส่วนที่เป็นตัวเลขออกมา """
    # เอาแค่ตัวเลขติดกันล้วนๆ ลบตัวอักษรอื่นทิ้งหมด เน้นหาตัวเลขที่พิมพ์ ติดกันรวดเดียว
    digits_only = re.sub(r'[^0-9]', '', all_text)
    
    # เปลี่ยนพวกเครื่องหมาย ให้เป็นช่องว่าง แยกเป็นก้อนๆ
    spaced_text = re.sub(r'[\.\-\/:]', ' ', all_text)

    # รวบรวม list(String) กลุ่มเลขที่น่าจะเป็นวันที่
    possible_dates = []
    
    # เลขติดกัน 8 ตัว (12052023)
    possible_dates.extend(re.findall(r'(\d{8})', digits_only))
    
    # เลขติดกัน 6 ตัว (120523)
    possible_dates.extend(re.findall(r'(\d{6})', digits_only))
    
    # ทำเลขที่เว้นวรรคกัน 3 ก้อน 12 05 2023 ให้ติดเป็นกลุ่มเดียวกัน
    for part1, part2, part3 in re.findall(r'\b(\d{1,4})\s+(\d{1,2})\s+(\d{1,4})\b', spaced_text):
        combined_parts = part1 + part2 + part3
        possible_dates.append(combined_parts)

    """ ตรวจสอบว่าแปลงเป็นวันที่ได้จริงไหม """
    for date_string in possible_dates:
        # ลบช่องว่างทิ้งให้หมดก่อนเริ่มตรวจสอบ
        date_string = date_string.replace(" ", "") 
        
        # กำหนดรูปแบบวันที่ที่อยากให้โปรแกรมลองแปลง
        if len(date_string) == 8:
            formats_to_try = ["%d%m%Y", "%Y%m%d"]
        else:
            formats_to_try = ["%d%m%y", "%y%m%d"]
        
        # ลองแปลงข้อความเป็นละรูปแบบ
        for fmt in formats_to_try:
            try:
                dt = datetime.strptime(date_string, fmt)
                year = dt.year
                    
                # ถ้าปีมีแค่ 2 หลัก
                if year < 100: 
                    year = year + 2000
                    
                # เช็คว่าปีสมเหตุสมผลไหม
                if 2020 <= year <= 2028:
                    # อัปเดตปีให้ถูกต้อง แล้วเก็บเข้ากล่อง valid_dates
                    correct_date = dt.replace(year=year)
                    valid_dates.append(correct_date)
                    
            except ValueError:
                # ถ้าแปลงไม่ได้ข้าม
                pass
                
    # จัดระเบียบผลลัพธ์
    # ใช้ set() ลบวันที่ที่ซ้ำกันออกแล้วแปลงกลับ
    unique_dates = list(set(valid_dates))
    
    # เรียงก้อนวันที่เป็นลำดับจากน้อยไปมาก
    unique_dates.sort()
    
    return unique_dates

""" API Endpoint สำหรับรับรูปภาพและวิเคราะห์ """
@app.post("/analyze")
async def analyze_image(file: UploadFile = File(...)):
    total_start_time = time.time()
    time_log = {}
    try:
        # 1. อ่านรูปภาพที่ส่งมา
        contents = await file.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if img is None:
            raise HTTPException(status_code=400, detail="ไฟล์รูปภาพมีปัญหาอ่านไม่ได้")

        # 2. ให้ YOLO หาป้ายวันที่ และตัดภาพมาเฉพาะส่วนนั้น
        yolo_start_time = time.time()

        crop_img = img 

        if yolo_model is not None:

            # ค้นหา
            results = yolo_model(img)

            # ดึงข้อมูลกล่องทั้งหมดที่หาเจอ
            boxes = results[0].boxes
            
            # ถ้าเจอกล่องอย่างน้อย 1 อัน และเลือกที่มั่นใจที่สุด
            if len(boxes) > 0:
                first_box = boxes[0]
                
                # ดึงค่า Confidence ออกมา
                confidence = float(first_box.conf[0])

                # มั่นใจเกิน 60% ไหม
                if confidence >= 0.6:
                    # พิกัดตำแหน่งของกล่อง xyxy [ซ้าย-บน-ขวา-ล่าง]
                    coordinates = first_box.xyxy[0]
                    
                    # แยกพิกัดออกมาทีละแกน
                    x_left   = int(coordinates[0])
                    y_top    = int(coordinates[1])
                    x_right  = int(coordinates[2])
                    y_bottom = int(coordinates[3])
                    
                    padding = 20
                    
                    # หาความกว้าง และความสูงของภาพต้นฉบับ
                    image_height = img.shape[0]
                    image_width  = img.shape[1]
                    
                    # คำนวณจุดตัดใหม่ เพื่อป้องกันการตัดออกนอกกรอบรูปภาพ
                    start_y = max(0, y_top - padding)
                    end_y   = min(image_height, y_bottom + padding)
                    
                    start_x = max(0, x_left - padding)
                    end_x   = min(image_width, x_right + padding)
                    
                    # ทำการตัดรูปภาพตามพิกัดที่คำนวณไว้
                    crop_img = img[start_y:end_y, start_x:end_x]

                    print(f"YOLO ตรวจพบป้ายด้วยความมั่นใจ: {confidence:.2f}")
                else:
                    print(f"YOLO เจอเป้าหมายแต่ไม่มั่นใจพอ ({confidence:.2f}) ใช้ภาพเต็มแทน")

        time_log['yolo'] = (time.time() - yolo_start_time) * 1000

        img_prep_start = time.time()
        
        # กันเหนี่ยว
        if crop_img is None or crop_img.size == 0:
            crop_img = img 

        # เปลี่ยนภาพที่ตัดมาให้เป็นสีขาวดำ
        gray_img = cv2.cvtColor(crop_img, cv2.COLOR_BGR2GRAY)

        # เติมขอบสีขาวรอบภาพ
        border_size = 20
        white_color = 255
        
        padded_img = cv2.copyMakeBorder(
            gray_img, 
            top=border_size, 
            bottom=border_size, 
            left=border_size, 
            right=border_size, 
            borderType=cv2.BORDER_CONSTANT, 
            value=white_color
        )
        
        # ปรับแสงด้วย Adaptive Threshold ให้อักษรชัดขึ้น
        # สีขาวสว่างที่สุดให้พื้นหลังเป็นสีขาว
        max_white_value = 255 
        
        # blockSize
        area_size = 15 
        
        # Constant
        contrast_adjustment = 6

        # สั่งให้ OpenCV ปรับแสง
        adaptive_thresh_img = cv2.adaptiveThreshold(
            src=padded_img,                                # รูปตั้งต้น
            maxValue=max_white_value,                      
            adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            thresholdType=cv2.THRESH_BINARY,               # ทำให้เป็น binary
            blockSize=area_size,                           
            C=contrast_adjustment                          
        )

        time_log['image_prep'] = (time.time() - img_prep_start) * 1000

        ocr_start_time = time.time()

        # 4. PaddleOCR อ่าน 2 แบบ

        # Menu ให้ loop ทำงาน
        attempts = [
            ("ปรับแสงชัด", adaptive_thresh_img),
            ("ขาวดำปกติ", padded_img)
        ]

        final_dates = []
        final_texts = []
        
        # ความมั่นใจขั้นต่ำ 40% พอ
        min_confidence = 0.4 
        
        for name, image_to_read in attempts:
            # แปลงภาพกลับเป็นภาพสีสำหรับ PaddleOCR
            ocr_input = cv2.cvtColor(image_to_read, cv2.COLOR_GRAY2RGB)

            result = ocr.ocr(ocr_input, cls=True)
            
            texts = []

            # ถ้าอ่านข้อความเจอ
            if result and result[0]:
                for line in result[0]:
                    # โครงสร้างที่ PaddleOCR ส่งคืนมา [0]พิกัดกล่อง, [1] ก้อนข้อความ และความมั่นใจ
                    text_data = line[1]         # ดึงก้อนข้อความ, ความมั่นใจ
                    found_text = text_data[0]   
                    confidence = text_data[1]   
                    
                    # มั่นใจเกิน 40% ไหม
                    if confidence > min_confidence:
                        texts.append(found_text)
            
            # เอาข้อความที่อ่านได้ทั้งหมดเข้าฟังก์ชันหาวันที่
            dates = get_valid_dates(texts)
            
            # ถ้าเจอวันที่แล้ว
            if dates and len(dates) > 0:
                final_dates = dates
                final_texts = texts 
                break

        time_log['ocr'] = (time.time() - ocr_start_time) * 1000

        full_text = " ".join(final_texts)
        
        formatted_dates = []

        # แปลงวันที่ให้เป็น String เช่น 12/05/2023
        for d in final_dates:
            formatted_dates.append(d.strftime('%d/%m/%Y'))
            
        # กล่องข้อมูลสำหรับส่งกลับไปฝั่ง Client
        response_data = {
            "raw_text": full_text,
            "dates_found_raw": formatted_dates,
            "status": "Unknown",
            "message": "ไม่พบวันที่ที่ชัดเจนค่ะ กรุณาลองถ่ายใหม่อีกครั้ง",
            "audio_url": ""
        }

        if final_dates:
            # รายการวันที่ถูกเรียงจากน้อยไปมากแล้ว 
            final_expiry = final_dates[-1] 
            
            today = datetime.now()
            
            # คำนวณหาว่าห่างกันกี่วัน 
            # เอาวันหมดอายุ - วันนี้ 
            days_diff = (final_expiry - today).days

            thai_months = [
                "มกราคม",
                "กุมภาพันธ์",
                "มีนาคม",
                "เมษายน",
                "พฤษภาคม",
                "มิถุนายน",
                "กรกฎาคม",
                "สิงหาคม",
                "กันยายน",
                "ตุลาคม",
                "พฤศจิกายน",
                "ธันวาคม"
            ]
            
            # index ของ List เริ่มที่ 0 เลยต้องลบ 1
            month_index = final_expiry.month - 1 
            month_name = thai_months[month_index]
            
            # แปลง ค.ศ. เป็น พ.ศ. เอาไปสร้างประโยค
            thai_year = final_expiry.year + 543
            
            readable_date = f"{final_expiry.day} {month_name} ปี {thai_year}"

            # เก็บข้อมูลเข้ากล่องเตรียมส่งกลับ
            response_data["expiry_date"] = final_expiry.strftime('%d/%m/%Y')
            response_data["days_remaining"] = days_diff

            # สร้างประโยคคำพูด และเช็ควัน
            # abs() เลขเป็นบวกเสมอ และหารเอาส่วน
            abs_days = abs(days_diff)
            months_total = abs_days // 30

            time_str = ""

            if months_total >= 12:
                # เกิน 1 ปีขึ้นไป
                years = months_total // 12
                rem_months = months_total % 12
                time_str = f"{years} ปี {rem_months} เดือน" if rem_months > 0 else f"{years} ปี"

            elif months_total > 0:
                # กรณีไม่ถึงปี
                time_str = f"{months_total} เดือน"

            else:
                # กรณีไม่ถึงเดือน
                time_str = f"{abs_days} วัน"

            if days_diff < 0:
                # กรณีหมดอายุแล้ว
                response_data["status"] = "Expired"
                response_data["message"] = f"หมดอายุแล้วค่ะ ตั้งแต่วันที่ {readable_date} ผ่านมาแล้วประมาณ {time_str}ค่ะ"
            else:
                # กรณียังไม่หมดอายุ
                response_data["status"] = "Safe"
                response_data["message"] = f"ยังไม่หมดอายุค่ะ เก็บได้อีกประมาณ {time_str} ถึงวันที่ {readable_date}"

        # ส่งข้อความไปแปลงเป็นเสียงด้วย Botnoi
        tts_start_time = time.time()

        if response_data["message"] != "":
            response_data["audio_url"] = get_botnoi_voice(response_data["message"])

        time_log['tts'] = (time.time() - tts_start_time) * 1000

        # คำนวณเวลารวมทั้งหมด
        total_time = (time.time() - total_start_time) * 1000
        time_log['total'] = total_time
        
        print("\n" + "="*50)
        print(f"[SERVER PROCESSING TIME LOG]")
        print(f"- YOLO Detection {time_log.get('yolo', 0):.2f} ms")
        print(f"- Image Processing {time_log.get('image_prep', 0):.2f} ms")
        print(f"- PaddleOCR {time_log.get('ocr', 0):.2f} ms")
        print(f"- Botnoi TTS API {time_log.get('tts', 0):.2f} ms")

        recorded_time = sum(v for k, v in time_log.items() if k != 'total')
        other_time = total_time - recorded_time
        print(f"- Other {other_time:.2f} ms")

        print(f"TOTAL TIME {total_time:.2f} ms")
        print("="*50 + "\n")

        return response_data

    except Exception as e:
        print(f"เกิดข้อผิดพลาดในระบบ: {e}")
        raise HTTPException(status_code=500, detail="เกิดข้อผิดพลาดในการประมวลผลเซิร์ฟเวอร์")


#  สั่งรัน Server
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)