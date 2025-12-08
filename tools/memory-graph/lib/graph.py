#!/usr/bin/env python3
"""
Graph Cache Builder - Build and query the memory graph
"""

import os
import sys
import json
from typing import Dict, List, Optional, Set
from datetime import datetime, timezone
from pathlib import Path

# Add lib directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parser import parse_node, Node


class MemoryGraph:
    """Memory graph cache manager"""

    def __init__(self, memory_dir: str = ".claude/memory"):
        self.memory_dir = memory_dir
        self.nodes_dir = os.path.join(memory_dir, "nodes")
        self.cache_path = os.path.join(memory_dir, "graph.json")
        self.cache: Dict = {}
        self.load_cache()

    def load_cache(self) -> None:
        """Load existing cache from disk."""
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, 'r', encoding='utf-8') as f:
                    self.cache = json.load(f)
            except (json.JSONDecodeError, IOError):
                self._init_empty_cache()
        else:
            self._init_empty_cache()

    def _init_empty_cache(self) -> None:
        """Initialize empty cache structure."""
        self.cache = {
            "version": "1.0.0",
            "updated_at": "",
            "node_count": 0,
            "nodes": {},
            "tags": {},
            "types": {},
            "recent": []
        }

    def save_cache(self) -> None:
        """Save cache to disk."""
        self.cache["updated_at"] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

        # Ensure directory exists
        os.makedirs(os.path.dirname(self.cache_path), exist_ok=True)

        with open(self.cache_path, 'w', encoding='utf-8') as f:
            json.dump(self.cache, f, indent=2)

    def rebuild(self) -> int:
        """Rebuild entire cache by scanning all nodes. Returns node count."""
        nodes = {}
        tags: Dict[str, List[str]] = {}
        types: Dict[str, List[str]] = {}

        if not os.path.exists(self.nodes_dir):
            self._init_empty_cache()
            self.save_cache()
            return 0

        # Scan all node files
        for root, dirs, files in os.walk(self.nodes_dir):
            for file in files:
                if not file.endswith('.md'):
                    continue

                file_path = os.path.join(root, file)
                node = parse_node(file_path)

                if not node:
                    continue

                node_id = node.metadata.id

                try:
                    mtime = os.path.getmtime(file_path)
                except OSError:
                    mtime = 0

                # Add to nodes
                nodes[node_id] = {
                    "path": file_path,
                    "type": node.metadata.type,
                    "tags": node.metadata.tags,
                    "links_to": node.links,
                    "backlinks": [],  # Computed below
                    "created": node.metadata.created,
                    "updated": node.metadata.updated,
                    "status": node.metadata.status,
                    "mtime": mtime
                }

                # Add to tags index
                for tag in node.metadata.tags:
                    if tag not in tags:
                        tags[tag] = []
                    if node_id not in tags[tag]:
                        tags[tag].append(node_id)

                # Add to types index
                node_type = node.metadata.type
                if node_type not in types:
                    types[node_type] = []
                if node_id not in types[node_type]:
                    types[node_type].append(node_id)

        # Compute backlinks
        for node_id, node_data in nodes.items():
            for link_target in node_data["links_to"]:
                if link_target in nodes:
                    if node_id not in nodes[link_target]["backlinks"]:
                        nodes[link_target]["backlinks"].append(node_id)

        # Compute recent (sorted by updated time, descending)
        def get_updated(nid: str) -> str:
            return nodes[nid].get("updated", "") or ""

        recent = sorted(nodes.keys(), key=get_updated, reverse=True)[:20]

        # Update cache
        self.cache["nodes"] = nodes
        self.cache["tags"] = tags
        self.cache["types"] = types
        self.cache["recent"] = recent
        self.cache["node_count"] = len(nodes)

        self.save_cache()
        return len(nodes)

    def update_single_node(self, file_path: str) -> bool:
        """
        Update cache for a single node file (incremental update).
        Much faster than full rebuild for single node changes.

        Returns True if node was added/updated, False if invalid.
        """
        node = parse_node(file_path)
        if not node:
            return False

        node_id = node.metadata.id
        nodes = self.cache.get("nodes", {})
        tags = self.cache.get("tags", {})
        types = self.cache.get("types", {})

        try:
            mtime = os.path.getmtime(file_path)
        except OSError:
            mtime = 0

        # Check if this is a new node or update
        is_new = node_id not in nodes

        # Update node data
        nodes[node_id] = {
            "path": file_path,
            "type": node.metadata.type,
            "tags": node.metadata.tags,
            "links_to": node.links,
            "backlinks": nodes.get(node_id, {}).get("backlinks", []),
            "created": node.metadata.created,
            "updated": node.metadata.updated,
            "status": node.metadata.status,
            "mtime": mtime
        }

        # Update tags index
        for tag in node.metadata.tags:
            if tag not in tags:
                tags[tag] = []
            if node_id not in tags[tag]:
                tags[tag].append(node_id)

        # Update types index
        node_type = node.metadata.type
        if node_type not in types:
            types[node_type] = []
        if node_id not in types[node_type]:
            types[node_type].append(node_id)

        # Recompute backlinks for this node's targets
        for link_target in node.links:
            if link_target in nodes:
                if node_id not in nodes[link_target]["backlinks"]:
                    nodes[link_target]["backlinks"].append(node_id)

        # Update recent list
        recent = self.cache.get("recent", [])
        if node_id in recent:
            recent.remove(node_id)
        recent.insert(0, node_id)
        self.cache["recent"] = recent[:20]

        # Update counts
        self.cache["nodes"] = nodes
        self.cache["tags"] = tags
        self.cache["types"] = types
        self.cache["node_count"] = len(nodes)

        self.save_cache()
        return True

    def get_node(self, node_id: str) -> Optional[Dict]:
        """Get node metadata from cache."""
        return self.cache.get("nodes", {}).get(node_id)

    def get_by_type(self, node_type: str) -> List[str]:
        """Get all node IDs of a specific type."""
        return self.cache.get("types", {}).get(node_type, [])

    def get_by_tag(self, tag: str) -> List[str]:
        """Get all node IDs with a specific tag."""
        return self.cache.get("tags", {}).get(tag, [])

    def get_recent(self, limit: int = 5) -> List[str]:
        """Get most recently updated node IDs."""
        return self.cache.get("recent", [])[:limit]

    def get_related(self, node_id: str, limit: int = 5) -> List[str]:
        """Get related nodes (links + backlinks + tag overlap)."""
        node = self.get_node(node_id)
        if not node:
            return []

        related: Set[str] = set()

        # Add direct links
        related.update(node.get("links_to", []))
        related.update(node.get("backlinks", []))

        # Add nodes with overlapping tags
        node_tags = set(node.get("tags", []))
        for tag in node_tags:
            for related_id in self.get_by_tag(tag):
                if related_id != node_id:
                    related.add(related_id)

        # Remove self
        related.discard(node_id)

        # Sort by connection strength (more shared tags/links = higher)
        def connection_strength(nid: str) -> int:
            other = self.get_node(nid)
            if not other:
                return 0
            score = 0
            # Direct link = 3 points each
            if nid in node.get("links_to", []):
                score += 3
            if nid in node.get("backlinks", []):
                score += 3
            # Shared tags = 1 point each
            other_tags = set(other.get("tags", []))
            score += len(node_tags & other_tags)
            return score

        sorted_related = sorted(related, key=connection_strength, reverse=True)
        return sorted_related[:limit]

    def search(self, query: str, limit: int = 10) -> List[str]:
        """Full-text search in node content."""
        results = []
        query_lower = query.lower()

        for node_id, node_data in self.cache.get("nodes", {}).items():
            file_path = node_data.get("path")
            if not file_path or not os.path.exists(file_path):
                continue

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read().lower()

                if query_lower in content:
                    results.append(node_id)

                if len(results) >= limit:
                    break
            except IOError:
                continue

        return results

    def get_stats(self) -> Dict:
        """Get graph statistics."""
        return {
            "node_count": self.cache.get("node_count", 0),
            "tag_count": len(self.cache.get("tags", {})),
            "type_count": len(self.cache.get("types", {})),
            "updated_at": self.cache.get("updated_at", "never")
        }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: graph.py <command> [args]")
        print("")
        print("Commands:")
        print("  rebuild              Rebuild the graph cache")
        print("  update <file>        Update cache for a single node file")
        print("  stats                Show graph statistics")
        print("  recent [N]           Get N most recent nodes (default: 5)")
        print("  type <type>          Get nodes by type")
        print("  tag <tag>            Get nodes by tag")
        print("  related <id> [N]     Get N related nodes (default: 5)")
        print("  search <query> [N]   Search nodes (default: 10)")
        print("  node <id>            Get node metadata")
        sys.exit(1)

    # Get memory dir from environment or default
    memory_dir = os.environ.get("CLAUDE_MEMORY_DIR", ".claude/memory")
    graph = MemoryGraph(memory_dir)

    command = sys.argv[1]

    if command == "rebuild":
        count = graph.rebuild()
        print(f"Rebuilt graph with {count} nodes")

    elif command == "update":
        if len(sys.argv) < 3:
            print("Usage: graph.py update <node_file>", file=sys.stderr)
            sys.exit(1)
        node_file = sys.argv[2]
        success = graph.update_single_node(node_file)
        if success:
            print(f"Updated cache for: {node_file}")
        else:
            print(f"Failed to update: {node_file}", file=sys.stderr)
            sys.exit(1)

    elif command == "stats":
        stats = graph.get_stats()
        print(json.dumps(stats, indent=2))

    elif command == "recent":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        print(json.dumps(graph.get_recent(limit), indent=2))

    elif command == "type":
        if len(sys.argv) < 3:
            print("Usage: graph.py type <type>", file=sys.stderr)
            sys.exit(1)
        node_type = sys.argv[2]
        print(json.dumps(graph.get_by_type(node_type), indent=2))

    elif command == "tag":
        if len(sys.argv) < 3:
            print("Usage: graph.py tag <tag>", file=sys.stderr)
            sys.exit(1)
        tag = sys.argv[2]
        print(json.dumps(graph.get_by_tag(tag), indent=2))

    elif command == "related":
        if len(sys.argv) < 3:
            print("Usage: graph.py related <id> [limit]", file=sys.stderr)
            sys.exit(1)
        node_id = sys.argv[2]
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 5
        print(json.dumps(graph.get_related(node_id, limit), indent=2))

    elif command == "search":
        if len(sys.argv) < 3:
            print("Usage: graph.py search <query> [limit]", file=sys.stderr)
            sys.exit(1)
        query = sys.argv[2]
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 10
        print(json.dumps(graph.search(query, limit), indent=2))

    elif command == "node":
        if len(sys.argv) < 3:
            print("Usage: graph.py node <id>", file=sys.stderr)
            sys.exit(1)
        node_id = sys.argv[2]
        node = graph.get_node(node_id)
        if node:
            print(json.dumps(node, indent=2))
        else:
            print(f"Node not found: {node_id}", file=sys.stderr)
            sys.exit(1)

    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)
