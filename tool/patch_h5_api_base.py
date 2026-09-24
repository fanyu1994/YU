#!/usr/bin/env python3
"""把 uni-app 构建产物里硬编码的后端地址改成运行时解析的同源地址。

背景：assets/h5/safety 是 uni-app 编译出的 H5 包，构建时通过 DefinePlugin 把
`VUE_APP_BASE_URL` 直接内联成了字符串字面量（共 101 处），例如：

    uni.request({ url: "http://172.23.2.87/hussarApi" + t.url })
    fetch("".concat("http://172.23.2.87/hussarApi").concat(t))

App 内 WebView 的页面源是 http://127.0.0.1:8848，直接请求 172.23.2.87 属于跨域，
而目标服务端没有返回 Access-Control-Allow-Origin，预检（OPTIONS）失败，于是所有
接口都报 CORS 错误。

脚本把该字面量替换为 `(window.__H5_API_BASE__ || "/hussarApi")`：
- 默认走同源相对路径，由 lib/utils/h5server.dart 的反向代理转发到真实后端 -> 无跨域
- 需要临时切换环境时，只要在页面里提前设置 window.__H5_API_BASE__ 即可

可重复执行（幂等）。用法：
    python3 tool/patch_h5_api_base.py            # 执行替换
    python3 tool/patch_h5_api_base.py --check     # 只检查是否还有硬编码
"""

from __future__ import annotations

import argparse
import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
JS_GLOB = "assets/h5/safety/static/js/**/*.js"

# 构建产物里写死的后端地址（VUE_APP_BASE_URL）
ORIGINAL = '"http://172.23.2.87/hussarApi"'
PATCHED = '(window.__H5_API_BASE__||"/hussarApi")'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="只检查是否残留硬编码地址，不修改文件",
    )
    args = parser.parse_args()

    files = sorted(REPO_ROOT.glob(JS_GLOB))
    if not files:
        print(f"未找到构建产物：{JS_GLOB}", file=sys.stderr)
        return 1

    changed_files = 0
    replaced = 0
    remaining = 0

    for path in files:
        text = path.read_text(encoding="utf-8")
        if ORIGINAL not in text:
            continue

        if args.check:
            remaining += text.count(ORIGINAL)
            print(f"[硬编码] {path.relative_to(REPO_ROOT)}: {text.count(ORIGINAL)} 处")
            continue

        count = text.count(ORIGINAL)
        path.write_text(text.replace(ORIGINAL, PATCHED), encoding="utf-8")
        changed_files += 1
        replaced += count
        print(f"[已替换] {path.relative_to(REPO_ROOT)}: {count} 处")

    if args.check:
        if remaining:
            print(f"\n仍有 {remaining} 处硬编码地址，请执行 python3 {pathlib.Path(__file__).name}")
            return 1
        print("没有发现硬编码地址，构建产物已经是同源相对路径。")
        return 0

    if replaced == 0:
        print("没有需要替换的内容（可能已经打过补丁）。")
        return 0

    print(f"\n完成：{changed_files} 个文件，共 {replaced} 处替换。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
