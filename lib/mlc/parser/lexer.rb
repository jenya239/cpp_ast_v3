# frozen_string_literal: true

module MLC
  module Parser
    class Token
      attr_reader :type, :value, :line, :column, :file,
                  :end_line, :end_column, :text, :line_text
      
      def initialize(type:, value:, line: 1, column: 1, file: nil,
                     end_line: line, end_column: column,
                     text: nil, line_text: nil)
        @type = type
        @value = value
        @line = line
        @column = column
        @file = file
        @end_line = end_line
        @end_column = end_column
        @text = text
        @line_text = line_text
      end
      
      def to_s
        "#{type}(#{value})"
      end
    end
    
    class Lexer
      KEYWORDS = %w[
        fn type let mut return break continue if then else while for in do end match
        i32 f32 bool void str module export import enum from as extern
      ].freeze
      
      OPERATORS = %w[
        + - * / % = == != < > <= >= && || !
        . , ; : ( ) { } [ ]
      ].freeze
      
      def initialize(source, filename: nil)
        @source = source
        @pos = 0
        @line = 1
        @column = 1
        @tokens = []
        @filename = filename
      end
      
      def tokenize
        while @pos < @source.length
          skip_whitespace
          skip_comments
          next if @pos >= @source.length

          char = @source[@pos]
          
          case char
          when /[a-zA-Z_]/
            tokenize_identifier_or_keyword
          when /[0-9]/
            tokenize_number
          when '"'
            tokenize_string
          when '<'
            # Check for heredoc syntax << or <<~
            if @pos + 1 < @source.length && @source[@pos + 1] == '<'
              tokenize_heredoc
            else
              tokenize_operator
            end
          when '/'
            # Distinguish between division operator and regex literal
            if regex_context?
              tokenize_regex
            else
              tokenize_operator
            end
          when /[=+\-*%>!&|.]/
            tokenize_operator
          when '('
            add_token(:LPAREN, char)
            advance
          when ')'
            add_token(:RPAREN, char)
            advance
          when '{'
            add_token(:LBRACE, char)
            advance
          when '}'
            add_token(:RBRACE, char)
            advance
          when '['
            add_token(:LBRACKET, char)
            advance
          when ']'
            add_token(:RBRACKET, char)
            advance
          when ','
            add_token(:COMMA, char)
            advance
          when ';'
            add_token(:SEMICOLON, char)
            advance
          when ':'
            add_token(:COLON, char)
            advance
          else
            advance # Skip unknown characters
          end
        end
        
        add_token(:EOF, "")
        @tokens
      end
      
      private
      
      def skip_whitespace
        while @pos < @source.length && @source[@pos] =~ /\s/
          if @source[@pos] == "\n"
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @pos += 1
        end
      end

      def skip_comments
        loop do
          break if @pos >= @source.length

          if @source[@pos] == '#'
            # Skip # comment
            @pos += 1
            @column += 1
            while @pos < @source.length && @source[@pos] != "\n"
              @pos += 1
              @column += 1
            end
          elsif @pos < @source.length - 1 && @source[@pos] == '/' && @source[@pos + 1] == '/'
            # Skip single-line comment (// or ///)
            @pos += 2
            @column += 2
            while @pos < @source.length && @source[@pos] != "\n"
              @pos += 1
              @column += 1
            end
          elsif @pos < @source.length - 1 && @source[@pos] == '/' && @source[@pos + 1] == '*'
            # Skip block comment /* ... */
            @pos += 2
            @column += 2
            while @pos < @source.length - 1
              if @source[@pos] == '*' && @source[@pos + 1] == '/'
                @pos += 2
                @column += 2
                break
              else
                advance_char
              end
            end
          else
            break
          end
          skip_whitespace
        end
      end

      def advance_char
        if @source[@pos] == "\n"
          @line += 1
          @column = 1
        else
          @column += 1
        end
        @pos += 1
      end
      
      def tokenize_identifier_or_keyword
        start_line = @line
        start_column = @column
        start = @pos
        while @pos < @source.length && @source[@pos] =~ /[a-zA-Z0-9_]/
          @pos += 1
        end
        
        value = @source[start...@pos]
        @column += value.length
        
        type = KEYWORDS.include?(value) ? value.upcase.to_sym : :IDENTIFIER
        add_token(type, value, line: start_line, column: start_column)
      end
      
      def tokenize_number
        start_line = @line
        start_column = @column
        start = @pos
        while @pos < @source.length && @source[@pos] =~ /[0-9]/
          @pos += 1
        end
        
        # Check for decimal point
        if @pos < @source.length && @source[@pos] == '.'
          @pos += 1
          while @pos < @source.length && @source[@pos] =~ /[0-9]/
            @pos += 1
          end
          value = @source[start...@pos]
          @column += value.length
          add_token(:FLOAT_LITERAL, value.to_f, line: start_line, column: start_column)
        else
          value = @source[start...@pos]
          @column += value.length
          add_token(:INT_LITERAL, value.to_i, line: start_line, column: start_column)
        end
      end
      
      def tokenize_string
        start_line = @line
        start_column = @column
        @pos += 1 # Skip opening quote
        @column += 1

        chars = []
        while @pos < @source.length && @source[@pos] != '"'
          if @source[@pos] == '\\'
            # Handle escape sequence
            @pos += 1
            @column += 1
            if @pos >= @source.length
              raise "Unterminated escape sequence"
            end

            case @source[@pos]
            when 'n'
              chars << "\n"
            when 't'
              chars << "\t"
            when 'r'
              chars << "\r"
            when '\\'
              chars << "\\"
            when '"'
              chars << '"'
            when '0'
              chars << "\0"
            else
              # Unknown escape - keep backslash
              chars << '\\'
              chars << @source[@pos]
            end
            @pos += 1
            @column += 1
          else
            if @source[@pos] == "\n"
              @line += 1
              @column = 1
            else
              @column += 1
            end
            chars << @source[@pos]
            @pos += 1
          end
        end

        value = chars.join
        @pos += 1 # Skip closing quote
        @column += 1

        add_token(:STRING_LITERAL, value, line: start_line, column: start_column)
      end

      def tokenize_heredoc
        start_line = @line
        start_column = @column

        # Skip << or <<~
        @pos += 2
        @column += 2
        strip_indent = false

        # Check for ~ (indented heredoc)
        if @pos < @source.length && @source[@pos] == '~'
          strip_indent = true
          @pos += 1
          @column += 1
        end

        # Read delimiter (must be uppercase identifier)
        delimiter_start = @pos
        while @pos < @source.length && @source[@pos] =~ /[A-Z0-9_]/
          @pos += 1
          @column += 1
        end

        delimiter = @source[delimiter_start...@pos]
        if delimiter.empty?
          raise "Heredoc delimiter must be an uppercase identifier"
        end

        # Skip to end of line
        while @pos < @source.length && @source[@pos] != "\n"
          @pos += 1
          @column += 1
        end

        if @pos < @source.length
          @pos += 1 # Skip newline
          @line += 1
          @column = 1
        end

        # Collect heredoc body lines
        body_lines = []
        content_start = @pos

        while @pos < @source.length
          line_start = @pos

          # Read current line
          while @pos < @source.length && @source[@pos] != "\n"
            @pos += 1
          end

          line = @source[line_start...@pos]

          # Check if this line is the delimiter
          if line.strip == delimiter
            # Found end delimiter
            if @pos < @source.length
              @pos += 1 # Skip newline
              @line += 1
              @column = 1
            end
            break
          end

          body_lines << line

          if @pos < @source.length
            @pos += 1 # Skip newline
            @line += 1
            @column = 1
          end
        end

        # Process body based on strip_indent flag
        value = if strip_indent
          strip_common_indent(body_lines)
        else
          body_lines.join("\n")
        end

        add_token(:STRING_LITERAL, value, line: start_line, column: start_column)
      end

      def strip_common_indent(lines)
        # Find minimum indentation (ignoring empty lines)
        non_empty_lines = lines.reject { |line| line.strip.empty? }
        return "" if non_empty_lines.empty?

        min_indent = non_empty_lines.map { |line|
          line.match(/^(\s*)/)[1].length
        }.min

        # Strip min_indent from all lines
        stripped_lines = lines.map { |line|
          if line.strip.empty?
            "" # Keep empty lines empty
          else
            line[min_indent..-1] || ""
          end
        }

        stripped_lines.join("\n")
      end

      def regex_context?
        # Regex can appear after: =, (, [, {, ,, return, :, =>, operators
        # Regex cannot appear after: ), ], identifiers, numbers, strings
        return true if @tokens.empty?

        last_token = @tokens.last
        return false if last_token.nil?

        # After these tokens, / starts a regex
        regex_after = [:EQUAL, :LPAREN, :LBRACKET, :LBRACE, :COMMA,
                       :RETURN, :COLON, :FAT_ARROW, :ARROW, :OPERATOR]

        regex_after.include?(last_token.type)
      end

      def tokenize_regex
        # Regex format: /pattern/flags
        start_line = @line
        start_column = @column

        # Skip opening /
        @pos += 1
        @column += 1

        pattern = ""

        # Read pattern until closing /
        while @pos < @source.length
          char = @source[@pos]

          if char == '/'
            # Found closing /
            @pos += 1
            @column += 1
            break
          elsif char == '\\'
            # Escape sequence
            pattern += char
            @pos += 1
            @column += 1

            if @pos < @source.length
              pattern += @source[@pos]
              @pos += 1
              @column += 1
            end
          elsif char == "\n"
            # Newline in regex pattern is an error, but we'll be permissive
            @line += 1
            @column = 1
            pattern += char
            @pos += 1
          else
            pattern += char
            @pos += 1
            @column += 1
          end
        end

        # Read flags (optional)
        flags = ""
        while @pos < @source.length && @source[@pos] =~ /[gimsuvy]/
          flags += @source[@pos]
          @pos += 1
          @column += 1
        end

        # Store both pattern and flags in the token value
        add_token(:REGEX, {pattern: pattern, flags: flags}, line: start_line, column: start_column)
      end

      def tokenize_operator
        start_line = @line
        start_column = @column
        char = @source[@pos]

        # Handle arrow operator ->
        if char == '-' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:ARROW, "->", line: start_line, column: start_column)
          return
        end

        # Handle fat arrow operator =>
        if char == '=' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:FAT_ARROW, "=>", line: start_line, column: start_column)
          return
        end

        # Handle pipe operator |>
        if char == '|' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:PIPE, "|>", line: start_line, column: start_column)
          return
        end

        # Handle multi-character operators
        if @pos + 1 < @source.length
          next_char = @source[@pos + 1]
          two_char = char + next_char

          if %w[== != <= >= && ||].include?(two_char)
            @pos += 2
            @column += 2
            add_token(:OPERATOR, two_char, line: start_line, column: start_column)
            return
          end
        end

        # Special handling for single =
        if char == '='
          @pos += 1
          @column += 1
          add_token(:EQUAL, char, line: start_line, column: start_column)
          return
        end

        @pos += 1
        @column += 1
        add_token(:OPERATOR, char, line: start_line, column: start_column)
      end
      
      def add_token(type, value, line: @line, column: @column)
        @tokens << Token.new(
          type: type,
          value: value,
          line: line,
          column: column,
          file: @filename
        )
      end
      
      def advance
        @pos += 1
        @column += 1
      end
    end
  end
end
