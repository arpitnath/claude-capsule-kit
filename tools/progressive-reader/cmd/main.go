package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/arpitnath/super-claude-kit/tools/progressive-reader/pkg/chunker"
	"github.com/arpitnath/super-claude-kit/tools/progressive-reader/pkg/formatter"
	"github.com/arpitnath/super-claude-kit/tools/progressive-reader/pkg/token"
)

const version = "1.0.0"
const defaultTokenPath = "/tmp/continue.toon"

func main() {
	var (
		pathFlag         = flag.String("path", "", "File path to read")
		chunkFlag        = flag.Int("chunk", -1, "Specific chunk number to read (0-indexed)")
		continueFileFlag = flag.String("continue-file", "", "Path to continuation token file (TOON format)")
		maxTokensFlag    = flag.Int("max-tokens", 2000, "Maximum tokens per chunk")
		listFlag         = flag.Bool("list", false, "List all chunks without content")
		versionFlag      = flag.Bool("version", false, "Show version")
		helpFlag         = flag.Bool("help", false, "Show help message")
	)

	flag.Parse()

	if *versionFlag {
		fmt.Printf("progressive-reader v%s\n", version)
		os.Exit(0)
	}

	if *helpFlag || (*pathFlag == "" && *continueFileFlag == "") {
		printHelp()
		os.Exit(0)
	}

	if err := run(*pathFlag, *chunkFlag, *continueFileFlag, *maxTokensFlag, *listFlag); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run(path string, chunkNum int, continueFile string, maxTokens int, list bool) error {
	if continueFile != "" {
		return handleContinuation(continueFile)
	}

	if path == "" {
		return fmt.Errorf("path is required")
	}

	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("invalid path: %w", err)
	}

	content, err := os.ReadFile(absPath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	c, err := chunker.NewChunker(absPath, content, maxTokens)
	if err != nil {
		return fmt.Errorf("failed to create chunker: %w", err)
	}

	chunks, err := c.ChunkFile()
	if err != nil {
		return fmt.Errorf("failed to chunk file: %w", err)
	}

	if len(chunks) == 0 {
		return fmt.Errorf("no chunks generated")
	}

	if list {
		output := formatter.FormatChunkList(chunks, absPath)
		fmt.Print(output)
		return nil
	}

	targetChunk := 0
	if chunkNum >= 0 {
		if chunkNum >= len(chunks) {
			return fmt.Errorf("chunk %d out of range (total: %d)", chunkNum, len(chunks))
		}
		targetChunk = chunkNum
	}

	chunk := chunks[targetChunk]

	tokenPath := ""
	if chunk.HasMore {
		tok := token.NewContinuationToken(
			absPath,
			targetChunk+1,
			"typescript",
			len(chunks),
			content,
		)

		if err := tok.SaveToFile(defaultTokenPath); err != nil {
			return fmt.Errorf("failed to save continuation token: %w", err)
		}
		tokenPath = defaultTokenPath
	}

	output := formatter.FormatChunk(chunk, absPath, tokenPath)
	fmt.Print(output)

	return nil
}

func handleContinuation(continueFile string) error {
	tok, err := token.LoadFromFile(continueFile)
	if err != nil {
		return fmt.Errorf("failed to load continuation token: %w", err)
	}

	content, err := os.ReadFile(tok.File)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	if err := tok.ValidateChecksum(content); err != nil {
		return fmt.Errorf("file validation failed: %w", err)
	}

	c, err := chunker.NewChunker(tok.File, content, 2000)
	if err != nil {
		return fmt.Errorf("failed to create chunker: %w", err)
	}

	chunks, err := c.ChunkFile()
	if err != nil {
		return fmt.Errorf("failed to chunk file: %w", err)
	}

	if tok.Offset >= len(chunks) {
		return fmt.Errorf("chunk offset %d out of range (total: %d)", tok.Offset, len(chunks))
	}

	chunk := chunks[tok.Offset]

	tokenPath := ""
	if chunk.HasMore {
		newTok := token.NewContinuationToken(
			tok.File,
			tok.Offset+1,
			tok.Language,
			len(chunks),
			content,
		)

		if err := newTok.SaveToFile(defaultTokenPath); err != nil {
			return fmt.Errorf("failed to save continuation token: %w", err)
		}
		tokenPath = defaultTokenPath
	}

	output := formatter.FormatChunk(chunk, tok.File, tokenPath)
	fmt.Print(output)

	return nil
}

func printHelp() {
	fmt.Println("progressive-reader - Semantic chunking reader for large files")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  progressive-reader [options]")
	fmt.Println()
	fmt.Println("Options:")
	fmt.Println("  --path <path>            File to read (required unless --continue-file)")
	fmt.Println("  --chunk <n>              Read specific chunk number (0-indexed)")
	fmt.Println("  --continue-file <path>   Continue from previous read (TOON token file)")
	fmt.Println("  --max-tokens <n>         Maximum tokens per chunk (default: 2000)")
	fmt.Println("  --list                   List all chunks without content")
	fmt.Println("  --version                Show version")
	fmt.Println("  --help                   Show this help message")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  progressive-reader --path src/auth.service.ts")
	fmt.Println("  progressive-reader --path src/auth.service.ts --chunk 2")
	fmt.Println("  progressive-reader --continue-file /tmp/continue.toon")
	fmt.Println("  progressive-reader --path src/auth.service.ts --list")
}
