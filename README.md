# arduino_rdp_without_hdmi

เปิด Remote Desktop (RDP) บน Arduino VENTUNO Q ด้วยสคริปต์เดียว ใช้ได้ทั้งตอนที่ไม่ได้ต่อจอและตอนที่ต่อจอ HDMI อยู่

## วิธีใช้

SSH เข้าบอร์ดแล้วรัน:

```bash
git clone https://github.com/syanyong/arduino_rdp_without_hdmi.git
cd arduino_rdp_without_hdmi
chmod +x setup_rdp.sh
sudo ./setup_rdp.sh
```

สคริปต์จะให้เลือกโหมดก่อน แล้วแสดงว่าจะเปลี่ยนอะไรบ้าง และถาม **Continue?** ก่อนลงมือทุกครั้ง

| โหมด | ใช้เมื่อ | ฝั่งโน้ตบุ๊กจะเห็น |
|---|---|---|
| **1) No HDMI** | ไม่ได้ต่อจอที่บอร์ด (ใช้ใน workshop) | หน้า login ของ Ubuntu ที่แยกเป็นของตัวเอง |
| **2) HDMI** | ต่อจออยู่และมีคน login ค้างไว้บนจอ | desktop เดียวกับที่อยู่บนจอ |

### สคริปต์ทำอะไร

1. **ยอมรับ distribution terms** บอร์ดใหม่จะขึ้นหน้า "Confirm" ก่อนหน้า login ถ้าไม่ได้ต่อจอ จะกดหน้านี้ไม่ได้ และ desktop จะไม่เปิดเลย สคริปต์จะแสดงข้อความเดียวกับในหน้านั้นแล้วถามว่ายอมรับไหม ได้ผลเหมือนกด Confirm บนจอ
2. **ตั้ง user และรหัสผ่านของ RDP** คุณพิมพ์เอง รหัสจะไม่ขึ้นบนจอ
3. **สร้าง TLS certificate แล้วเปิด RDP** ที่พอร์ต 3389 (โหมด 2 อาจใช้พอร์ต 3390 ถ้า 3389 ถูกใช้อยู่ สคริปต์จะบอกตอนจบ)

### ต่อจากโน้ตบุ๊ก

| เครื่อง | โปรแกรม |
|---|---|
| Windows | Remote Desktop Connection (`mstsc`) |
| macOS | Windows App (App Store) |
| Linux | Remmina |

ใส่ IP ของบอร์ดที่สคริปต์พิมพ์ให้ตอนจบ หรือดูเองด้วย `hostname -I`

- **โหมด 1:** login 2 ชั้น ชั้นแรกคือ user และรหัส RDP ชั้นที่สองคือ user ปกติของ Ubuntu
- **โหมด 2:** login ชั้นเดียวด้วย user และรหัส RDP แล้วจะเห็นจอเดียวกับบนบอร์ด

### คำสั่งอื่น

```bash
sudo ./setup_rdp.sh --status    # ดูสถานะอย่างเดียว ไม่แก้อะไร
sudo ./setup_rdp.sh --disable   # ปิด RDP ทั้งสองโหมด
```

### ใช้ไม่ได้?

| อาการ | ลองทำ |
|---|---|
| ต่อไม่ติด | เช็กว่าบอร์ดกับโน้ตบุ๊กอยู่ network เดียวกัน และ `--status` ต้องขึ้น `listening` |
| ต่อได้แต่จอดำ | เช็กว่า `systemctl status gdm` เป็น `active` |
| โหมด 2 บอกว่าไม่มี desktop session | ต้อง login บนจอก่อน หรือใช้โหมด 1 แทน |
| ใส่รหัส RDP ไม่ผ่าน | รัน `sudo ./setup_rdp.sh` ใหม่แล้วตั้งรหัสใหม่ |

ทดสอบกับ Ubuntu 24.04.4 LTS (GNOME 46) บน VENTUNO Q
