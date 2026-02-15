/**
 * Task Decomposer - Analyze dependency graph to find independent file clusters
 * and generate crew config for parallel work.
 */

import { execSync } from 'child_process';
import { existsSync, readdirSync, statSync } from 'fs';
import { join, dirname, basename, relative } from 'path';
import { ROLE_PRESETS } from './role-presets.js';

const CCK_HOME = process.env.HOME ? join(process.env.HOME, '.claude', 'cck') : null;
const QUERY_DEPS_SCRIPT = CCK_HOME ? join(CCK_HOME, 'tools', 'query-deps', 'query-deps.sh') : null;

/**
 * Get dependency information for a file using query-deps.sh
 * @param {string} filePath - Path to file
 * @param {string} graphFile - Path to TOON graph file
 * @returns {{ imports: string[], importers: string[] }} Dependency info
 */
function getFileDependencies(filePath, graphFile) {
  if (!QUERY_DEPS_SCRIPT || !existsSync(QUERY_DEPS_SCRIPT)) {
    throw new Error('query-deps.sh not found. Run "cck setup" first.');
  }

  try {
    const output = execSync(`bash "${QUERY_DEPS_SCRIPT}" "${filePath}" "${graphFile}"`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe']
    });

    const imports = [];
    const importers = [];
    let section = null;

    for (const line of output.split('\n')) {
      if (line.startsWith('Imports:')) {
        section = 'imports';
      } else if (line.startsWith('Imported by:')) {
        section = 'importers';
      } else if (line.startsWith('Total importers:')) {
        section = null;
      } else if (section && line.trim().startsWith('- ')) {
        const file = line.trim().slice(2);
        if (section === 'imports') {
          imports.push(file);
        } else if (section === 'importers') {
          importers.push(file);
        }
      }
    }

    return { imports, importers };
  } catch (err) {
    // File not in graph or other error
    return { imports: [], importers: [] };
  }
}

/**
 * Get all files from the dependency graph
 * @param {string} graphFile - Path to TOON graph file
 * @returns {string[]} List of file paths in the graph
 */
function getAllFilesFromGraph(graphFile) {
  if (!existsSync(graphFile)) {
    throw new Error(`Graph file not found: ${graphFile}. Run dependency scanner first.`);
  }

  try {
    const output = execSync(`grep "^FILE{" "${graphFile}" | cut -d'{' -f2 | cut -d':' -f1`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe']
    });

    return output.trim().split('\n').filter(f => f);
  } catch (err) {
    return [];
  }
}

/**
 * Build dependency graph from file list
 * @param {string[]} files - List of file paths
 * @param {string} graphFile - Path to TOON graph file
 * @returns {Map<string, Set<string>>} Adjacency list (file -> dependencies)
 */
function buildDependencyGraph(files, graphFile) {
  const graph = new Map();

  for (const file of files) {
    if (!graph.has(file)) {
      graph.set(file, new Set());
    }

    const { imports, importers } = getFileDependencies(file, graphFile);

    // Add edges: file -> imports and file -> importers (undirected for clustering)
    for (const imp of imports) {
      if (files.includes(imp)) {
        graph.get(file).add(imp);
        if (!graph.has(imp)) graph.set(imp, new Set());
        graph.get(imp).add(file);
      }
    }

    for (const importer of importers) {
      if (files.includes(importer)) {
        graph.get(file).add(importer);
        if (!graph.has(importer)) graph.set(importer, new Set());
        graph.get(importer).add(file);
      }
    }
  }

  return graph;
}

/**
 * Find connected components using DFS
 * @param {Map<string, Set<string>>} graph - Dependency graph
 * @returns {string[][]} Array of clusters (each cluster is an array of files)
 */
function findConnectedComponents(graph) {
  const visited = new Set();
  const clusters = [];

  function dfs(node, cluster) {
    if (visited.has(node)) return;
    visited.add(node);
    cluster.push(node);

    const neighbors = graph.get(node) || new Set();
    for (const neighbor of neighbors) {
      dfs(neighbor, cluster);
    }
  }

  for (const node of graph.keys()) {
    if (!visited.has(node)) {
      const cluster = [];
      dfs(node, cluster);
      clusters.push(cluster);
    }
  }

  // Sort clusters by size (largest first)
  clusters.sort((a, b) => b.length - a.length);
  return clusters;
}

/**
 * Generate a descriptive name for a file cluster
 * @param {string[]} files - Files in the cluster
 * @param {string} projectRoot - Project root for relative path calculation
 * @returns {string} Cluster name
 */
function generateClusterName(files, projectRoot) {
  if (files.length === 0) return 'empty';
  if (files.length === 1) return basename(files[0], '.js').replace(/[^a-z0-9]/gi, '-');

  // Find common directory prefix
  const relativePaths = files.map(f => relative(projectRoot, f));
  const dirs = relativePaths.map(p => dirname(p));
  const commonDir = findCommonPrefix(dirs);

  if (commonDir && commonDir !== '.') {
    return basename(commonDir).replace(/[^a-z0-9]/gi, '-').toLowerCase();
  }

  // Try to find common file prefix
  const names = relativePaths.map(p => basename(p, '.js'));
  const commonName = findCommonPrefix(names);

  if (commonName && commonName.length > 2) {
    return commonName.replace(/[^a-z0-9]/gi, '-').toLowerCase();
  }

  // Fallback: use first file's directory or name
  const firstDir = dirname(relativePaths[0]);
  if (firstDir && firstDir !== '.') {
    return basename(firstDir).replace(/[^a-z0-9]/gi, '-').toLowerCase();
  }

  return basename(files[0], '.js').replace(/[^a-z0-9]/gi, '-').toLowerCase();
}

