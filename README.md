# ventuno-q-setup

สคริปต์เตรียมบอร์ด Arduino VENTUNO Q สำหรับ workshop

## เปิด Remote Desktop (ไม่ต้องต่อจอ)

SSH เข้าบอร์ดแล้วรัน:

```bash
git clone https://github.com/syanyong/ventuno-q-setup.git
cd ventuno-q-setup
chmod +x setup_rdp.sh
sudo ./setup_rdp.sh
```

สคริปต์ทำ 3 ขั้น และถามก่อนทุกครั้งที่จะแก้อะไร:

1. **ยอมรับ distribution terms**: บอร์ดใหม่จะค้างอยู่ที่หน้า "Confirm" ก่อนขึ้นหน้า login ถ้าไม่ได้ต่อจอ จะกดปุ่มนี้ไม่ได้ และ desktop จะไม่เปิดเลย สคริปต์จะแสดงข้อความเดียวกับหน้านั้น แล้วถามว่ายอมรับไหม (ได้ผลเหมือนกด Confirm บนจอ)
2. **สร้าง TLS certificate** ให้ GNOME Remote Desktop
3. **ตั้ง user และรหัสผ่านของ RDP** แล้วเปิด RDP ที่พอร์ต 3389

### ต่อจากโน้ตบุ๊ก

| เครื่อง | โปรแกรม |
|---|---|
| Windows | Remote Desktop Connection (`mstsc`) |
| macOS | Windows App (App Store) |
| Linux | Remmina |

ใส่ IP ของบอร์ด (สคริปต์พิมพ์ให้ตอนจบ หรือดูด้วย `hostname -I`) แล้ว login 2 ชั้น:

1. หน้าต่างของ Windows: user และรหัสผ่าน RDP ที่ตั้งในขั้นที่ 3
2. หน้า login ของ Ubuntu: user ปกติของบอร์ด

### คำสั่งอื่น

```bash
sudo ./setup_rdp.sh --status    # ดูสถานะอย่างเดียว ไม่แก้อะไร
sudo ./setup_rdp.sh --disable   # ปิด RDP
```

### ใช้ไม่ได้?

| อาการ | ลองทำ |
|---|---|
| ต่อไม่ติด | บอร์ดกับโน้ตบุ๊กอยู่ network เดียวกันไหม · `sudo ./setup_rdp.sh --status` ต้องขึ้น `listening` |
| ต่อได้แต่จอดำ | `systemctl status gdm` ต้องเป็น `active` |
| รหัส RDP ไม่ผ่าน | รัน `sudo ./setup_rdp.sh` ใหม่ แล้วตั้งรหัสใหม่ |

ทดสอบกับ Ubuntu 24.04.4 LTS (GNOME 46) บน VENTUNO Q
