# frozen_string_literal: true

module CppAst
  module Parsers
    # TypeParser - module with helper methods for parsing C++ types
    # Handles: int, const int*, std::vector<int>, etc
    module TypeParser
      # Parse a complete type, including qualifiers, pointers, references, templates
      # Returns: [type_string, trivia_after]
      def parse_type
        type = "".dup
        
        loop do
          break unless can_continue_type_parsing?
          
          type << current_token.lexeme
          trivia = current_token.trailing_trivia
          advance_raw
          
          # Handle template arguments <...>
          if current_token.kind == :less
            type << trivia
            type << parse_template_arguments
            trivia = current_leading_trivia
          end
          
          break if is_end_of_type?
          
          type << trivia
        end
        
        extract_trailing_trivia(type)
      end
      
      def can_continue_type_parsing?
        is_type_keyword? || current_token.kind == :identifier || is_type_modifier?
      end
      
      def is_type_keyword?
        current_token.kind.to_s.start_with?("keyword_")
      end
      
      def is_type_modifier?
        [:asterisk, :ampersand, :less, :greater, :colon_colon].include?(current_token.kind)
      end
      
      def is_end_of_type?
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        advance_raw
        next_kind = current_token.kind
        @position = saved_pos
        
        [:equals, :semicolon, :comma, :lparen, :lbracket].include?(next_kind)
      end
      
      def extract_trailing_trivia(type)
        type_match = type.match(/^(.*?)(\s*)$/)
        type_match ? [type_match[1], type_match[2]] : [type, ""]
      end
      
      # Parse template arguments <...>, handling nested templates
      # Returns: string with < ... > including all tokens
      def parse_template_arguments
        result = "".dup
        result << current_token.lexeme  # <
        advance_raw
        
        depth = 1
        while depth > 0 && !at_end?
          if current_token.kind == :less
            depth += 1
          elsif current_token.kind == :greater
            depth -= 1
          end
          
          result << current_token.lexeme
          advance_raw
          
          break if depth == 0
        end
        
        result
      end
      
      # Parse qualified name with :: (e.g., std::vector)
      # Returns: [name_string, trivia_after]
      def parse_qualified_name
        name = "".dup
        trivia_after = ""
        
        loop do
          unless current_token.kind == :identifier
            break
          end
          
          name << current_token.lexeme
          trivia_before_colon = current_token.trailing_trivia
          advance_raw
          
          # Check for ::
          if current_token.kind == :colon_colon
            name << trivia_before_colon << current_token.lexeme
            advance_raw
          else
            # No more ::, this is the end
            trivia_after = trivia_before_colon
            break
          end
        end
        
        [name, trivia_after]
      end
    end
  end
end