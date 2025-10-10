# frozen_string_literal: true

require_relative 'helpers/number_lexer'
require_relative 'helpers/string_lexer'
require_relative 'helpers/trivia_lexer'

module CppAst
  class Lexer
    include NumberLexer
    include StringLexer
    include TriviaLexer
    
    attr_reader :source, :position, :line, :column
    
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
      eof_leading_accumulator = "".dup
      
      until at_end?
        leading = collect_trivia_as_string
        token = scan_non_trivia_token
        
        if token
          token.leading_trivia = eof_leading_accumulator + leading
          eof_leading_accumulator = "".dup
          trailing = collect_trailing_trivia
          token.trailing_trivia = trailing
          tokens << token
        else
          eof_leading_accumulator << leading
        end
      end
      
      eof = Token.new(kind: :eof, lexeme: "", line: @line, column: @column)
      eof.leading_trivia = eof_leading_accumulator
      eof.trailing_trivia = ""
      tokens << eof
      
      tokens
    end
    
    def at_end?
      @position >= @source.length
    end
    
    def collect_trivia_as_string
      trivia = "".dup
      while trivia_ahead?
        trivia << scan_trivia_token
      end
      trivia
    end
    
    def collect_trailing_trivia
      trivia = "".dup
      loop do
        break unless trivia_ahead?
        char = current_char
        trivia << scan_trivia_token
        break if char == "\n"
      end
      trivia
    end
    
    def trivia_ahead?
      return false if at_end?
      char = current_char
      
      return true if char&.match?(/\s/)
      return true if char == '/' && (peek(1) == '/' || peek(1) == '*')
      return true if char == '#'
      return true if char == '[' && peek(1) == '['
      
      false
    end
    
    def scan_trivia_token
      start_line = @line
      start_column = @column
      char = current_char
      
      case char
      when "\n"
        advance
        "\n"
      when /\s/
        lexeme = advance.dup
        while current_char&.match?(/\s/) && current_char != "\n"
          lexeme << advance
        end
        lexeme
      when "/"
        if peek(1) == "/"
          scan_line_comment_lexeme
        elsif peek(1) == "*"
          scan_block_comment_lexeme
        else
          raise "Unexpected /"
        end
      when "#"
        scan_preprocessor_lexeme
      when "["
        if peek(1) == "["
          scan_attribute_lexeme
        else
          raise "Unexpected ["
        end
      else
        raise "Not a trivia token: #{char.inspect}"
      end
    end
    
    def scan_non_trivia_token
      return nil if at_end?
      return nil if trivia_ahead?
      
      start_line = @line
      start_column = @column
      char = advance
      
      case char
      when /[a-zA-Z_]/
        scan_identifier_or_keyword(char, start_line, start_column)
      when /[0-9]/
        scan_literal_token(char, start_line, start_column, is_number: true)
      when '"', "'"
        scan_literal_token(char, start_line, start_column, is_string: true)
      when "=", "+", "-", "*", "/", "!", "%", "~", "&", "|", "^", "<", ">", "."
        scan_operator_token(char, start_line, start_column)
      when ";", ",", ":", "?", "(", ")", "{", "}", "[", "]"
        scan_punctuation_token(char, start_line, start_column)
      else
        raise "Unexpected character: #{char.inspect} at #{start_line}:#{start_column}"
      end
    end
    
    def scan_operator_token(char, start_line, start_column)
      case char
      when "="
        peek == "=" ? (advance; Token.new(kind: :equals_equals, lexeme: "==", line: start_line, column: start_column)) : Token.new(kind: :equals, lexeme: "=", line: start_line, column: start_column)
      when "+"
        if peek == "+"
          advance; Token.new(kind: :plus_plus, lexeme: "++", line: start_line, column: start_column)
        elsif peek == "="
          advance; Token.new(kind: :plus_equals, lexeme: "+=", line: start_line, column: start_column)
        else
          Token.new(kind: :plus, lexeme: "+", line: start_line, column: start_column)
        end
      when "-"
        if peek == "-"
          advance; Token.new(kind: :minus_minus, lexeme: "--", line: start_line, column: start_column)
        elsif peek == ">"
          advance; Token.new(kind: :arrow, lexeme: "->", line: start_line, column: start_column)
        elsif peek == "="
          advance; Token.new(kind: :minus_equals, lexeme: "-=", line: start_line, column: start_column)
        else
          Token.new(kind: :minus, lexeme: "-", line: start_line, column: start_column)
        end
      when "*"
        peek == "=" ? (advance; Token.new(kind: :asterisk_equals, lexeme: "*=", line: start_line, column: start_column)) : Token.new(kind: :asterisk, lexeme: "*", line: start_line, column: start_column)
      when "/"
        peek == "=" ? (advance; Token.new(kind: :slash_equals, lexeme: "/=", line: start_line, column: start_column)) : Token.new(kind: :slash, lexeme: "/", line: start_line, column: start_column)
      when "!"
        peek == "=" ? (advance; Token.new(kind: :exclamation_equals, lexeme: "!=", line: start_line, column: start_column)) : Token.new(kind: :exclamation, lexeme: "!", line: start_line, column: start_column)
      when "%"
        peek == "=" ? (advance; Token.new(kind: :percent_equals, lexeme: "%=", line: start_line, column: start_column)) : Token.new(kind: :percent, lexeme: "%", line: start_line, column: start_column)
      when "~"
        Token.new(kind: :tilde, lexeme: "~", line: start_line, column: start_column)
      when "&"
        peek == "&" ? (advance; Token.new(kind: :ampersand_ampersand, lexeme: "&&", line: start_line, column: start_column)) : Token.new(kind: :ampersand, lexeme: "&", line: start_line, column: start_column)
      when "|"
        peek == "|" ? (advance; Token.new(kind: :pipe_pipe, lexeme: "||", line: start_line, column: start_column)) : Token.new(kind: :pipe, lexeme: "|", line: start_line, column: start_column)
      when "^"
        Token.new(kind: :caret, lexeme: "^", line: start_line, column: start_column)
      when "<"
        if peek == "<"
          advance; Token.new(kind: :less_less, lexeme: "<<", line: start_line, column: start_column)
        elsif peek == "="
          advance; Token.new(kind: :less_equals, lexeme: "<=", line: start_line, column: start_column)
        else
          Token.new(kind: :less, lexeme: "<", line: start_line, column: start_column)
        end
      when ">"
        if peek == ">"
          advance; Token.new(kind: :greater_greater, lexeme: ">>", line: start_line, column: start_column)
        elsif peek == "="
          advance; Token.new(kind: :greater_equals, lexeme: ">=", line: start_line, column: start_column)
        else
          Token.new(kind: :greater, lexeme: ">", line: start_line, column: start_column)
        end
      when "."
        peek&.match?(/[0-9]/) ? scan_number(char, start_line, start_column) : Token.new(kind: :dot, lexeme: ".", line: start_line, column: start_column)
      end
    end
    
    def scan_punctuation_token(char, start_line, start_column)
      case char
      when ";" then Token.new(kind: :semicolon, lexeme: ";", line: start_line, column: start_column)
      when "," then Token.new(kind: :comma, lexeme: ",", line: start_line, column: start_column)
      when ":"
        peek == ":" ? (advance; Token.new(kind: :colon_colon, lexeme: "::", line: start_line, column: start_column)) : Token.new(kind: :colon, lexeme: ":", line: start_line, column: start_column)
      when "?" then Token.new(kind: :question, lexeme: "?", line: start_line, column: start_column)
      when "(" then Token.new(kind: :lparen, lexeme: "(", line: start_line, column: start_column)
      when ")" then Token.new(kind: :rparen, lexeme: ")", line: start_line, column: start_column)
      when "{" then Token.new(kind: :lbrace, lexeme: "{", line: start_line, column: start_column)
      when "}" then Token.new(kind: :rbrace, lexeme: "}", line: start_line, column: start_column)
      when "[" then Token.new(kind: :lbracket, lexeme: "[", line: start_line, column: start_column)
      when "]" then Token.new(kind: :rbracket, lexeme: "]", line: start_line, column: start_column)
      end
    end
    
    def scan_literal_token(char, start_line, start_column, is_number: false, is_string: false)
      return scan_number(char, start_line, start_column) if is_number
      return scan_string_literal(start_line, start_column) if is_string && char == '"'
      scan_char_literal(start_line, start_column) if is_string && char == "'"
    end
    
    def scan_identifier_or_keyword(char, start_line, start_column)
      scan_identifier(char, start_line, start_column)
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
    
    def scan_identifier(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/[a-zA-Z0-9_]/)
        lexeme << advance
      end
      
      kind = KEYWORDS[lexeme] || :identifier
      
      Token.new(kind: kind, lexeme: lexeme, line: line, column: column)
    end
  end
end
