package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Default directories to always exclude
var defaultExcludeDirs = map[string]bool{
	// Version control
	".git": true,
	".svn": true,
	".hg":  true,

	// Package managers / dependencies
	"node_modules": true,
	"vendor":       true,
	"bower_components": true,

	// Python virtual environments
	"venv":          true,
	".venv":         true,
	"virtualenv":    true,
	".virtualenv":   true,
	"env":           true,
	".env":          true,
	"__pycache__":   true,
	".pytest_cache": true,
	".mypy_cache":   true,
	"site-packages": true,

	// Build outputs
	"dist":    true,
	"build":   true,
	".next":   true,
	"out":     true,
	"target":  true,
	"_build":  true,
	".output": true,

	// IDE / Editor
	".idea":   true,
	".vscode": true,

	// Data / cache directories (common in projects)
	".data":  true,
	".cache": true,
	"cache":  true,

	// Test coverage
	"coverage":  true,
	".coverage": true,
	"htmlcov":   true,
}

// Scanner orchestrates the dependency scanning process
type Scanner struct {
	rootPath    string
	parser      *Parser
	graph       *DependencyGraph
	verbose     bool
	moduleName  string            // Go module name from go.mod
	excludeDirs map[string]bool   // Directories to exclude
}

// NewScanner creates a new scanner instance
func NewScanner(rootPath string, verbose bool, customExcludes []string) (*Scanner, error) {
	// Load detected languages from .claude/.languages
	languages, err := loadDetectedLanguages()
	if err != nil {
		return nil, fmt.Errorf("failed to load languages: %w", err)
	}

	if verbose {
		printf("Loaded languages: %v\n", languages)
	}

	// Create parser with detected languages
	parser, err := NewParser(languages)
	if err != nil {
		return nil, fmt.Errorf("failed to create parser: %w", err)
	}

	// Try to load Go module name if go.mod exists
	moduleName := ""
	goModPath := filepath.Join(rootPath, "go.mod")
	if content, err := os.ReadFile(goModPath); err == nil {
		lines := strings.Split(string(content), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "module ") {
				moduleName = strings.TrimSpace(strings.TrimPrefix(line, "module"))
				if verbose {
					printf("Detected Go module: %s\n", moduleName)
				}
				break
			}
		}
	}

	// Merge default exclusions with custom ones
	excludeDirs := make(map[string]bool)
	for dir := range defaultExcludeDirs {
		excludeDirs[dir] = true
	}
	for _, dir := range customExcludes {
		excludeDirs[dir] = true
	}

	if verbose && len(customExcludes) > 0 {
		printf("Custom exclusions added: %v\n", customExcludes)
	}

	return &Scanner{
		rootPath:    rootPath,
		parser:      parser,
		graph:       NewDependencyGraph(),
		verbose:     verbose,
		moduleName:  moduleName,
		excludeDirs: excludeDirs,
	}, nil
}

// loadDetectedLanguages reads the .claude/.languages file
func loadDetectedLanguages() ([]string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	langFile := filepath.Join(homeDir, ".claude", ".languages")

	// If file doesn't exist, use defaults
	if _, err := os.Stat(langFile); os.IsNotExist(err) {
		return []string{"typescript", "javascript", "go", "python"}, nil
	}

	content, err := os.ReadFile(langFile)
	if err != nil {
		return nil, err
	}

	// Parse languages (one per line)
	lines := strings.Split(string(content), "\n")
	var languages []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "#") {
			languages = append(languages, line)
		}
	}

	if len(languages) == 0 {
		return []string{"typescript", "javascript", "go", "python"}, nil
	}

	return languages, nil
}

// Scan walks the directory tree and builds the dependency graph
func (s *Scanner) Scan() error {
	if s.verbose {
		printf("Scanning directory: %s\n", s.rootPath)
	}

	// Walk directory tree
	err := filepath.Walk(s.rootPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip directories
		if info.IsDir() {
			name := info.Name()
			if s.excludeDirs[name] {
				if s.verbose {
					printf("Skipping excluded directory: %s\n", path)
				}
				return filepath.SkipDir
			}
			return nil
		}

		// Check if file is supported
		if s.isSupportedFile(path) {
			if s.verbose {
				printf("Parsing: %s\n", path)
			}

			node, err := s.parser.Parse(path)
			if err != nil {
				if s.verbose {
					printf("Warning: Failed to parse %s: %v\n", path, err)
				}
				return nil // Continue on parse errors
			}

			s.graph.Files[path] = node
		}

		return nil
	})

	if err != nil {
		return err
	}

	// Build reverse dependencies
	s.buildReverseImports()

	// Detect circular dependencies
	s.graph.Circular = DetectCircularDependencies(s.graph)

	// Detect dead code
	s.graph.DeadCode = DetectDeadCode(s.graph)

	if s.verbose {
		printf("Scan complete: %d files processed\n", len(s.graph.Files))
	}

	return nil
}

// isSupportedFile checks if a file should be parsed
func (s *Scanner) isSupportedFile(path string) bool {
	ext := filepath.Ext(path)
	supportedExts := map[string]bool{
		".ts":   true,
		".tsx":  true,
		".js":   true,
		".jsx":  true,
		".mjs":  true,
		".cjs":  true,
		".go":   true,
		".py":   true,
		".pyi":  true,
	}
	return supportedExts[ext]
}

// buildReverseImports populates the ImportedBy field for each file
func (s *Scanner) buildReverseImports() {
	for filePath, node := range s.graph.Files {
		for i, imp := range node.Imports {
			resolvedPath := s.resolveImport(filePath, imp.Path)
			if resolvedPath == "" {
				continue
			}

			node.Imports[i].Path = resolvedPath

			if importedNode, exists := s.graph.Files[resolvedPath]; exists {
				importedNode.ImportedBy = append(importedNode.ImportedBy, filePath)
			}
		}
	}
}

func (s *Scanner) resolveImport(fromFile, importPath string) string {
	if s.moduleName != "" && strings.HasPrefix(importPath, s.moduleName+"/") {
		relPath := strings.TrimPrefix(importPath, s.moduleName+"/")
		packageDir := filepath.Join(s.rootPath, relPath)

		if files, err := filepath.Glob(filepath.Join(packageDir, "*.go")); err == nil && len(files) > 0 {
			return files[0]
		}

		if _, err := os.Stat(packageDir + ".go"); err == nil {
			return packageDir + ".go"
		}

		return ""
	}

	if !strings.HasPrefix(importPath, ".") && !strings.HasPrefix(importPath, "/") {
		return ""
	}

	fromDir := filepath.Dir(fromFile)
	resolved := filepath.Join(fromDir, importPath)

	// Try different extensions
	extensions := []string{"", ".ts", ".tsx", ".js", ".jsx", ".go", ".py"}
	for _, ext := range extensions {
		testPath := resolved + ext
		if _, err := os.Stat(testPath); err == nil {
			return testPath
		}
	}

	// Try index files
	for _, indexFile := range []string{"index.ts", "index.tsx", "index.js", "index.jsx"} {
		testPath := filepath.Join(resolved, indexFile)
		if _, err := os.Stat(testPath); err == nil {
			return testPath
		}
	}

	return ""
}

// GetGraph returns the built dependency graph
func (s *Scanner) GetGraph() *DependencyGraph {
	return s.graph
}
