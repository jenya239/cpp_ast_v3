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
        
        # Parse type (can be multiple tokens: const int*, unsigned long, std::vector<int>, etc)
        loop do
          # Type keywords and modifiers
          if current_token.kind.to_s.start_with?("keyword_") || 
             current_token.kind == :identifier ||
             [:asterisk, :ampersand, :less, :greater, :colon_colon].include?(current_token.kind)
            
            type << current_token.lexeme
            trivia = current_token.trailing_trivia
            advance_raw
            
            # Handle template arguments <...>
            if current_token.kind == :less
              type << trivia
              type << parse_template_arguments
              trivia = current_leading_trivia
            end
            
            # Check if we're done with type (next is identifier for variable/function name)
            if current_token.kind == :identifier
              # This might be the name - check what follows
              saved_pos = @position
              advance_raw
              next_trivia = current_leading_trivia
              next_kind = current_token.kind
              @position = saved_pos
              
              # If followed by =, ; , ( [ then this identifier is the name
              if [:equals, :semicolon, :comma, :lparen, :lbracket].include?(next_kind)
                type << trivia
                break
              end
            end
            
            type << trivia
          else
            break
          end
        end
        
        # Extract trailing whitespace from type
        type_match = type.match(/^(.*?)(\s*)$/)
        if type_match
          [type_match[1], type_match[2]]
        else
          [type, ""]
        end
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