#!/usr/bin/env
"""
供 Foundry vm.ffi 调用的 wadExp / wadLn / wadPow 高精度计算器
输入：op x_wad [y_wad]
输出：abi.encode(int256) 的 hex 字符串（供 abi.decode 解析）
"""

import sys
from decimal import Decimal, getcontext

getcontext().prec = 50

WAD = Decimal(10**18)


def wad_exp(x_wad: int) -> int:
    x = Decimal(x_wad) / WAD
    return int(x.exp() * WAD)


def wad_ln(x_wad: int) -> int:
    x = Decimal(x_wad) / WAD
    return int(x.ln() * WAD)


def wad_pow(x_wad: int, y_wad: int) -> int:
    x = Decimal(x_wad) / WAD
    y = Decimal(y_wad) / WAD
    return int(x**y * WAD)


op = sys.argv[1]
x_wad = int(sys.argv[2])

if op == "exp":
    result = wad_exp(x_wad)
elif op == "ln":
    result = wad_ln(x_wad)
elif op == "pow":
    y_wad = int(sys.argv[3])
    result = wad_pow(x_wad, y_wad)
else:
    sys.exit(1)

# 输出 abi.encode(int256)：32 字节，二补码，hex 前缀 0x
print("0x" + result.to_bytes(32, byteorder="big", signed=True).hex())
