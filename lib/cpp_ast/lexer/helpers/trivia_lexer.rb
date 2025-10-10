# frozen_string_literal: true

module CppAst
  class Lexer
    module TriviaLexer
      def scan_line_comment_lexeme
        lexeme = "//".dup
        advance
        advance
        
        while current_char && current_char != "\n"
          lexeme << advance
        end
        
        lexeme
      end
      
      def scan_block_comment_lexeme
        lexeme = "/*".dup
        advance
        advance
        
        loop do
          break if at_end?
          
          char = advance
          lexeme << char
          
          if char == '*' && current_char == '/'
            lexeme << advance
            break
          end
        end
        
        lexeme
      end
      
      def scan_preprocessor_lexeme
        lexeme = '#'.dup
        advance
        
        loop do
          break if at_end?
          
          char = current_char
          
          if char == "\n"
            if @position > 0 && @source[@position - 1] == '\\'
              lexeme << advance
            else
              break
            end
          else
            lexeme << advance
          end
        end
        
        lexeme
      end
      
      def scan_attribute_lexeme
        lexeme = "[[".dup
        advance
        advance
        
        depth = 1
        loop do
          break if at_end?
          
          char = current_char
          
          if char == "[" && peek == "["
            depth += 1
            lexeme << advance
            lexeme << advance
          elsif char == "]" && peek == "]"
            depth -= 1
            lexeme << advance
            lexeme << advance
            break if depth.zero?
          else
            lexeme << advance
          end
        end
        
        lexeme
      end
    end
  end
end

