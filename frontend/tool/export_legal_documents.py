#!/usr/bin/env python3
"""공개 HTML 원본에서 앱의 약관 본문을 만들고 문서 내부 링크를 확인해요."""

import argparse
import json
import re
import subprocess
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "backend/deploy/vultr/site/legal"
OUTPUT = ROOT / "frontend/lib/core/legal_document_content.dart"
BASE_URL = "https://1touch.football/legal/"
VOID = {"meta", "link", "br", "hr", "img", "input"}


@dataclass
class Node:
    tag: str
    attrs: dict = field(default_factory=dict)
    children: list = field(default_factory=list)


class Document(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.root = Node("root")
        self.stack = [self.root]
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, dict(attrs))
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        assert self.stack[-1].tag == tag, f"닫는 태그를 확인해 주세요: {tag}"
        self.stack.pop()

    def handle_data(self, data):
        self.stack[-1].children.append(re.sub(r"\s+", " ", data))


def walk(node):
    yield node
    for child in node.children:
        if isinstance(child, Node):
            yield from walk(child)


def plain(node, page):
    if isinstance(node, str):
        return node
    if node.tag == "br":
        return "\n"
    value = "".join(plain(child, page) for child in node.children).strip()
    if node.tag == "a":
        target = urljoin(BASE_URL + page, node.attrs["href"])
        if not target.startswith("mailto:") and target != value:
            value += f" ({target})"
    # 넓은 웹 표는 같은 내용을 항목별 문장으로 바꿔 작은 화면에서도 읽게 해요.
    if node.tag == "table":
        rows = [child for child in walk(node) if child.tag == "tr"]
        headings = [plain(cell, page) for cell in rows[0].children
                    if isinstance(cell, Node) and cell.tag == "th"]
        return "\n\n".join(
            "\n".join(f"{headings[index]}: {plain(cell, page)}"
                      for index, cell in enumerate(
                          child for child in row.children
                          if isinstance(child, Node) and child.tag == "td"))
            for row in rows[1:]
        ) + "\n\n"
    if node.tag == "li":
        return f"• {value}\n"
    if node.tag in {"p", "h3", "small", "address", "ul", "ol", "section"}:
        return value + "\n\n"
    return value


def sections(document, page):
    main = next(node for node in walk(document.root) if node.tag == "main")
    result = []
    title, body = "Overview", []

    def append():
        text = "\n\n".join(part.strip() for part in body if part.strip())
        if text:
            match = re.match(r"^(\d+)\.\s+(.*)$", title)
            result.append({"number": match[1] if match else "",
                           "title": match[2] if match else title,
                           "body": text})

    for node in main.children:
        if isinstance(node, str) or node.tag in {"h1", "nav"}:
            continue
        if node.tag == "h2":
            append()
            title, body = plain(node, page), []
        else:
            body.append(plain(node, page))
    append()
    return result


def validate(documents):
    ids = {}
    for page, document in documents.items():
        found = [node.attrs["id"] for node in walk(document.root)
                 if "id" in node.attrs]
        assert len(found) == len(set(found)), f"중복된 문단 ID: {page}"
        ids[page] = set(found)
        assert document.stack == [document.root], f"닫히지 않은 태그: {page}"
    for page, document in documents.items():
        for node in walk(document.root):
            href = node.attrs.get("href")
            if not href:
                continue
            link = urlsplit(href)
            if link.scheme or link.netloc or link.path == "/":
                continue
            target = unquote(link.path) or page
            if target == "./":
                target = "index.html"
            assert (SOURCE / target).is_file(), f"없는 문서: {page}: {href}"
            if link.fragment:
                assert unquote(link.fragment) in ids[target], f"없는 문단: {page}: {href}"


def generate():
    documents = {path.name: Document(path.read_text()) for path in SOURCE.glob("*.html")}
    validate(documents)
    data = {name: sections(documents[page], page) for name, page in
            {"legal": "index.html", "terms": "terms.html", "privacy": "privacy.html"}.items()}
    lines = ["// 공개 HTML 원본에서 생성한 파일이에요. tool/export_legal_documents.py로 갱신해요.",
             "// 앱과 웹의 약관이 달라지지 않도록 본문을 이 파일에서 직접 수정하지 않아요.",
             "const legalDocumentContent = <String, List<({String number, String title, String body})>>{"]
    for name, entries in data.items():
        lines.append(f"  '{name}': [")
        for entry in entries:
            fields = ", ".join(f"{key}: {json.dumps(value, ensure_ascii=False).replace('$', chr(92) + '$')}"
                               for key, value in entry.items())
            lines.append(f"    ({fields}),")
        lines.append("  ],")
    lines.append("};\n")
    return subprocess.run(
        ["dart", "format", "--output=show", "--summary=none", "--stdin-name", str(OUTPUT)],
        input="\n".join(lines), text=True, capture_output=True, check=True,
    ).stdout


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = generate()
    if args.check:
        assert OUTPUT.read_text() == content, "공개 원본이 변경됐어요. 앱 본문을 다시 생성해 주세요."
    else:
        OUTPUT.write_text(content)
    print("공개 문서 링크와 앱 본문 일치 확인 완료" if args.check else "공개 원본으로 앱 본문 생성 완료")
