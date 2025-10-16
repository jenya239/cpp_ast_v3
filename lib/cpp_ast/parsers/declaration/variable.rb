# frozen_string_literal: true

module CppAst
  module Parsers
    module VariableParser
      def parse_variable_declaration(leading_trivia)
        type, type_suffix = parse_variable_type
        type_suffix = " " if type_suffix.empty?
        
        declarators = []
        declarator_separators = []
        
        loop do
          declarators << parse_variable_declarator
          
          if current_token.kind == :comma
            declarator_separators << current_token.lexeme + current_token.trailing_trivia
            advance_raw
          else
            break
          end
        end
        
        _semicolon_prefix = current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::VariableDeclaration.new(
          leading_trivia: leading_trivia,
          type: type,
          declarators: declarators,
          declarator_separators: declarator_separators,
          type_suffix: type_suffix
        )
        
        [stmt, trailing]
      end
      
      def parse_variable_type
        type = "".dup
        template_depth = 0
        _last_trivia = ""
        
        loop do
          break unless current_token.kind.to_s.start_with?("keyword_") || 
                       current_token.kind == :identifier ||
                       [:asterisk, :ampersand, :less, :greater, :colon_colon, :comma, :lparen, :rparen].include?(current_token.kind)
          
          was_colon_colon = current_token.kind == :colon_colon
          
          template_depth += 1 if current_token.kind == :less
          template_depth -= 1 if current_token.kind == :greater
          
          break if current_token.kind == :comma && template_depth == 0
          
          type << current_token.lexeme
          trivia = current_token.trailing_trivia
          advance_raw

          # Always preserve spaces after keywords and identifiers in type
          type << trivia
          _last_trivia = trivia
          
          next if was_colon_colon && (current_token.kind == :identifier || 
                                      current_token.kind.to_s.start_with?("keyword_"))
          
          next if template_depth > 0 && [:comma, :greater, :lparen, :rparen].include?(current_token.kind)
          
          if current_token.kind == :identifier
            saved_pos = @position
            advance_raw
            next_kind = current_token.kind
            @position = saved_pos
            
            if [:equals, :semicolon, :comma, :lparen, :lbracket, :lbrace].include?(next_kind)
              break
            end
          end
        end
        
        # Extract final trailing whitespace as type_suffix
        type_match = type.match(/^(.*?)(\s*)$/)
        type_match ? [type_match[1], type_match[2]] : [type, ""]
      end
      
      def parse_variable_declarator
        decl_text = "".dup
        
        loop do
          break if at_end? || [:semicolon, :comma].include?(current_token.kind)
          
          decl_text << current_leading_trivia
          
          case current_token.kind
          when :equals
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            parse_variable_initializer(decl_text)
            break
          when :lparen
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lparen, :rparen)
          when :lbrace
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lbrace, :rbrace)
          else
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        decl_text
      end
      
      def parse_variable_initializer(decl_text)
        loop do
          break if at_end? || [:semicolon, :comma].include?(current_token.kind)
          
          decl_text << current_leading_trivia
          
          if current_token.kind == :lparen
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lparen, :rparen)
          elsif current_token.kind == :lbrace
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lbrace, :rbrace)
          else
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
      end
      
      def collect_balanced_tokens(text, open_kind, close_kind)
        depth = 1
        loop do
          break if at_end?
          text << current_leading_trivia
          depth += 1 if current_token.kind == open_kind
          depth -= 1 if current_token.kind == close_kind
          text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          break if depth.zero?
        end
      end
      
      def looks_like_declaration?
        type_keywords = [:keyword_int, :keyword_float, :keyword_double, :keyword_char, 
                        :keyword_bool, :keyword_void, :keyword_auto,
                        :keyword_const, :keyword_static, :keyword_extern,
                        :keyword_unsigned, :keyword_signed, :keyword_long, :keyword_short,
                        :keyword_constexpr, :keyword_inline, :keyword_volatile, :keyword_register]
        
        return true if type_keywords.include?(current_token.kind)
        
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        advance_raw
        current_leading_trivia
        
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier
            advance_raw
            current_leading_trivia
          end
        end
        
        if current_token.kind == :less
          depth = 1
          advance_raw
          
          while depth > 0 && !at_end?
            if current_token.kind == :less
              depth += 1
            elsif current_token.kind == :greater
              depth -= 1
            end
            advance_raw
          end
          
          current_leading_trivia
        end
        
        result = [:identifier, :asterisk, :ampersand].include?(current_token.kind)
        
        @position = saved_pos
        result
      end
    end
  end
end

