package formatter

import (
	"fmt"
	"strings"

	"github.com/arpitnath/super-claude-kit/tools/progressive-reader/pkg/chunker"
)

func FormatChunk(chunk chunker.Chunk, filePath string, tokenPath string) string {
	var output strings.Builder

	header := fmt.Sprintf("Chunk %d/%d", chunk.CurrentChunk+1, chunk.TotalChunks)
	output.WriteString("┌─ ")
	output.WriteString(header)
	output.WriteString(strings.Repeat("─", 54-len(header)))
	output.WriteString("┐\n")

	output.WriteString(fmt.Sprintf("│ File: %-47s│\n", truncate(filePath, 47)))
	output.WriteString(fmt.Sprintf("│ Lines: %-46s│\n", fmt.Sprintf("%d-%d", chunk.StartLine, chunk.EndLine)))

	if chunk.Type != "" && chunk.Type != "code" && chunk.Type != "text" {
		output.WriteString(fmt.Sprintf("│ Type: %-47s│\n", chunk.Type))
	}

	if chunk.Name != "" {
		output.WriteString(fmt.Sprintf("│ Name: %-47s│\n", truncate(chunk.Name, 47)))
	}

	if chunk.Context != "" {
		output.WriteString(fmt.Sprintf("│ Context: %-44s│\n", truncate(chunk.Context, 44)))
	}

	output.WriteString("└─────────────────────────────────────────────────────┘\n")
	output.WriteString("\n")

	lines := strings.Split(chunk.Content, "\n")
	lineNum := chunk.StartLine
	for _, line := range lines {
		output.WriteString(fmt.Sprintf("%6d  %s\n", lineNum, line))
		lineNum++
	}

	output.WriteString("\n")

	if chunk.HasMore {
		output.WriteString("┌─────────────────────────────────────────────────────┐\n")
		output.WriteString("│ More content available                              │\n")
		if tokenPath != "" {
			pathDisplay := truncate(tokenPath, 38)
			output.WriteString(fmt.Sprintf("│ Continuation token saved to: %-23s│\n", pathDisplay))
			output.WriteString(fmt.Sprintf("│ Use: progressive-reader --continue-file %s%s│\n", pathDisplay, strings.Repeat(" ", 11-len(pathDisplay)+38)))
		}
		output.WriteString("└─────────────────────────────────────────────────────┘\n")
	} else {
		output.WriteString("┌─────────────────────────────────────────────────────┐\n")
		output.WriteString("│ End of file                                          │\n")
		output.WriteString("└─────────────────────────────────────────────────────┘\n")
	}

	return output.String()
}

func FormatChunkList(chunks []chunker.Chunk, filePath string) string {
	var output strings.Builder

	output.WriteString(fmt.Sprintf("File: %s\n", filePath))
	output.WriteString(fmt.Sprintf("Total chunks: %d\n\n", len(chunks)))

	for i, chunk := range chunks {
		typeInfo := chunk.Type
		if chunk.Name != "" {
			typeInfo = fmt.Sprintf("%s: %s", chunk.Type, chunk.Name)
		}

		indent := ""
		if chunk.Depth > 0 {
			indent = strings.Repeat("  ", chunk.Depth)
		}

		output.WriteString(fmt.Sprintf("%sChunk %d/%d (lines %d-%d): %s\n",
			indent, i+1, len(chunks), chunk.StartLine, chunk.EndLine, typeInfo))

		if chunk.Context != "" {
			output.WriteString(fmt.Sprintf("%s  %s\n", indent, truncate(chunk.Context, 70)))
		}
	}

	return output.String()
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}
