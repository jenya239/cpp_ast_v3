# frozen_string_literal: true

module CppAst
  class Lexer
    attr_reader :source, :position, :line, :column
    
    # C++ keywords
    KEYWORDS = {
      'if' => :keyword_if,
      'else' => :keyword_else,
      'while' => :keyword_while,
      'for' => :keyword_for,
      'do' => :keyword_do,
      'switch' => :keyword_switch,
      'case' => :keyword_case,
      'default' => :keyword_default,
      'break' => :keyword_break,
      'continue' => :keyword_continue,
      'return' => :keyword_return,
      'goto' => :keyword_goto,
      'try' => :keyword_try,
      'catch' => :keyword_catch,
      'throw' => :keyword_throw,
      'int' => :keyword_int,
      'float' => :keyword_float,
      'double' => :keyword_double,
      'char' => :keyword_char,
      'bool' => :keyword_bool,
      'void' => :keyword_void,
      'auto' => :keyword_auto,
      'const' => :keyword_const,
      'static' => :keyword_static,
      'extern' => :keyword_extern,
      'volatile' => :keyword_volatile,
      'register' => :keyword_register,
      'inline' => :keyword_inline,
      'constexpr' => :keyword_constexpr,
      'class' => :keyword_class,
      'struct' => :keyword_struct,
      'union' => :keyword_union,
      'enum' => :keyword_enum,
      'namespace' => :keyword_namespace,
      'using' => :keyword_using,
      'typedef' => :keyword_typedef,
      'template' => :keyword_template,
      'typename' => :keyword_typename,
      'public' => :keyword_public,
      'private' => :keyword_private,
      'protected' => :keyword_protected,
      'virtual' => :keyword_virtual,
      'override' => :keyword_override,
      'final' => :keyword_final,
      'friend' => :keyword_friend,
      'operator' => :keyword_operator,
      'sizeof' => :keyword_sizeof,
      'alignof' => :keyword_alignof,
      'new' => :keyword_new,
      'delete' => :keyword_delete,
      'this' => :keyword_this,
      'nullptr' => :keyword_nullptr,
      'true' => :keyword_true,
      'false' => :keyword_false,
      'signed' => :keyword_signed,
      'unsigned' => :keyword_unsigned,
      'short' => :keyword_short,
      'long' => :keyword_long
    }.freeze
    
    def initialize(source)
      @source = source
      @position = 0
      @line = 1
      @column = 0
    end
    
    def tokenize
      tokens = []
      
      until at_end?
        token = scan_token
        tokens << token if token
      end
      
      tokens << Token.new(kind: :eof, lexeme: "", line: @line, column: @column)
      tokens
    end
    
    private
    
    def at_end?
      @position >= @source.length
    end
    
    def current_char
      return nil if at_end?
      @source[@position]
    end
    
    def peek(offset = 0)
      pos = @position + offset
      return nil if pos >= @source.length
      @source[pos]
    end
    
    def advance
      char = current_char
      @position += 1
      
      if char == "\n"
        @line += 1
        @column = 0
      else
        @column += 1
      end
      
      char
    end
    
    def scan_token
      start_line = @line
      start_column = @column
      char = advance
      
      case char
      when "\n"
        Token.new(kind: :newline, lexeme: "\n", line: start_line, column: start_column)
      when /\s/
        scan_whitespace(char, start_line, start_column)
      when /[a-zA-Z_]/
        scan_identifier(char, start_line, start_column)
      when /[0-9]/
        scan_number(char, start_line, start_column)
      when "="
        if peek == "="
          advance
          Token.new(kind: :equals_equals, lexeme: "==", line: start_line, column: start_column)
        else
          Token.new(kind: :equals, lexeme: "=", line: start_line, column: start_column)
        end
      when ";"
        Token.new(kind: :semicolon, lexeme: ";", line: start_line, column: start_column)
      when "+"
        if peek == "+"
          advance
          Token.new(kind: :plus_plus, lexeme: "++", line: start_line, column: start_column)
        elsif peek == "="
          advance
          Token.new(kind: :plus_equals, lexeme: "+=", line: start_line, column: start_column)
        else
          Token.new(kind: :plus, lexeme: "+", line: start_line, column: start_column)
        end
      when "-"
        if peek == "-"
          advance
          Token.new(kind: :minus_minus, lexeme: "--", line: start_line, column: start_column)
        elsif peek == ">"
          advance
          Token.new(kind: :arrow, lexeme: "->", line: start_line, column: start_column)
        elsif peek == "="
          advance
          Token.new(kind: :minus_equals, lexeme: "-=", line: start_line, column: start_column)
        else
          Token.new(kind: :minus, lexeme: "-", line: start_line, column: start_column)
        end
      when "*"
        if peek == "="
          advance
          Token.new(kind: :asterisk_equals, lexeme: "*=", line: start_line, column: start_column)
        else
          Token.new(kind: :asterisk, lexeme: "*", line: start_line, column: start_column)
        end
      when "/"
        if peek == "/"
          scan_line_comment(start_line, start_column)
        elsif peek == "*"
          scan_block_comment(start_line, start_column)
        elsif peek == "="
          advance
          Token.new(kind: :slash_equals, lexeme: "/=", line: start_line, column: start_column)
        else
          Token.new(kind: :slash, lexeme: "/", line: start_line, column: start_column)
        end
      when "!"
        if peek == "="
          advance
          Token.new(kind: :exclamation_equals, lexeme: "!=", line: start_line, column: start_column)
        else
          Token.new(kind: :exclamation, lexeme: "!", line: start_line, column: start_column)
        end
      when "~"
        Token.new(kind: :tilde, lexeme: "~", line: start_line, column: start_column)
      when "&"
        if peek == "&"
          advance
          Token.new(kind: :ampersand_ampersand, lexeme: "&&", line: start_line, column: start_column)
        else
          Token.new(kind: :ampersand, lexeme: "&", line: start_line, column: start_column)
        end
      when "|"
        if peek == "|"
          advance
          Token.new(kind: :pipe_pipe, lexeme: "||", line: start_line, column: start_column)
        else
          Token.new(kind: :pipe, lexeme: "|", line: start_line, column: start_column)
        end
      when "^"
        Token.new(kind: :caret, lexeme: "^", line: start_line, column: start_column)
      when "<"
        if peek == "<"
          advance
          Token.new(kind: :less_less, lexeme: "<<", line: start_line, column: start_column)
        elsif peek == "="
          advance
          Token.new(kind: :less_equals, lexeme: "<=", line: start_line, column: start_column)
        else
          Token.new(kind: :less, lexeme: "<", line: start_line, column: start_column)
        end
      when ">"
        if peek == ">"
          advance
          Token.new(kind: :greater_greater, lexeme: ">>", line: start_line, column: start_column)
        elsif peek == "="
          advance
          Token.new(kind: :greater_equals, lexeme: ">=", line: start_line, column: start_column)
        else
          Token.new(kind: :greater, lexeme: ">", line: start_line, column: start_column)
        end
      when ","
        Token.new(kind: :comma, lexeme: ",", line: start_line, column: start_column)
      when "."
        # Check if it's a float starting with dot (.5)
        if peek&.match?(/[0-9]/)
          scan_number(char, start_line, start_column)
        else
          Token.new(kind: :dot, lexeme: ".", line: start_line, column: start_column)
        end
      when ":"
        if peek == ":"
          advance
          Token.new(kind: :colon_colon, lexeme: "::", line: start_line, column: start_column)
        else
          Token.new(kind: :colon, lexeme: ":", line: start_line, column: start_column)
        end
      when "?"
        Token.new(kind: :question, lexeme: "?", line: start_line, column: start_column)
      when "("
        Token.new(kind: :lparen, lexeme: "(", line: start_line, column: start_column)
      when ")"
        Token.new(kind: :rparen, lexeme: ")", line: start_line, column: start_column)
      when "{"
        Token.new(kind: :lbrace, lexeme: "{", line: start_line, column: start_column)
      when "}"
        Token.new(kind: :rbrace, lexeme: "}", line: start_line, column: start_column)
      when "["
        Token.new(kind: :lbracket, lexeme: "[", line: start_line, column: start_column)
      when "]"
        Token.new(kind: :rbracket, lexeme: "]", line: start_line, column: start_column)
      when '"'
        scan_string_literal(start_line, start_column)
      when "'"
        scan_char_literal(start_line, start_column)
      when "#"
        scan_preprocessor(start_line, start_column)
      else
        raise "Unexpected character: #{char.inspect} at #{start_line}:#{start_column}"
      end
    end
    
    def scan_whitespace(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/\s/) && current_char != "\n"
        lexeme << advance
      end
      
      Token.new(kind: :whitespace, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_identifier(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/[a-zA-Z0-9_]/)
        lexeme << advance
      end
      
      # Check if it's a keyword
      kind = KEYWORDS[lexeme] || :identifier
      
      Token.new(kind: kind, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_number(first_char, line, column)
      lexeme = first_char.dup
      
      # Check for hex (0x), binary (0b), or octal (0...)
      if first_char == "0" && current_char
        if current_char.match?(/[xX]/)
          # Hexadecimal
          lexeme << advance
          while current_char&.match?(/[0-9a-fA-F]/)
            lexeme << advance
          end
        elsif current_char.match?(/[bB]/)
          # Binary
          lexeme << advance
          while current_char&.match?(/[01]/)
            lexeme << advance
          end
        elsif current_char.match?(/[0-7]/)
          # Octal
          while current_char&.match?(/[0-7]/)
            lexeme << advance
          end
        elsif current_char == "."
          # Float starting with 0.
          lexeme << advance
          scan_float_fraction(lexeme)
        end
        # Could still be just "0" or have suffix
      elsif first_char == "."
        # Float starting with .
        scan_float_fraction(lexeme)
      else
        # Decimal integer or float
        while current_char&.match?(/[0-9]/)
          lexeme << advance
        end
        
        # Check for decimal point
        if current_char == "."
          next_char = peek(1)  # Look one character ahead
          # Only consume dot if followed by digit
          if next_char&.match?(/[0-9]/)
            lexeme << advance  # consume '.'
            scan_float_fraction(lexeme)
          end
        elsif current_char&.match?(/[eE]/)
          # Scientific notation without decimal point
          scan_exponent(lexeme)
        end
      end
      
      # Scan suffixes (u, U, l, L, ll, LL, f, F, or combinations)
      scan_number_suffix(lexeme)
      
      Token.new(kind: :number, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_float_fraction(lexeme)
      # Scan digits after decimal point
      while current_char&.match?(/[0-9]/)
        lexeme << advance
      end
      
      # Check for exponent
      if current_char&.match?(/[eE]/)
        scan_exponent(lexeme)
      end
    end
    
    def scan_exponent(lexeme)
      lexeme << advance  # consume 'e' or 'E'
      
      # Optional sign
      if current_char&.match?(/[+-]/)
        lexeme << advance
      end
      
      # Exponent digits
      while current_char&.match?(/[0-9]/)
        lexeme << advance
      end
    end
    
    def scan_number_suffix(lexeme)
      # Integer suffixes: u/U, l/L, ll/LL, ul/UL, ull/ULL, etc.
      # Float suffixes: f/F
      
      # Check for unsigned
      if current_char&.match?(/[uU]/)
        lexeme << advance
      end
      
      # Check for long/long long
      if current_char&.match?(/[lL]/)
        lexeme << advance
        # Check for second 'l' or 'L'
        if current_char&.match?(/[lL]/)
          lexeme << advance
        end
      end
      
      # Check for float suffix (f/F)
      if current_char&.match?(/[fF]/)
        lexeme << advance
      end
    end
    
    def scan_line_comment(line, column)
      advance  # skip second /
      lexeme = "//".dup
      
      while current_char && current_char != "\n"
        lexeme << advance
      end
      
      Token.new(kind: :comment, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_block_comment(line, column)
      advance  # skip *
      lexeme = "/*".dup
      
      # Scan until */
      loop do
        break if at_end?
        
        char = advance
        lexeme << char
        
        # Check for end of comment
        if char == '*' && current_char == '/'
          lexeme << advance
          break
        end
      end
      
      Token.new(kind: :comment, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_string_literal(line, column)
      lexeme = '"'.dup
      
      # Check for raw string literal R"delimiter(...)delimiter"
      if @position > 0 && @source[@position - 2] == 'R'
        return scan_raw_string_literal(line, column - 1)
      end
      
      # Regular string literal
      loop do
        break if at_end?
        
        char = current_char
        
        if char == '"'
          lexeme << advance
          break
        elsif char == '\\'
          # Escape sequence
          lexeme << advance
          lexeme << advance unless at_end?
        elsif char == "\n"
          raise "Unterminated string literal at #{line}:#{column}"
        else
          lexeme << advance
        end
      end
      
      Token.new(kind: :string, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_raw_string_literal(line, column)
      # Back up to capture 'R'
      lexeme = 'R"'.dup
      
      # Read delimiter
      delimiter = "".dup
      while current_char && current_char != '('
        delimiter << advance
      end
      
      return Token.new(kind: :string, lexeme: 'R"', line: line, column: column) if at_end?
      
      lexeme << delimiter
      lexeme << advance  # '('
      
      # Read content until )delimiter"
      content = "".dup
      loop do
        break if at_end?
        
        char = advance
        content << char
        
        # Check for end pattern
        if content.end_with?(")#{delimiter}\"")
          lexeme << content
          break
        end
      end
      
      Token.new(kind: :string, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_char_literal(line, column)
      lexeme = "'".dup
      
      loop do
        break if at_end?
        
        char = current_char
        
        if char == "'"
          lexeme << advance
          break
        elsif char == '\\'
          # Escape sequence
          lexeme << advance
          lexeme << advance unless at_end?
        elsif char == "\n"
          raise "Unterminated character literal at #{line}:#{column}"
        else
          lexeme << advance
        end
      end
      
      Token.new(kind: :char, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_preprocessor(line, column)
      lexeme = '#'.dup
      
      # Scan until end of line, handling line continuations
      loop do
        break if at_end?
        
        char = current_char
        
        if char == "\n"
          # Check for line continuation
          if @position > 0 && @source[@position - 1] == '\\'
            lexeme << advance
          else
            break
          end
        else
          lexeme << advance
        end
      end
      
      Token.new(kind: :preprocessor, lexeme: lexeme, line: line, column: column)
    end
  end
end

