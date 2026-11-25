# ventuno-q-setup

สคริปต์เตรียมบอร์ด Arduino VENTUNO Q สำหรับ workshop

## check_board.sh: เช็กว่าบอร์ดพร้อมสอนไหม

```bash
./check_board.sh        # ไม่ต้องใช้ sudo ไม่แก้อะไรบนบอร์ด
```

เช็กทีละ Part: arduino:zephyr, Remote Desktop, กล้อง, ROS 2, กลุ่ม arduino-router, โมเดล AI, llama.cpp และพื้นที่ disk ข้อที่ขาดจะบอกคำสั่งที่ต้องรันต่อ

## copy_models.sh: ก็อปโมเดลไปบอร์ดอื่นโดยไม่ต้องใช้เน็ต

ก็อปโมเดลที่ลงผ่าน arduino-app-cli (`genie:` และ `llamacpp:`) จากบอร์ดที่โหลดไว้แล้วไปบอร์ดอื่น ใช้ตอนเน็ตหลุดหรือเน็ตช้าในห้องเรียน ไม่ต้องใช้ sudo

```bash
./copy_models.sh list                              # ดูว่ามีโมเดลอะไรให้ก็อป

# วิธี A: ส่งผ่าน LAN (บอร์ดอยู่วงเดียวกัน ไม่ต้องมีเน็ต)
./copy_models.sh send 10.26.15.160                 # ส่งทุกโมเดล
./copy_models.sh send 10.26.15.160 genie:qwen3_4b_instruct_2507

# วิธี B: ผ่าน flash drive (ฟอร์แมต exFAT)
udisksctl mount -b /dev/sda1                       # บอร์ดต้นทาง
./copy_models.sh export /media/arduino/<drive>/models
udisksctl unmount -b /dev/sda1
# เสียบที่บอร์ดปลายทาง
udisksctl mount -b /dev/sda1
./copy_models.sh import /media/arduino/<drive>/models
```

- โมเดล built-in (YoloX, Face) ติดมากับบอร์ดอยู่แล้ว ไม่ต้องก็อป
- `models.ini` ของ llamacpp จะเพิ่มเฉพาะบรรทัดที่ยังไม่มี ไม่เขียนทับ
- `send` จะถามรหัสผ่านของบอร์ดปลายทาง (ใช้ ssh)
- เสร็จแล้วสคริปต์จะแสดง Status ให้ดูว่าเป็น `installed`

## setup_rdp.sh: เปิด Remote Desktop

เปิด Remote Desktop (RDP) ด้วยสคริปต์เดียว ใช้ได้ทั้งตอนที่ไม่ได้ต่อจอและตอนที่ต่อจอ HDMI อยู่

### วิธีใช้

SSH เข้าบอร์ดแล้วรัน:

```bash
git clone https://github.com/syanyong/ventuno-q-setup.git
cd ventuno-q-setup
chmod +x setup_rdp.sh
sudo ./setup_rdp.sh
```

สคริปต์จะให้เลือกโหมดก่อน แล้วแสดงว่าจะเปลี่ยนอะไรบ้าง และถาม **Continue?** ก่อนลงมือทุกครั้ง

| โหมด | ใช้เมื่อ | ฝั่งโน้ตบุ๊กจะเห็น |
|---|---|---|
| **1) No HDMI** | ไม่ได้ต่อจอที่บอร์ด (ใช้ใน workshop) | หน้า login ของ Ubuntu ที่แยกเป็นของตัวเอง |
| **2) HDMI** | ต่อจออยู่และมีคน login ค้างไว้บนจอ | desktop เดียวกับที่อยู่บนจอ |

#### สคริปต์ทำอะไร

1. **ยอมรับ distribution terms** บอร์ดใหม่จะขึ้นหน้า "Confirm" ก่อนหน้า login ถ้าไม่ได้ต่อจอ จะกดหน้านี้ไม่ได้ และ desktop จะไม่เปิดเลย สคริปต์จะแสดงข้อความเดียวกับในหน้านั้นแล้วถามว่ายอมรับไหม ได้ผลเหมือนกด Confirm บนจอ
2. **ตั้ง user และรหัสผ่านของ RDP** คุณพิมพ์เอง รหัสจะไม่ขึ้นบนจอ
3. **สร้าง TLS certificate แล้วเปิด RDP** ที่พอร์ต 3389 (โหมด 2 อาจใช้พอร์ต 3390 ถ้า 3389 ถูกใช้อยู่ สคริปต์จะบอกตอนจบ)

#### ต่อจากโน้ตบุ๊ก

| เครื่อง | โปรแกรม |
|---|---|
| Windows | Remote Desktop Connection (`mstsc`) |
| macOS | Windows App (App Store) |
| Linux | Remmina |

ใส่ IP ของบอร์ดที่สคริปต์พิมพ์ให้ตอนจบ หรือดูเองด้วย `hostname -I`

- **โหมด 1:** login 2 ชั้น ชั้นแรกคือ user และรหัส RDP ชั้นที่สองคือ user ปกติของ Ubuntu
- **โหมด 2:** login ชั้นเดียวด้วย user และรหัส RDP แล้วจะเห็นจอเดียวกับบนบอร์ด

#### คำสั่งอื่น

```bash
sudo ./setup_rdp.sh --status    # ดูสถานะอย่างเดียว ไม่แก้อะไร
sudo ./setup_rdp.sh --fix       # แก้จอดำหลัง login ผ่าน RDP
sudo ./setup_rdp.sh --disable   # ปิด RDP ทั้งสองโหมด
```

#### ใช้ไม่ได้?

| อาการ | ลองทำ |
|---|---|
| ต่อไม่ติด | เช็กว่าบอร์ดกับโน้ตบุ๊กอยู่ network เดียวกัน และ `--status` ต้องขึ้น `listening` |
| login แล้วจอดำหรือเด้งกลับหน้า login | รัน `sudo ./setup_rdp.sh --fix` (แก้เจ้าของ `/tmp/.X11-unix` ให้เป็น root) หรือ reboot บอร์ด |
| ต่อได้แต่จอดำตั้งแต่แรก | เช็กว่า `systemctl status gdm` เป็น `active` |
| ขึ้น "This connection is insecure" | เป็นเรื่องปกติ กด Continue ได้เลย หรือเซฟไฟล์ .rdp แล้วเพิ่มบรรทัด `use redirection server name:i:1` |
| โหมด 2 บอกว่าไม่มี desktop session | ต้อง login บนจอก่อน หรือใช้โหมด 1 แทน |
| ใส่รหัส RDP ไม่ผ่าน | รัน `sudo ./setup_rdp.sh` ใหม่แล้วตั้งรหัสใหม่ |

ทดสอบกับ Ubuntu 24.04.4 LTS (GNOME 46) บน VENTUNO Q
