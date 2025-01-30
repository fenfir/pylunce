import serial
import time


def read_contacts(device: str):
    percentage = 2.0
    read_command = [
        0x68,  # Sync
        0x31,  # Command
        0x00,  # UNK
        0x01,
        0x00,  # % Complete
        0xEB,  # UNK  0xCD = Read Bitmap 0xCF = Read Memory
        0x00,  # Read Length
        0x04,
        0x00,  # Block Address
        0x0D,
        0x10,  # Terminator
    ]

    ser = serial.Serial(
        device,
        baudrate=115200,
        parity=serial.PARITY_NONE,
        bytesize=8,
        stopbits=1,
        rtscts=True,
    )

    read_contacts = bytearray(read_command)
    ser.write(read_contacts)
    ser.flush()

    while percentage <= 100:
        received_data = bytearray()
        while ser.in_waiting:
            d = ser.read(1)
            received_data.extend(d)

        print("".join("{:02x} ".format(x) for x in received_data))

        if len(received_data) < 10:
            continue

        percentage += 2.5
        address = received_data[9] << 8 | received_data[8] + 1
        read_command = [
            0x68,  # Sync
            0x31,  # Command
            0x00,  # UNK
            0x01,
            min(round(percentage), 100),  # % Complete
            0xEB,  # UNK  0xCD = Read Bitmap 0xCF = Read Memory
            0x00,  # Read Length
            0x04,
            address & 0xFF,  # Block Address
            address >> 8,
            0x10,  # Terminator
        ]
        read_contacts = bytearray(read_command)
        ser.write(read_contacts)
        ser.flush()


def get_version(device: str):
    ser = serial.Serial(
        device,
        baudrate=115200,
        parity=serial.PARITY_NONE,
        bytesize=8,
        stopbits=1,
        rtscts=False,
        dsrdtr=False,
    )

    ser.write(bytearray("GetVer".encode(encoding="ASCII")))
    ser.flush()

    time.sleep(0.1)
    received_data = bytearray()
    while ser.in_waiting:
        d = ser.read(1)
        received_data.extend(d)

    s = "".join("{:02x} ".format(x) for x in received_data)
    print(received_data)


get_version("/dev/ttyUSB0")
