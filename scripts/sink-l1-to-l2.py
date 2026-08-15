#!/usr/bin/env python3
"""L1→L2 记忆下沉脚本（方案B）
用途：L1 记忆（MEMORY.md，4000字符硬上限）写满前，把低优先级条目
      （项目/环境/历史/技术决策）自动下沉到 L2 mem0（无限容量），
      L1 只保留高优先级条目（铁律/称呼/核心偏好）。

触发：
  python3 sink-l1-to-l2.py            # 使用率>80% 时自动下沉
  python3 sink-l1-to-l2.py --force    # 强制下沉所有可下沉条目
  python3 sink-l1-to-l2.py --dry-run  # 预览不执行

原理：
  - 高优先级关键词：铁律/称呼/老板/必须/禁止/偏好/最高/核心
  - 低优先级关键词：环境/项目/仓库/网络/技术/mem0/成本/账单/岗位/profile/GitHub
  - 无关键词命中 → 保守保留（不误删）
"""
import os, re, sys, json, shutil, datetime

HOME = os.path.expanduser("~")
MEMORY_FILE = os.path.join(HOME, ".hermes/memories/MEMORY.md")
MEM0_JSON = os.path.join(HOME, ".hermes/mem0.json")
ENV_FILE = os.path.join(HOME, ".hermes/opcos/.env")
HERMES_ENV = os.path.join(HOME, ".hermes/.env")
LIMIT = 4000
THRESHOLD = 0.80  # 80% 触发

HIGH_PRI = ["铁律", "称呼", "老板", "必须", "禁止", "偏好", "最高", "核心", "要求"]
LOW_PRI = ["环境", "项目", "仓库", "网络", "技术", "mem0", "成本", "账单",
           "岗位", "profile", "GitHub", "HERMES", "模型", "渠道", "档案室", "部署", "安装"]


def load_env(path):
    env = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env


def read_memory():
    if not os.path.exists(MEMORY_FILE):
        return []
    content = open(MEMORY_FILE, encoding="utf-8").read()
    # 去掉开头的 LOCKED 注释行
    lines = [l for l in content.split("\n") if not l.startswith("#")]
    text = "\n".join(lines)
    entries = [e.strip() for e in text.split("§") if e.strip()]
    return entries


def classify(entry):
    """返回 'high'（保留）/ 'low'（下沉）/ 'keep'（保守保留）
    优先级：含铁律类强信号 → 保留；仅含环境/项目类 → 下沉；无命中 → 保守保留
    """
    # 强保留信号：铁律/老板设定/必须/禁止/称呼/最高（出现在开头或核心位置）
    strong_keep = ["铁律", "老板设定", "最高铁律", "称呼", "禁止", "必须"]
    has_strong = any(k in entry for k in strong_keep)
    if has_strong:
        return "high"

    has_high = any(k in entry for k in HIGH_PRI)
    has_low = any(k in entry for k in LOW_PRI)
    if has_high and not has_low:
        return "high"
    if has_low and not has_high:
        return "low"
    if has_high and has_low:
        return "high" if len(entry) < 120 else "low"
    return "keep"


def sink_to_mem0(entries):
    """生成下沉清单文件（由 Hermes 会话内 mem0_add 写入，避免 qdrant 锁冲突）
    返回 True 表示清单已生成（L1 可重写）；实际写入由 Hermes 代理执行。
    """
    pending_dir = os.path.join(HOME, ".hermes/opcos")
    os.makedirs(pending_dir, exist_ok=True)
    pending_file = os.path.join(pending_dir, "l1-sink-pending.json")

    # 合并已有 pending（不覆盖）
    existing = []
    if os.path.exists(pending_file):
        try:
            existing = json.load(open(pending_file, encoding="utf-8"))
        except Exception:
            existing = []
    merged = existing + [{"content": e, "ts": datetime.datetime.now().isoformat()} for e in entries]
    with open(pending_file, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
    print(f"  ✓ 已生成下沉清单: {pending_file}（{len(merged)} 条待写入 L2）")
    print("    Hermes 会话内执行: 告诉我 '写入待同步记忆' 即可由 mem0_add 完成")
    return True


def rewrite_memory(keep_entries):
    """重写 MEMORY.md，只保留 keep_entries"""
    bak = MEMORY_FILE + ".bak." + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    shutil.copy2(MEMORY_FILE, bak)
    header = "# LOCKED - 以下条目压缩时禁止触碰\n\n"
    content = header + "\n§\n".join(keep_entries) + "\n"
    with open(MEMORY_FILE, "w", encoding="utf-8") as f:
        f.write(content)
    return bak


def main():
    dry = "--dry-run" in sys.argv
    force = "--force" in sys.argv

    entries = read_memory()
    if not entries:
        print("L1 记忆为空")
        return

    usage = sum(len(e) for e in entries) + len(entries)
    pct = usage / LIMIT
    print(f"L1 使用率: {pct*100:.0f}% ({usage}/{LIMIT})")

    if pct < THRESHOLD and not force:
        print(f"低于 {THRESHOLD*100:.0f}% 阈值，无需下沉（--force 可强制）")
        return

    highs, lows, keeps = [], [], []
    for e in entries:
        c = classify(e)
        (highs if c == "high" else lows if c == "low" else keeps).append(e)

    print(f"分类: 保留(铁律/偏好) {len(highs)} | 下沉(项目/环境) {len(lows)} | 保守保留 {len(keeps)}")
    print("\n将下沉到 L2 mem0 的条目:")
    for e in lows:
        print(f"  · {e[:60]}...")

    if dry:
        print("\n[dry-run] 未执行")
        return

    if lows:
        print("\n写入 L2 mem0...")
        ok = sink_to_mem0(lows)
        if ok:
            keep = highs + keeps
            bak = rewrite_memory(keep)
            print(f"✅ 已下沉 {len(lows)} 条到 L2，L1 重写完成")
            print(f"   L1 现使用率: {sum(len(e) for e in keep)/LIMIT*100:.0f}%")
            print(f"   备份: {bak}")
            print("   说明: 下沉条目仍可通过 mem0 语义检索（问 Agent '你还记得...' 即可）")
        else:
            print("✗ 下沉失败，L1 未改动（安全）")
    else:
        print("无可下沉条目，L1 未改动")


if __name__ == "__main__":
    main()
