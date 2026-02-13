package parser

import (
	"fmt"
	"path/filepath"
	"strings"

	sitter "github.com/smacker/go-tree-sitter"
	"github.com/smacker/go-tree-sitter/golang"
	"github.com/smacker/go-tree-sitter/javascript"
	"github.com/smacker/go-tree-sitter/python"
	"github.com/smacker/go-tree-sitter/typescript/typescript"
)

type Parser struct {
	parser   *sitter.Parser
	language *sitter.Language
	langName string
}

func NewParser(filePath string) (*Parser, error) {
	lang := DetectLanguage(filePath)

	// Non-AST languages: return nil parser, chunker handles them directly
	if lang == "markdown" || lang == "text" {
		return &Parser{
			parser:   nil,
			language: nil,
			langName: lang,
		}, nil
	}

	var tsLang *sitter.Language
	switch lang {
	case "typescript":
		tsLang = typescript.GetLanguage()
	case "javascript":
		tsLang = javascript.GetLanguage()
	case "python":
		tsLang = python.GetLanguage()
	case "go":
		tsLang = golang.GetLanguage()
	default:
		return nil, fmt.Errorf("unsupported language: %s", lang)
	}

	p := sitter.NewParser()
	p.SetLanguage(tsLang)

	return &Parser{
		parser:   p,
		language: tsLang,
		langName: lang,
	}, nil
}

func (p *Parser) Parse(sourceCode []byte) (*sitter.Tree, error) {
	tree := p.parser.Parse(nil, sourceCode)
	if tree == nil {
		return nil, fmt.Errorf("failed to parse source code")
	}
	return tree, nil
}

func (p *Parser) GetLanguage() string {
	return p.langName
}

func DetectLanguage(filePath string) string {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".ts", ".tsx":
		return "typescript"
	case ".js", ".jsx":
		return "javascript"
	case ".py":
		return "python"
	case ".go":
		return "go"
	case ".md", ".markdown", ".mdx":
		return "markdown"
	default:
		return "text"
	}
}
