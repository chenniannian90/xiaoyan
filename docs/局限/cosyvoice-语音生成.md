# 局限:CosyVoice 语音生成

记录日期:2026-10-10(「盐水浮鸡蛋」冒烟包跑通时)

## 已定量、原因已知的

### CosyVoice 的 wav 输出,`data` 块长度字段是占位值

- 现象:生成的 `.wav` 里 `data` chunk 声明长度 `0x7FFFFFDB`(2147483547),而实际音频数据只有约 28 万字节。`fmt` 块本身是对的(22050Hz / 单声道 / 16bit)
- 出处:用 `tools/gen_audio.py --format wav` 生成 `s01.wav` 后解析 RIFF 块(2026-10-10 实测)
- 影响:按声明长度判断结尾的播放器会读错长度,可能提前结束或报错;也没法拿声明值算时长
- 已定因:阿里云侧生成时的占位写法,不是我们写坏了
- 处理:内容包音频统一改用 **mp3**(`--format mp3`),绕开这一类问题;校验器 `validate_content.py` 里的 `probe_wav` 也改成按实际字节数算时长,不认声明值

### 本机没有 ffmpeg / ffprobe

- 出处:`which ffmpeg ffprobe` 都为空(2026-10-10)
- 影响:音频没法用成熟工具探测、转码;`tools/validate_content.py` 只能自己实现 wav / mp3 的时长解析
- 现状:够用。mp3 解析器拿 `s01` 的 wav 真值(6.36s)校准过,估出 6.43s(差 1%,是 mp3 帧填充导致的)

### `study` 仓库里的 CosyVoice 端点写错了

- 现象:`study/src/lib/tts-client.ts` 用 `POST /api/v1/services/audio/tts/generation`,实测 11 句全部返回 `400 InvalidParameter: url error, please check url`
- 出处:2026-10-10 照该端点请求一次
- 已定因:正确端点是 `/api/v1/services/audio/tts/SpeechSynthesizer`,并且 `voice` / `format` / `sample_rate` 要放在 `input` 里。那段代码在该仓库里从未被执行过(实际路由走的是 qwen-tts)
- 现状:这是 `study` 的问题,本仓库按正确端点实现,不受影响

### `study` 里「龙呼呼需在百炼控制台开通 CosyVoice」的说法不成立

- 出处:2026-10-10 直接调 `cosyvoice-v3-flash` + `longhuhu_v3`,11 句全部成功
- 结论:该账号可直接用,不需要额外开通;`study` 那条注释过时了

## 已验的

- **听感**:2026-10-10 用户听过全部 11 句,确认声音可以——童声、语速、断句都没问题

## 没验的(别当已知)

- **逐字读音校对**:整体听感没问题,但没有拿文稿逐字对照校对过(多音字、生僻词这类)
- **长句稳定性**:目前最长 33 字。再长会不会断句奇怪、有没有长度上限,没试
- **批量与限流**:一次只跑过 11 句。几十句连着跑会不会被限流,没试