/**
 * Find common prefix of strings
 * @param {string[]} strings - Array of strings
 * @returns {string} Common prefix
 */
function findCommonPrefix(strings) {
  if (strings.length === 0) return '';
  if (strings.length === 1) return strings[0];

  let prefix = strings[0];
  for (let i = 1; i < strings.length; i++) {
    while (strings[i].indexOf(prefix) !== 0) {
      prefix = prefix.slice(0, -1);
      if (prefix === '') return '';
    }
  }

  return prefix;
}

/**
 * Generate a focus description for a cluster
 * @param {string} clusterName - Cluster name
 * @param {string[]} files - Files in the cluster
 * @param {string} projectRoot - Project root
 * @returns {string} Focus description
 */
function generateClusterFocus(clusterName, files, projectRoot) {
  const relativePaths = files.map(f => relative(projectRoot, f));
  const fileList = relativePaths.slice(0, 5).join(', ');
  const more = files.length > 5 ? ` and ${files.length - 5} more` : '';

  return `Work on ${clusterName} module (${fileList}${more})`;
}

/**
 * Merge small clusters to limit team size
 * @param {object[]} clusters - Array of cluster objects
 * @param {number} maxTeammates - Maximum number of teammates
 * @returns {object[]} Merged clusters
 */
function mergeClusters(clusters, maxTeammates) {
  if (clusters.length <= maxTeammates) {
    return clusters;
  }

  // Keep the largest (maxTeammates - 1) clusters
  const keep = clusters.slice(0, maxTeammates - 1);
  const merge = clusters.slice(maxTeammates - 1);

  // Merge all remaining into a "mixed" cluster
  const mergedFiles = merge.flatMap(c => c.files);
  const mixed = {
    name: 'mixed',
    files: mergedFiles,
    suggestedBranch: 'feat/mixed-work',
    suggestedFocus: `Mixed work across ${merge.length} modules (${mergedFiles.length} files)`
  };

  return [...keep, mixed];
}

/**
 * Decompose project into independent file clusters
 * @param {string} projectRoot - Project root directory
 * @param {string[]} entryPaths - Entry files/directories to analyze (optional)
 * @param {object} options - Options
 * @param {string} options.graphFile - Path to TOON graph file (default: ~/.claude/dep-graph.toon)
 * @param {number} options.maxTeammates - Maximum number of teammates (merge small clusters if exceeded)
 * @returns {{ clusters: object[], metadata: object }} Decomposition result
 */
export function decompose(projectRoot, entryPaths = [], options = {}) {
  const graphFile = options.graphFile || join(process.env.HOME, '.claude', 'dep-graph.toon');

  // Get all files from graph or filter by entry paths
  let files = getAllFilesFromGraph(graphFile);

  if (entryPaths && entryPaths.length > 0) {
    // Filter to only files under entry paths
    const entrySet = new Set();
    for (const entry of entryPaths) {
      const absEntry = join(projectRoot, entry);
      if (existsSync(absEntry)) {
        if (statSync(absEntry).isDirectory()) {
          // Include all files in graph that are under this directory
          files.forEach(f => {
            if (f.startsWith(absEntry)) {
              entrySet.add(f);
            }
          });
        } else {
          // Single file
          entrySet.add(absEntry);
        }
      }
    }
    files = Array.from(entrySet);
  }

  if (files.length === 0) {
    throw new Error('No files found in dependency graph. Run dependency scanner first.');
  }

  // Build dependency graph
  const graph = buildDependencyGraph(files, graphFile);

  // Find connected components
  const components = findConnectedComponents(graph);

  // Generate cluster objects
  let clusters = components.map(files => {
    const name = generateClusterName(files, projectRoot);
    const suggestedBranch = `feat/${name}`;
    const suggestedFocus = generateClusterFocus(name, files, projectRoot);

    return {
      name,
      files,
      suggestedBranch,
      suggestedFocus
    };
  });

  // Merge if too many clusters
  if (options.maxTeammates && clusters.length > options.maxTeammates) {
    clusters = mergeClusters(clusters, options.maxTeammates);
  }

  return {
    clusters,
    metadata: {
      totalFiles: files.length,
      totalClusters: clusters.length,
      graphFile
    }
  };
}

/**
 * Generate crew config from clusters
 * @param {object[]} clusters - Clusters from decompose()
 * @param {object} options - Options
 * @param {string} options.teamName - Team name (default: "decomposed-team")
 * @param {string} options.mainBranch - Main branch name (default: auto-detect)
 * @param {string} options.defaultRole - Default role for teammates (default: "developer")
 * @returns {object} Crew config object
 */
export function generateCrewConfig(clusters, options = {}) {
  const teamName = options.teamName || 'decomposed-team';
  const defaultRole = options.defaultRole || 'developer';

  // Auto-detect main branch
  let mainBranch = options.mainBranch || 'main';
  if (!options.mainBranch) {
    try {
      mainBranch = execSync('git symbolic-ref refs/remotes/origin/HEAD', {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      }).trim().replace('refs/remotes/origin/', '');
    } catch {
      try {
        execSync('git rev-parse --verify main', { stdio: 'pipe' });
        mainBranch = 'main';
      } catch {
        try {
          execSync('git rev-parse --verify master', { stdio: 'pipe' });
          mainBranch = 'master';
        } catch {
          mainBranch = 'main';
        }
      }
    }
  }

  const teammates = clusters.map(cluster => ({
    name: cluster.name,
    branch: cluster.suggestedBranch,
    worktree: true,
    role: defaultRole,
    focus: cluster.suggestedFocus
  }));

  return {
    team: {
      name: teamName,
      lead: {
        model: 'sonnet'
      },
      teammates
    },
    project: {
      main_branch: mainBranch
    },
    stale_after_hours: 4
  };
}
