#!/usr/bin/env python3
"""按内容包 topic.json 逐句生成语音。

用法:
    export DASHSCOPE_API_KEY=sk-xxxx
    python3 tools/gen_audio.py app/assets/content/salt-water-egg

默认走阿里云百炼 CosyVoice(cosyvoice-v3-flash + longhuhu_v3 童声「龙呼呼」)。
百炼账号没开通 CosyVoice 时会明确报错;加 --fallback-qwen-tts 退回 qwen-tts 的
Cherry 童声(音色不同,会在输出里写清楚)。

选项:
    --force             已存在的音频也重新生成
    --format {wav,mp3}  输出格式,默认 wav
    --voice NAME        覆盖音色
    --model NAME        覆盖模型
    --dry-run           只列出要生成哪些句子,不调接口
    --fallback-qwen-tts CosyVoice 失败时退回 qwen-tts

只用标准库,不装依赖。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

COSYVOICE_URL = "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer"
QWEN_TTS_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"

DEFAULT_MODEL = "cosyvoice-v3-flash"
DEFAULT_VOICE = "longhuhu_v3"
FALLBACK_MODEL = "qwen-tts"
FALLBACK_VOICE = "Cherry"

TIMEOUT = 90
RETRIES = 2


class SynthError(RuntimeError):
    pass


def collect_sentences(topic: dict) -> list[tuple[str, str]]:
    """返回 [(音频文件名, 文案)],学 + 做两段,按出现顺序。"""
    out: list[tuple[str, str]] = []
    for step in topic.get("learn", {}).get("steps", []):
        out.append((step["audio"], step["text"]))
    for step in topic.get("experiment", {}).get("steps", []):
        out.append((step["audio"], step["text"]))
    return out


def _post_json(url: str, payload: dict, api_key: str) -> tuple[bytes, str]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.read(), resp.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise SynthError(f"HTTP {e.code}: {body[:500]}") from None
    except urllib.error.URLError as e:
        raise SynthError(f"网络错误: {e}") from None


def _download(url: str) -> bytes:
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
            return resp.read()
    except urllib.error.URLError as e:
        raise SynthError(f"下载音频失败: {e}") from None


def synth_cosyvoice(text: str, api_key: str, model: str, voice: str, fmt: str) -> bytes:
    """CosyVoice 非实时合成:返回 JSON,里面给一个 24 小时有效的音频地址,再下载回来。

    注意 voice / format / sample_rate 在 input 里,不在 parameters 里。
    """
    payload = {
        "model": model,
        "input": {
            "text": text,
            "voice": voice,
            "format": fmt,
            "sample_rate": 22050,
        },
    }
    data, _ = _post_json(COSYVOICE_URL, payload, api_key)
    try:
        body = json.loads(data)
    except json.JSONDecodeError:
        raise SynthError(f"接口没返回 JSON: {data[:300].decode('utf-8', 'replace')}") from None
    audio_url = (body.get("output") or {}).get("audio", {}).get("url")
    if not audio_url:
        raise SynthError(f"返回里没有音频地址: {json.dumps(body, ensure_ascii=False)[:500]}")
    return _download(audio_url)


def synth_qwen_tts(text: str, api_key: str, fmt: str) -> bytes:
    """qwen-tts 走多模态端点,返回一个 OSS 音频地址,再下载回来。"""
    payload = {
        "model": FALLBACK_MODEL,
        "input": {"text": text, "voice": FALLBACK_VOICE},
        "parameters": {"format": fmt, "sample_rate": 24000},
    }
    data, _ = _post_json(QWEN_TTS_URL, payload, api_key)
    body = json.loads(data)
    audio_url = (body.get("output") or {}).get("audio", {}).get("url")
    if not audio_url:
        raise SynthError(f"返回里没有音频地址: {json.dumps(body, ensure_ascii=False)[:500]}")
    return _download(audio_url)


def main() -> int:
    ap = argparse.ArgumentParser(description="按 topic.json 逐句生成语音")
    ap.add_argument("package_dir", type=Path, help="内容包目录(含 topic.json)")
    ap.add_argument("--force", action="store_true", help="已存在的音频也重新生成")
    ap.add_argument("--format", default="mp3", choices=["wav", "mp3"])
    ap.add_argument("--voice", default=DEFAULT_VOICE)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--fallback-qwen-tts", action="store_true")
    args = ap.parse_args()

    topic_path = args.package_dir / "topic.json"
    if not topic_path.is_file():
        print(f"找不到 {topic_path}", file=sys.stderr)
        return 1
    topic = json.loads(topic_path.read_text(encoding="utf-8"))

    sentences = collect_sentences(topic)
    if not sentences:
        print("topic.json 里没有任何句子", file=sys.stderr)
        return 1

    audio_dir = args.package_dir / "audio"
    mismatched = [name for name, _ in sentences if not name.endswith(f".{args.format}")]
    if mismatched:
        print(
            f"topic.json 里的音频名和 --format {args.format} 对不上:{', '.join(mismatched)}",
            file=sys.stderr,
        )
        print("要么改 topic.json 的后缀,要么改 --format —— 别让 mp3 装进 .wav 的名字里。", file=sys.stderr)
        return 1

    print(f"内容包: {topic.get('title')} ({topic.get('slug')})")
    print(f"句子数: {len(sentences)}  输出到: {audio_dir}")
    if args.dry_run:
        for name, text in sentences:
            print(f"  {name:12s} {len(text):3d} 字  {text}")
        return 0

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        print("环境变量 DASHSCOPE_API_KEY 没设置,没法生成。", file=sys.stderr)
        return 1

    audio_dir.mkdir(parents=True, exist_ok=True)
    used_fallback = False
    failed: list[tuple[str, str]] = []

    for name, text in sentences:
        target = audio_dir / name
        if target.exists() and not args.force:
            print(f"  跳过 {name}(已存在)")
            continue

        last_err = None
        for attempt in range(1, RETRIES + 1):
            try:
                blob = synth_cosyvoice(text, api_key, args.model, args.voice, args.format)
                voice_label = f"{args.model}/{args.voice}"
                break
            except SynthError as e:
                last_err = e
                if args.fallback_qwen_tts:
                    try:
                        blob = synth_qwen_tts(text, api_key, args.format)
                        voice_label = f"{FALLBACK_MODEL}/{FALLBACK_VOICE}(退回)"
                        used_fallback = True
                        break
                    except SynthError as e2:
                        last_err = e2
                if attempt < RETRIES:
                    time.sleep(2 * attempt)
        else:
            print(f"  失败 {name}: {last_err}", file=sys.stderr)
            failed.append((name, str(last_err)))
            continue

        target.write_bytes(blob)
        print(f"  生成 {name}  {len(blob)/1024:6.1f} KB  [{voice_label}]")

    print()
    if used_fallback:
        print("!! 有句子退回了 qwen-tts/Cherry,不是龙呼呼音色 —— 原因见上面的报错。")
    if failed:
        print(f"完成,{len(sentences) - len(failed)}/{len(sentences)} 成功,{len(failed)} 句失败。")
        for name, err in failed:
            print(f"  - {name}: {err}")
        return 1
    print(f"完成,{len(sentences)} 句全部成功。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
