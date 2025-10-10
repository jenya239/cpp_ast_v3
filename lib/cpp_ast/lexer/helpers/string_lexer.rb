# frozen_string_literal: true

module CppAst
  class Lexer
    module StringLexer
      def scan_string_literal(line, column)
        lexeme = '"'.dup
        
        if @position > 0 && @source[@position - 2] == 'R'
          return scan_raw_string_literal(line, column - 1)
        end
        
        loop do
          break if at_end?
          
          char = current_char
          
          if char == '"'
            lexeme << advance
            break
          elsif char == '\\'
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
        lexeme = 'R"'.dup
        
        delimiter = "".dup
        while current_char && current_char != '('
          delimiter << advance
        end
        
        return Token.new(kind: :string, lexeme: 'R"', line: line, column: column) if at_end?
        
        lexeme << delimiter
        lexeme << advance
        
        content = "".dup
        loop do
          break if at_end?
          
          char = advance
          content << char
          
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
    end
  end
end

