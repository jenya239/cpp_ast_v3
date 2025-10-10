# frozen_string_literal: true

module CppAst
  class Lexer
    attr_reader :source, :position, :line, :column
    
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
        Token.new(kind: :dot, lexeme: ".", line: start_line, column: start_column)
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
      
      Token.new(kind: :identifier, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_number(first_char, line, column)
      lexeme = first_char
      
      while current_char&.match?(/[0-9]/)
        lexeme << advance
      end
      
      Token.new(kind: :number, lexeme: lexeme, line: line, column: column)
    end
    
    def scan_line_comment(line, column)
      advance  # skip second /
      lexeme = "//".dup
      
      while current_char && current_char != "\n"
        lexeme << advance
      end
      
      Token.new(kind: :comment, lexeme: lexeme, line: line, column: column)
    end
  end
end

