#!/usr/bin/env python3
"""
acltool.py — setfacl/getfacl 대체 (libacl.so.1 을 ctypes 로 직접 호출)

왜 이것이 필요한가
  이 샌드박스는 apt 저장소 접속이 막혀 `acl` 패키지(setfacl/getfacl)를 설치할 수 없다
  (apt-cache policy acl → Candidate: none). 그런데 **libacl.so.1 런타임은 이미 설치**돼 있다
  (dpkg -l | grep libacl1 → 2.3.1-3). setfacl/getfacl 은 결국 이 라이브러리의 얇은 CLI 래퍼다.
  그래서 CLI 대신 **동일한 libacl 을 직접 호출**해 실제 POSIX ACL 을 설정/조회한다.
  → 만들어지는 ACL 은 진짜이며, GNU ls 의 '+' 표시와 실제 접근 테스트로 독립 검증한다.

사용
  sudo python3 acltool.py set   <path> <acl_text> [--default]
  sudo python3 acltool.py get   <path> [--default]

acl_text 예: "u::rwx,g::rwx,g:agent-core:rwx,o::---"
"""
import ctypes
import ctypes.util
import sys

ACL_TYPE_ACCESS = 0x8000
ACL_TYPE_DEFAULT = 0x4000


def load():
    for name in ("libacl.so.1", "libacl.so", ctypes.util.find_library("acl")):
        if not name:
            continue
        try:
            return ctypes.CDLL(name, use_errno=True)
        except OSError:
            continue
    raise SystemExit("libacl 을 찾을 수 없음 (libacl1 패키지 필요)")


lib = load()
lib.acl_from_text.restype = ctypes.c_void_p
lib.acl_from_text.argtypes = [ctypes.c_char_p]
lib.acl_get_file.restype = ctypes.c_void_p
lib.acl_get_file.argtypes = [ctypes.c_char_p, ctypes.c_int]
lib.acl_to_text.restype = ctypes.c_char_p
lib.acl_to_text.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ssize_t)]
lib.acl_set_file.restype = ctypes.c_int
lib.acl_set_file.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_void_p]
lib.acl_calc_mask.restype = ctypes.c_int
lib.acl_calc_mask.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
lib.acl_valid.restype = ctypes.c_int
lib.acl_valid.argtypes = [ctypes.c_void_p]
lib.acl_free.restype = ctypes.c_int
lib.acl_free.argtypes = [ctypes.c_void_p]


def to_text(acl):
    ln = ctypes.c_ssize_t(0)
    p = lib.acl_to_text(acl, ctypes.byref(ln))
    if not p:
        raise SystemExit(f"acl_to_text 실패 errno={ctypes.get_errno()}")
    return p.decode()


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    cmd, path = sys.argv[1], sys.argv[2]
    default = "--default" in sys.argv
    ttype = ACL_TYPE_DEFAULT if default else ACL_TYPE_ACCESS
    pb = path.encode()

    if cmd == "get":
        acl = lib.acl_get_file(pb, ttype)
        if not acl:
            print(f"(ACL 없음 또는 읽기 실패: errno={ctypes.get_errno()})")
            return 0
        print(f"# file: {path}" + (" (default)" if default else ""))
        print(to_text(acl))
        lib.acl_free(acl)
        return 0

    if cmd == "set":
        text = sys.argv[3]
        acl = lib.acl_from_text(text.encode())
        if not acl:
            raise SystemExit(f"acl_from_text 해석 실패: {text!r} errno={ctypes.get_errno()}")
        # mask 항목 자동 계산 (setfacl 이 해주는 것과 동일)
        holder = ctypes.c_void_p(acl)
        if lib.acl_calc_mask(ctypes.byref(holder)) != 0:
            raise SystemExit(f"acl_calc_mask 실패 errno={ctypes.get_errno()}")
        acl = holder.value
        if lib.acl_valid(acl) != 0:
            raise SystemExit(f"acl_valid 실패(필수 항목 누락 등) errno={ctypes.get_errno()}")
        rc = lib.acl_set_file(pb, ttype, acl)
        if rc != 0:
            raise SystemExit(f"acl_set_file 실패 errno={ctypes.get_errno()}")
        print(f"[OK] {path} {'default ' if default else ''}ACL 설정: {text}")
        print("--- 읽기 검증 (acl_get_file) ---")
        back = lib.acl_get_file(pb, ttype)
        print(to_text(back))
        lib.acl_free(back)
        lib.acl_free(acl)
        return 0

    raise SystemExit(f"unknown cmd: {cmd}")


if __name__ == "__main__":
    sys.exit(main())
