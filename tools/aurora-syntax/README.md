# Aurora Syntax (VS Code / Cursor)

Lightweight workspace extension that provides syntax highlighting for the Aurora `.aur` language.

## Install in VS Code

1. Open VS Code (or Cursor).
2. Run the command palette: `Developer: Install Extension from Location…`
3. Point it to the folder `experimental/tools/aurora-syntax`.
4. Reload the window.

`.aur` files (and `failing.aur`) will now highlight Aurora keywords, operators, literals, and comments.

## Supported features

- **Keywords**: `fn`, `let`, `mut`, `return`, `if`, `then`, `else`, `while`, `for`, `in`, `do`, `end`, `match`, `module`, `import`, `export`, `enum`, `from`, `as`, `where`, `case`, `of`, `break`, `continue`, `extern`
- **Types**: Primitives (`i32`, `f32`, `bool`, `str`, `string`, `void`, `regex`) and custom types (capitalized names)
- **Comments**: Single-line `//` comments
- **Literals**:
  - Numbers with underscores (`1_000`, `3.14_159`)
  - Strings with escape sequences (`"Hello\nWorld"`)
  - Heredocs (`<<DELIMITER`, `<<~DELIMITER`)
  - Regex patterns (`/pattern/flags`)
- **Operators**: `+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `=`, `.`, `:`, `|>`
- **Booleans**: `true`, `false`

You can customise the grammar by editing `syntaxes/aurora.tmLanguage.json`. After changes, reload VS Code to apply.
