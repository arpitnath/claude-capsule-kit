#!/usr/bin/env python3
"""
File Summary Generator - Create summaries for large files
Uses heuristics (not LLM) for automatic summarization.
"""

import os
import re
import sys
from typing import Dict, List
from pathlib import Path


def extract_exports_ts(content: str) -> List[str]:
    """Extract exported functions/classes from TypeScript/JavaScript."""
    exports = []

    # export function name
    for match in re.finditer(r'export\s+(?:async\s+)?function\s+(\w+)', content):
        exports.append(f"function {match.group(1)}")

    # export class name
    for match in re.finditer(r'export\s+class\s+(\w+)', content):
        exports.append(f"class {match.group(1)}")

    # export const name
    for match in re.finditer(r'export\s+const\s+(\w+)', content):
        exports.append(f"const {match.group(1)}")

    # export default
    for match in re.finditer(r'export\s+default\s+(?:class|function)?\s*(\w+)?', content):
        name = match.group(1) or "default"
        exports.append(f"default {name}")

    return exports[:10]  # Limit to 10


def extract_imports_ts(content: str) -> List[str]:
    """Extract import sources from TypeScript/JavaScript."""
    imports = []

    for match in re.finditer(r"from\s+['\"]([^'\"]+)['\"]", content):
        imports.append(match.group(1))

    return list(set(imports))[:10]


def extract_functions_py(content: str) -> List[str]:
    """Extract function/class definitions from Python."""
    defs = []

    for match in re.finditer(r'^(?:async\s+)?def\s+(\w+)', content, re.MULTILINE):
        defs.append(f"def {match.group(1)}")

    for match in re.finditer(r'^class\s+(\w+)', content, re.MULTILINE):
        defs.append(f"class {match.group(1)}")

    return defs[:10]


def extract_functions_go(content: str) -> List[str]:
    """Extract function definitions from Go."""
    defs = []

    for match in re.finditer(r'^func\s+(?:\([^)]+\)\s+)?(\w+)', content, re.MULTILINE):
        defs.append(f"func {match.group(1)}")

    for match in re.finditer(r'^type\s+(\w+)\s+struct', content, re.MULTILINE):
        defs.append(f"type {match.group(1)}")

    return defs[:10]


def detect_language(file_path: str) -> str:
    """Detect programming language from file extension."""
    ext = Path(file_path).suffix.lower()
    lang_map = {
        '.ts': 'typescript',
        '.tsx': 'typescript',
        '.js': 'javascript',
        '.jsx': 'javascript',
        '.py': 'python',
        '.go': 'go',
        '.rs': 'rust',
        '.java': 'java',
        '.md': 'markdown',
        '.sh': 'bash',
        '.rb': 'ruby',
    }
    return lang_map.get(ext, 'unknown')


def generate_summary(file_path: str, content: str) -> Dict:
    """Generate a summary for a file."""
    language = detect_language(file_path)
    lines = content.split('\n')
    line_count = len(lines)
    size_kb = len(content) / 1024

    summary = {
        "path": file_path,
        "language": language,
        "line_count": line_count,
        "size_kb": round(size_kb, 1),
        "exports": [],
        "imports": [],
        "description": ""
    }

    # Extract based on language
    if language in ['typescript', 'javascript']:
        summary["exports"] = extract_exports_ts(content)
        summary["imports"] = extract_imports_ts(content)
    elif language == 'python':
        summary["exports"] = extract_functions_py(content)
    elif language == 'go':
        summary["exports"] = extract_functions_go(content)

    # Try to extract description from top comments
    desc_lines = []
    for line in lines[:20]:
        line = line.strip()
        if line.startswith('//') or line.startswith('#') or line.startswith('*'):
            clean = re.sub(r'^[/#*\s]+', '', line)
            if clean and not clean.startswith('@'):
                desc_lines.append(clean)
        elif line.startswith('"""') or line.startswith("'''"):
            # Python docstring
            continue

    if desc_lines:
        summary["description"] = ' '.join(desc_lines[:3])[:200]

    return summary


def format_as_markdown(summary: Dict) -> str:
    """Format summary as markdown content for a node."""
    lines = [f"# {summary['path']}", ""]

    if summary["description"]:
        lines.append(f"{summary['description']}")
        lines.append("")

    lines.append("## Overview")
    lines.append(f"- **Language**: {summary['language']}")
    lines.append(f"- **Lines**: {summary['line_count']}")
    lines.append(f"- **Size**: {summary['size_kb']} KB")
    lines.append("")

    if summary["exports"]:
        lines.append("## Exports")
        for exp in summary["exports"]:
            lines.append(f"- `{exp}`")
        lines.append("")

    if summary["imports"]:
        lines.append("## Dependencies")
        for imp in summary["imports"]:
            lines.append(f"- `{imp}`")
        lines.append("")

    return '\n'.join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: summarize.py <file_path> [--json]")
        sys.exit(1)

    file_path = sys.argv[1]

    if not os.path.exists(file_path):
        print(f"File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    summary = generate_summary(file_path, content)

    if "--json" in sys.argv:
        import json
        print(json.dumps(summary, indent=2))
    else:
        print(format_as_markdown(summary))
