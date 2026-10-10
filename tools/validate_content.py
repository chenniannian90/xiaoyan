#!/usr/bin/env python3
"""内容包校验:打包进 App 之前必须过这一关。

用法:
    python3 tools/validate_content.py app/assets/content/salt-water-egg
    python3 tools/validate_content.py app/assets/content     # 整个目录下所有内容包

查五件事:
    1. topic.json 合不合 content-schema/topic.schema.json
    2. 每句引用的音频文件在不在 <包>/audio/,而且是真音频(能读出格式和时长)
    3. 每处引用的积木在不在 content-schema/bricks.json 里登记过
    4. slug 和目录名一致
    5. 时长合不合理(太短/太长说明生成坏了 —— 比如错误 JSON 被当成音频存下来)

音频缺失是「警告」不是「失败」:App 有系统 TTS 兜底,先跑内容后补音频是允许的。
加 --strict 则把警告也当失败(打包发布时用)。

依赖 jsonschema(Python 标准库没有 JSON Schema 实现)。
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    print("缺 jsonschema,装一下:pip install jsonschema", file=sys.stderr)
    sys.exit(2)

REPO = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO / "content-schema" / "topic.schema.json"
BRICKS_PATH = REPO / "content-schema" / "bricks.json"

MIN_SECONDS = 0.5
MAX_SECONDS = 30.0

# MPEG 音频头查询表(MP3 时长解析用)
_BITRATE = {
    3: [None, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, None],
    2: [None, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, None],
}
_SAMPLERATE = {3: [44100, 48000, 32000, None], 2: [22050, 24000, 16000, None], 0: [11025, 12000, 8000, None]}
_MPEG_VERSION = {0: 0, 2: 2, 3: 3}  # 0 = MPEG 2.5


class NotAudio(Exception):
    pass


def probe_wav(blob: bytes) -> tuple[float, list[str]]:
    """返回 (时长秒, 备注)。CosyVoice 生成的 WAV 头部 data 长度字段是占位值,
    所以时长按文件实际字节数算,不按声明值算。"""
    notes: list[str] = []
    pos, fmt, data_offset, declared = 12, None, None, None
    while pos + 8 <= len(blob):
        cid = blob[pos : pos + 4]
        size = struct.unpack("<I", blob[pos + 4 : pos + 8])[0]
        if cid == b"fmt ":
            _, ch, sr, _, _, bits = struct.unpack("<HHIIHH", blob[pos + 8 : pos + 24])
            fmt = (ch, sr, bits)
        elif cid == b"data":
            data_offset, declared = pos + 8, size
        pos += 8 + size + (size & 1)
    if fmt is None or data_offset is None:
        raise NotAudio("WAV 里没找到 fmt 或 data 块")
    ch, sr, bits = fmt
    actual = len(blob) - data_offset
    if declared != actual:
        notes.append(f"data 长度字段声明 {declared}、实际 {actual}(CosyVoice 的占位值)")
    return actual / (sr * ch * bits // 8), notes


def probe_mp3(blob: bytes) -> tuple[float, list[str]]:
    pos = 0
    if blob[:3] == b"ID3":
        tag = (blob[6] & 0x7F) << 21 | (blob[7] & 0x7F) << 14 | (blob[8] & 0x7F) << 7 | (blob[9] & 0x7F)
        pos = 10 + tag
    frames, duration = 0, 0.0
    while pos + 4 <= len(blob):
        head = struct.unpack(">I", blob[pos : pos + 4])[0]
        if (head >> 21) != 0x7FF:
            pos += 1
            continue
        ver = _MPEG_VERSION.get((head >> 19) & 0x3)
        layer = (head >> 17) & 0x3  # 01 = Layer III
        bridx, sridx, pad = (head >> 12) & 0xF, (head >> 10) & 0x3, (head >> 9) & 0x1
        if ver is None or layer != 1 or _BITRATE[ver][bridx] is None or _SAMPLERATE[ver][sridx] is None:
            pos += 1
            continue
        bitrate, rate = _BITRATE[ver][bridx], _SAMPLERATE[ver][sridx]
        per_frame = 1152 if ver == 3 else 576
        frame_len = (144 if ver == 3 else 72) * bitrate * 1000 // rate + pad
        if frame_len <= 4:
            break
        frames += 1
        duration += per_frame / rate
        pos += frame_len
    if frames == 0:
        raise NotAudio("MP3 里一帧都没解析出来")
    return duration, []


def probe_audio(path: Path) -> tuple[str, float, list[str]]:
    """返回 (格式, 时长秒, 备注)。读不出音频就抛 NotAudio。"""
    blob = path.read_bytes()
    if blob.lstrip()[:1] in (b"{", b"<"):
        raise NotAudio(f"这不是音频,是文本(像是接口报错被存下来了):{blob[:120]!r}")
    if blob[:4] == b"RIFF" and blob[8:12] == b"WAVE":
        duration, notes = probe_wav(blob)
        return "wav", duration, notes
    duration, notes = probe_mp3(blob)
    return "mp3", duration, notes


def registered_bricks() -> set[str]:
    data = json.loads(BRICKS_PATH.read_text(encoding="utf-8"))
    return {b["name"] for b in data["bricks"]}


def used_bricks(topic: dict) -> list[str]:
    names: list[str] = []
    for step in topic.get("learn", {}).get("steps", []):
        for call in step.get("bricks", []):
            names.append(call["brick"])
    for step in topic.get("experiment", {}).get("steps", []):
        for call in step.get("bricks", []):
            names.append(call["brick"])
    return names


def referenced_audio(topic: dict) -> list[str]:
    files: list[str] = []
    for step in topic.get("learn", {}).get("steps", []):
        files.append(step["audio"])
    for step in topic.get("experiment", {}).get("steps", []):
        files.append(step["audio"])
    return files


def check_package(pkg: Path, schema: dict, bricks: set[str], strict: bool) -> tuple[list[str], list[str]]:
    """返回 (错误, 警告)。"""
    errors: list[str] = []
    warnings: list[str] = []

    topic_path = pkg / "topic.json"
    if not topic_path.is_file():
        return [f"{pkg}: 没有 topic.json"], warnings

    try:
        topic = json.loads(topic_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"{pkg}/topic.json: JSON 语法错误 —— {e}"], warnings

    # 1. schema
    validator = jsonschema.Draft7Validator(schema)
    for err in sorted(validator.iter_errors(topic), key=lambda e: list(e.absolute_path)):
        where = "/".join(str(p) for p in err.absolute_path) or "(根)"
        errors.append(f"{pkg}/topic.json: [{where}] {err.message}")

    # 2/5. 音频:在不在 + 是不是真音频 + 时长合不合理
    for name in referenced_audio(topic):
        target = pkg / "audio" / name
        if not target.is_file():
            warnings.append(f"{pkg}: 缺音频 audio/{name}(App 会用系统 TTS 兜底)")
            continue
        try:
            fmt, duration, notes = probe_audio(target)
        except NotAudio as e:
            errors.append(f"{pkg}: audio/{name} 读不出音频 —— {e}")
            continue
        if not (MIN_SECONDS <= duration <= MAX_SECONDS):
            errors.append(f"{pkg}: audio/{name} 时长 {duration:.2f}s 不在合理区间 [{MIN_SECONDS}, {MAX_SECONDS}]")
        for note in notes:
            warnings.append(f"{pkg}: audio/{name} {note}")

    # 3. 积木引用
    for name in sorted(set(used_bricks(topic))):
        if name not in bricks:
            errors.append(f"{pkg}: 积木 {name} 没在 content-schema/bricks.json 里登记")

    # 4. slug 和目录名
    slug = topic.get("slug")
    if slug and slug != pkg.name:
        errors.append(f"{pkg}: slug 是 {slug},和目录名对不上")

    if strict and warnings:
        errors.extend(warnings)
        warnings = []

    return errors, warnings


def main() -> int:
    ap = argparse.ArgumentParser(description="校验内容包")
    ap.add_argument("path", type=Path, help="内容包目录,或装着多个内容包的目录")
    ap.add_argument("--strict", action="store_true", help="警告也当失败(打包发布时用)")
    args = ap.parse_args()

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    bricks = registered_bricks()

    if (args.path / "topic.json").is_file():
        packages = [args.path]
    else:
        packages = sorted(p for p in args.path.iterdir() if (p / "topic.json").is_file())

    if not packages:
        print(f"{args.path} 下面没找到内容包(没有 topic.json)", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    all_warnings: list[str] = []
    for pkg in packages:
        errors, warnings = check_package(pkg, schema, bricks, args.strict)
        all_errors += errors
        all_warnings += warnings

    for w in all_warnings:
        print(f"警告  {w}")
    for e in all_errors:
        print(f"错误  {e}")

    print()
    if all_errors:
        print(f"{len(packages)} 个内容包:{len(all_errors)} 个错误,{len(all_warnings)} 个警告 —— 不通过。")
        return 1
    if all_warnings:
        print(f"{len(packages)} 个内容包:0 个错误,{len(all_warnings)} 个警告 —— 通过(有警告)。")
        return 0
    print(f"{len(packages)} 个内容包:全部通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
