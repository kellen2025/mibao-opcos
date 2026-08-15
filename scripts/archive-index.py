#!/usr/bin/env python3
"""档案室 INDEX 自动生成器
扫描档案室目录 → 自动生成 INDEX.md（目录树 + 文件清单）
用法：python3 archive-index.py [档案室路径]
默认路径：/media/kellen/DATE/hermes 或 $ARCHIVES_DIR
"""
import os, sys, datetime

def get_archives_root():
    # 优先 ARCHIVES_DIR 环境变量，其次默认外部盘，最后 home
    env = os.environ.get("ARCHIVES_DIR", "")
    if env and os.path.isdir(env):
        return env
    for p in ["/media/kellen/DATE/hermes", os.path.expanduser("~/.hermes/archives")]:
        if os.path.isdir(p):
            return p
    return os.path.expanduser("~/.hermes/archives")

def build_tree(root):
    """返回 {分类: {子分类: [文件]}}"""
    tree = {}
    for entry in sorted(os.listdir(root)):
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            continue  # 顶层只放 INDEX
        if not os.path.isdir(full):
            continue
        tree[entry] = {}
        for sub in sorted(os.listdir(full)):
            sub_full = os.path.join(full, sub)
            if os.path.isdir(sub_full):
                files = [f for f in sorted(os.listdir(sub_full)) if not f.startswith(".")]
                if files:
                    tree[entry][sub] = files
            elif os.path.isfile(sub_full) and not sub.startswith("."):
                tree[entry].setdefault("_files", []).append(sub)
    return tree

def render(root, tree):
    now = datetime.date.today().isoformat()
    total = sum(len(files) for cat in tree.values() for files in cat.values())
    lines = [
        "---",
        "title: 档案室索引（自动生成）",
        f"created: {now}",
        f"updated: {now}",
        "author: 米宝OpcOS",
        "category: 机制",
        "tags: [索引, 档案室]",
        "status: active",
        "version: auto",
        "---",
        "",
        "# 档案室索引",
        "",
        f"> 自动生成于 {now}（archive-index.py）| 共 {total} 个文件",
        "",
    ]
    for cat, subs in tree.items():
        lines.append(f"## {cat}/")
        for sub, files in subs.items():
            if sub == "_files":
                for f in files:
                    lines.append(f"- {f}")
            else:
                lines.append(f"### {sub}/")
                for f in files:
                    lines.append(f"  - {f}")
        lines.append("")
    return "\n".join(lines)

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else get_archives_root()
    tree = build_tree(root)
    content = render(root, tree)
    idx = os.path.join(root, "INDEX.md")
    with open(idx, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"✓ INDEX.md 已生成: {idx}")
    print(f"  共 {sum(len(files) for cat in tree.values() for files in cat.values())} 个文件")
