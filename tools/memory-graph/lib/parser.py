#!/usr/bin/env python3
"""
Node Parser - Parse markdown nodes with YAML frontmatter and wiki-links
"""

import os
import re
import sys
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict, field
from datetime import datetime

try:
    import yaml
except ImportError:
    # Fallback to basic YAML parsing if PyYAML not installed
    yaml = None


@dataclass
class NodeMetadata:
    """Metadata from node frontmatter"""
    id: str
    type: str
    created: str
    updated: str
    path: str  # File path to the node
    tags: List[str] = field(default_factory=list)
    related: List[str] = field(default_factory=list)
    status: str = "active"
    supersedes: Optional[str] = None
    file_path: Optional[str] = None  # For file-summary nodes (the file being summarized)
    session_id: Optional[str] = None


@dataclass
class Node:
    """A memory node with metadata and content"""
    metadata: NodeMetadata
    content: str
    links: List[str]  # Extracted [[wiki-links]]

    def to_dict(self) -> Dict:
        return {
            "metadata": asdict(self.metadata),
            "content": self.content,
            "links": self.links
        }


def parse_frontmatter_basic(text: str) -> tuple[Dict, str]:
    """Basic YAML frontmatter parser (no PyYAML dependency)."""
    pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
    match = re.match(pattern, text, re.DOTALL)

    if not match:
        return {}, text

    yaml_text = match.group(1)
    content = match.group(2)

    # Basic parsing
    frontmatter = {}
    current_key = None
    current_list = None

    for line in yaml_text.split('\n'):
        line = line.rstrip()
        if not line or line.startswith('#'):
            continue

        # Check for key: value
        if ':' in line and not line.startswith(' ') and not line.startswith('-'):
            key, _, value = line.partition(':')
            key = key.strip()
            value = value.strip()

            # Handle inline list [a, b, c]
            if value.startswith('[') and value.endswith(']'):
                items = value[1:-1].split(',')
                frontmatter[key] = [item.strip().strip('"\'') for item in items if item.strip()]
            elif value:
                # Remove quotes
                if (value.startswith('"') and value.endswith('"')) or \
                   (value.startswith("'") and value.endswith("'")):
                    value = value[1:-1]
                frontmatter[key] = value
            else:
                # Might be a list following
                frontmatter[key] = []
                current_key = key
                current_list = frontmatter[key]

        # Handle list item
        elif line.strip().startswith('- ') and current_key:
            item = line.strip()[2:].strip().strip('"\'')
            # Handle [[link]] format
            if item.startswith('[[') and item.endswith(']]'):
                item = item[2:-2]
            current_list.append(item)

    return frontmatter, content


def parse_frontmatter(text: str) -> tuple[Dict, str]:
    """Extract YAML frontmatter and remaining content."""
    if yaml:
        pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
        match = re.match(pattern, text, re.DOTALL)

        if not match:
            return {}, text

        try:
            frontmatter = yaml.safe_load(match.group(1)) or {}
            content = match.group(2)
            return frontmatter, content
        except yaml.YAMLError:
            return {}, text
    else:
        return parse_frontmatter_basic(text)


def extract_wiki_links(content: str) -> List[str]:
    """Extract all [[wiki-links]] from content."""
    # Match [[link]] or [[link|display text]]
    pattern = r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]'
    matches = re.findall(pattern, content)
    return list(set(matches))  # Dedupe


def extract_tags(content: str) -> List[str]:
    """Extract all #tags from content (not in code blocks)."""
    # Simple approach: find #word patterns not preceded by non-whitespace
    pattern = r'(?<!\S)#([a-zA-Z][a-zA-Z0-9_-]*)'
    matches = re.findall(pattern, content)
    return list(set(matches))


def parse_node(file_path: str) -> Optional[Node]:
    """Parse a markdown node file into a Node object."""
    if not os.path.exists(file_path):
        return None

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            text = f.read()
    except Exception:
        return None

    frontmatter, content = parse_frontmatter(text)

    # Require id and type
    if not frontmatter.get('id') or not frontmatter.get('type'):
        return None

    # Extract links from content
    links = extract_wiki_links(content)

    # Add links from frontmatter 'related' field
    related = frontmatter.get('related', [])
    if isinstance(related, list):
        for r in related:
            if isinstance(r, str):
                # Handle [[node-id]] format
                link_match = re.match(r'\[\[([^\]]+)\]\]', r)
                if link_match:
                    links.append(link_match.group(1))
                elif not r.startswith('[['):
                    links.append(r)

    links = list(set(links))  # Dedupe

    # Merge tags from frontmatter and content
    fm_tags = frontmatter.get('tags', [])
    if isinstance(fm_tags, str):
        fm_tags = [fm_tags]
    content_tags = extract_tags(content)
    all_tags = list(set(fm_tags + content_tags))

    # Ensure string values for dates (handle datetime objects from PyYAML)
    created = frontmatter.get('created', '')
    updated = frontmatter.get('updated', '')
    if hasattr(created, 'isoformat'):
        created = created.isoformat()
    if hasattr(updated, 'isoformat'):
        updated = updated.isoformat()

    metadata = NodeMetadata(
        id=str(frontmatter['id']),
        type=str(frontmatter['type']),
        created=str(created) if created else '',
        updated=str(updated) if updated else '',
        path=file_path,
        tags=all_tags,
        related=frontmatter.get('related', []),
        status=str(frontmatter.get('status', 'active')),
        supersedes=frontmatter.get('supersedes'),
        file_path=frontmatter.get('file_path') or frontmatter.get('path'),
        session_id=frontmatter.get('session_id')
    )

    return Node(metadata=metadata, content=content, links=links)


def create_node(
    node_id: str,
    node_type: str,
    title: str,
    content: str,
    tags: List[str] = None,
    related: List[str] = None,
    extra_frontmatter: Dict = None
) -> str:
    """Create a markdown node with frontmatter."""
    now = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

    # Build frontmatter manually to avoid PyYAML dependency
    lines = [
        '---',
        f'id: {node_id}',
        f'type: {node_type}',
        f'created: {now}',
        f'updated: {now}',
        'status: active',
    ]

    if tags:
        lines.append(f'tags: [{", ".join(tags)}]')
    else:
        lines.append('tags: []')

    if related:
        related_str = ', '.join(f'[[{r}]]' for r in related)
        lines.append(f'related: [{related_str}]')
    else:
        lines.append('related: []')

    if extra_frontmatter:
        for key, value in extra_frontmatter.items():
            if isinstance(value, list):
                lines.append(f'{key}: [{", ".join(str(v) for v in value)}]')
            else:
                lines.append(f'{key}: {value}')

    lines.append('---')
    lines.append('')
    lines.append(f'# {title}')
    lines.append('')
    lines.append(content)

    return '\n'.join(lines)


if __name__ == "__main__":
    import json

    if len(sys.argv) < 2:
        print("Usage: parser.py <node_file.md>")
        print("       parser.py --create <id> <type> <title>")
        sys.exit(1)

    if sys.argv[1] == "--create":
        if len(sys.argv) < 5:
            print("Usage: parser.py --create <id> <type> <title>")
            sys.exit(1)
        node_id = sys.argv[2]
        node_type = sys.argv[3]
        title = sys.argv[4]
        print(create_node(node_id, node_type, title, ""))
    else:
        node = parse_node(sys.argv[1])
        if node:
            print(json.dumps(node.to_dict(), indent=2))
        else:
            print("Failed to parse node", file=sys.stderr)
            sys.exit(1)
