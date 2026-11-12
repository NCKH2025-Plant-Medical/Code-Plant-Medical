"""Mở SSH tunnel tới MongoDB của server, giữ cửa sổ terminal trong khi web chạy.

Cách dùng (cửa sổ terminal riêng, để nguyên):
    python admin_web/tools/tunnel.py

Sau đó MONGO_URI trong .env đặt là:
    mongodb://127.0.0.1:27017

Tunnel:  222.255.184.116:22  →  localhost:27017
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from config import MONGO_URI  # noqa: E402

DEFAULT_SERVER = "222.255.184.116"
DEFAULT_LOCAL_PORT = 27017
DEFAULT_REMOTE_PORT = 27017


def main() -> int:
    parser = argparse.ArgumentParser(description="SSH tunnel tới MongoDB")
    parser.add_argument("--server", default=DEFAULT_SERVER)
    parser.add_argument("--user", default="root")
    parser.add_argument("--key", default="")
    parser.add_argument("--local-port", type=int, default=DEFAULT_LOCAL_PORT)
    parser.add_argument("--remote-port", type=int, default=DEFAULT_REMOTE_PORT)
    args = parser.parse_args()

    ssh = ["ssh", "-N", "-T",
           "-o", "StrictHostKeyChecking=accept-new",
           "-o", "ServerAliveInterval=30",
           "-L", f"{args.local_port}:127.0.0.1:{args.remote_port}"]
    if args.key:
        ssh += ["-i", args.key]
    ssh.append(f"{args.user}@{args.server}")

    print("Đang mở SSH tunnel:")
    print("  " + " ".join(ssh))
    print()
    print(f"  MongoDB giờ truy cập tại: mongodb://127.0.0.1:{args.local_port}")
    print("  Đặt MONGO_URI trong .env thành:")
    print(f"      MONGO_URI=mongodb://127.0.0.1:{args.local_port}")
    print()
    print("Nhấn Ctrl+C để đóng tunnel.")

    try:
        proc = subprocess.run(ssh)
    except KeyboardInterrupt:
        print("\nĐã đóng tunnel.")
        return 0
    except FileNotFoundError:
        print("✗ Không tìm thấy lệnh ssh. Cài OpenSSH Client trên Windows.")
        return 1

    if proc.returncode != 0:
        print(f"✗ ssh kết thúc với mã {proc.returncode} (sai user/key hoặc server từ chối)")
        return proc.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
