#!/usr/bin/env python3
"""
Query Engine - Format and filter memory graph queries for context injection
"""

import os
import sys
import json
import argparse
from typing import List, Dict

# Add lib directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from graph import MemoryGraph
from parser import parse_node


def get_node_summary(node_id: str, graph: MemoryGraph) -> str:
    """Get a one-line summary of a node."""
    node_data = graph.get_node(node_id)
    if not node_data:
        return ""

    file_path = node_data.get("path")
    if not file_path or not os.path.exists(file_path):
        return ""

    node = parse_node(file_path)
    if not node:
        return ""

    # Extract first heading or first non-empty line as summary
    content_lines = node.content.strip().split('\n')
    title = ""
    summary = ""

    for line in content_lines:
        line = line.strip()
        if line.startswith('#'):
            title = line.lstrip('#').strip()
            break
        elif line and not summary:
            summary = line[:80]

    display = title or summary or node_id
    return display


def format_summary(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as brief summaries for context injection."""
    lines = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        node_type = node_data.get("type", "unknown")
        display = get_node_summary(node_id, graph)

        if display:
            lines.append(f"[{node_type}] {display}")

    return '\n'.join(lines)


def format_json(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as JSON."""
    nodes = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if node_data:
            nodes.append({
                "id": node_id,
                **node_data
            })

    return json.dumps({"nodes": nodes, "count": len(nodes)}, indent=2)


def format_full(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes with full content."""
    parts = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        file_path = node_data.get("path")
        if not file_path or not os.path.exists(file_path):
            continue

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            parts.append(f"--- {node_id} ---\n{content}")
        except IOError:
            continue

    return '\n\n'.join(parts)


def format_ids(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format as simple list of IDs."""
    return '\n'.join(node_ids)


def main():
    parser = argparse.ArgumentParser(description="Query memory graph")
    parser.add_argument("--memory-dir", default=".claude/memory",
                        help="Path to memory directory")
    parser.add_argument("--command", required=True,
                        choices=["recent", "type", "tag", "related", "search", "id"],
                        help="Query command")
    parser.add_argument("--query", default="",
                        help="Query argument (type name, tag, node id, or search term)")
    parser.add_argument("--format", default="summary",
                        choices=["summary", "json", "full", "ids"],
                        help="Output format")
    parser.add_argument("--limit", type=int, default=5,
                        help="Maximum number of results")
    parser.add_argument("--status", default="active",
                        choices=["active", "archived", "all"],
                        help="Filter by status")

    args = parser.parse_args()

    # Override memory dir from environment if set
    memory_dir = os.environ.get("CLAUDE_MEMORY_DIR", args.memory_dir)
    graph = MemoryGraph(memory_dir)

    # Get node IDs based on command
    node_ids: List[str] = []

    if args.command == "recent":
        node_ids = graph.get_recent(args.limit)

    elif args.command == "type":
        node_ids = graph.get_by_type(args.query)[:args.limit]

    elif args.command == "tag":
        node_ids = graph.get_by_tag(args.query)[:args.limit]

    elif args.command == "related":
        node_ids = graph.get_related(args.query, args.limit)

    elif args.command == "search":
        node_ids = graph.search(args.query, args.limit)

    elif args.command == "id":
        if graph.get_node(args.query):
            node_ids = [args.query]

    # Filter by status
    if args.status != "all":
        filtered = []
        for nid in node_ids:
            node_data = graph.get_node(nid)
            if node_data and node_data.get("status") == args.status:
                filtered.append(nid)
        node_ids = filtered

    # Format output
    if args.format == "summary":
        output = format_summary(node_ids, graph)
    elif args.format == "json":
        output = format_json(node_ids, graph)
    elif args.format == "full":
        output = format_full(node_ids, graph)
    elif args.format == "ids":
        output = format_ids(node_ids, graph)
    else:
        output = ""

    if output:
        print(output)


if __name__ == "__main__":
    main()
