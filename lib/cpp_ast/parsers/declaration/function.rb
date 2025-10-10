# frozen_string_literal: true

module CppAst
  module Parsers
    module FunctionParser
      def parse_function_declaration(leading_trivia)
        prefix_modifiers = parse_function_prefix_modifiers
        is_constructor, constructor_class_name = detect_constructor_pattern
        
        return_type, trivia_after = if is_constructor
          ["", ""]
        else
          parse_function_return_type
        end
        
        name, return_type_suffix = parse_function_name(is_constructor, trivia_after)
        _lparen_prefix = current_leading_trivia
        parameters, param_separators, lparen_suffix, rparen_suffix, after_rparen = parse_function_parameters
        modifiers_text, after_rparen = parse_function_modifiers_postfix(after_rparen, is_constructor)
        
        body, trailing = if current_token.kind == :lbrace
          parse_block_statement(after_rparen)
        else
          _semicolon_prefix = after_rparen + current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          [nil, trailing]
        end
        
        stmt = Nodes::FunctionDeclaration.new(
          leading_trivia: leading_trivia,
          prefix_modifiers: prefix_modifiers,
          return_type: return_type,
          name: name,
          parameters: parameters,
          body: body,
          return_type_suffix: return_type_suffix,
          lparen_suffix: lparen_suffix,
          rparen_suffix: rparen_suffix,
          param_separators: param_separators,
          modifiers_text: modifiers_text
        )
        
        [stmt, trailing]
      end
      
      def looks_like_function_declaration?
        return false unless current_token.kind == :identifier || current_token.kind.to_s.start_with?("keyword_")
        
        return true if looks_like_in_class_constructor?
        return true if looks_like_out_of_line_constructor?
        
        saved_pos = @position
        
        unless skip_function_modifiers_and_check
          @position = saved_pos
          return false
        end
        
        skip_type_specification
        return true if check_operator_overload_pattern(saved_pos)
        
        advance_raw if current_token.kind == :tilde
        current_leading_trivia
        
        is_func = current_token.kind == :identifier
        if is_func
          advance_raw
          current_leading_trivia
          # Check for Class::method pattern
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            is_func = current_token.kind == :identifier
            if is_func
              advance_raw
              current_leading_trivia
              is_func = current_token.kind == :lparen
            end
          else
            is_func = current_token.kind == :lparen
          end
        end
        
        @position = saved_pos
        is_func
      end
      
      def looks_like_in_class_constructor?
        return false unless in_context?(:class)
        
        saved_pos = @position
        advance_raw if current_token.kind == :keyword_explicit
        current_leading_trivia
        
        if current_token.kind == :identifier && current_token.lexeme == current_class_name
          advance_raw
          current_leading_trivia
          if current_token.kind == :lparen
            @position = saved_pos
            return true
          end
        end
        
        @position = saved_pos
        false
      end
      
      def looks_like_out_of_line_constructor?
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        class_name = current_token.lexeme
        advance_raw
        current_leading_trivia
        
        if current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier && current_token.lexeme == class_name
            advance_raw
            current_leading_trivia
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
        end
        
        @position = saved_pos
        false
      end
      
      def skip_function_modifiers_and_check
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          advance_raw
          current_leading_trivia
        end
        
        declaration_keywords = [:keyword_class, :keyword_struct, :keyword_enum, 
                               :keyword_namespace, :keyword_using, :keyword_template, :keyword_typedef]
        !declaration_keywords.include?(current_token.kind)
      end
      
      def skip_type_specification
        advance_raw
        current_leading_trivia
        
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          advance_raw if current_token.kind == :identifier
          current_leading_trivia
        end
        
        if current_token.kind == :less
          depth = 1
          advance_raw
          while depth > 0 && !at_end?
            depth += 1 if current_token.kind == :less
            depth -= 1 if current_token.kind == :greater
            advance_raw
          end
          current_leading_trivia
        end
        
        while [:asterisk, :ampersand, :ampersand_ampersand].include?(current_token.kind)
          advance_raw
          current_leading_trivia
        end
      end
      
      def check_operator_overload_pattern(saved_pos)
        if current_token.kind == :keyword_operator
          @position = saved_pos
          return true
        end
        
        if [:asterisk, :ampersand, :ampersand_ampersand].include?(current_token.kind)
          while [:asterisk, :ampersand, :ampersand_ampersand].include?(current_token.kind)
            advance_raw
            current_leading_trivia
          end
          
          if current_token.kind == :keyword_operator
            skip_operator_symbol
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
          
          if current_token.kind == :identifier
            saved_after_ptr = @position
            advance_raw
            current_leading_trivia
            if current_token.kind == :colon_colon
              advance_raw
              current_leading_trivia
              if current_token.kind == :keyword_operator
                @position = saved_pos
                return true
              end
            end
            @position = saved_after_ptr
          end
        elsif current_token.kind == :identifier
          saved_op = @position
          advance_raw
          current_leading_trivia
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            if current_token.kind == :keyword_operator
              @position = saved_pos
              return true
            end
          end
          @position = saved_op
        end
        
        false
      end
      
      def skip_operator_symbol
        advance_raw
        current_leading_trivia
        
        operator_symbols = [:plus, :minus, :asterisk, :slash, :percent, :equals,
                           :equals_equals, :exclamation_equals, :less, :greater,
                           :less_equals, :greater_equals, :plus_plus, :minus_minus,
                           :ampersand, :pipe, :caret, :tilde, :exclamation,
                           :ampersand_ampersand, :pipe_pipe, :less_less, :greater_greater,
                           :comma, :arrow, :arrow_asterisk]
        
        if operator_symbols.include?(current_token.kind)
          advance_raw
          current_leading_trivia
        elsif current_token.kind == :lparen
          advance_raw
          advance_raw if current_token.kind == :rparen
          current_leading_trivia
        elsif current_token.kind == :lbracket
          advance_raw
          advance_raw if current_token.kind == :rbracket
          current_leading_trivia
        end
      end
      
      def parse_function_prefix_modifiers
        prefix_modifiers = "".dup
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          prefix_modifiers << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        prefix_modifiers
      end
      
      def detect_constructor_pattern
        if in_context?(:class) && current_token.kind == :identifier && 
           current_token.lexeme == current_class_name
          saved_pos = @position
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :lparen || current_token.kind == :colon_colon
            @position = saved_pos
            return [true, current_class_name]
          end
          @position = saved_pos
        end
        
        if current_token.kind == :identifier
          saved_pos = @position
          class_name = current_token.lexeme
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            
            if current_token.kind == :identifier && current_token.lexeme == class_name
              @position = saved_pos
              return [true, class_name]
            end
          end
          @position = saved_pos
        end
        
        [false, nil]
      end
      
      def parse_function_return_type
        return_type = current_token.lexeme.dup
        trivia_after = current_token.trailing_trivia
        advance_raw
        
        while current_token.kind == :colon_colon
          return_type << trivia_after << current_token.lexeme
          trivia_after = current_token.trailing_trivia
          advance_raw
          
          if current_token.kind == :identifier
            return_type << trivia_after << current_token.lexeme
            trivia_after = current_token.trailing_trivia
            advance_raw
          end
        end
        
        if current_token.kind == :less
          return_type << trivia_after << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          depth = 1
          while depth > 0 && !at_end?
            depth += 1 if current_token.kind == :less
            depth -= 1 if current_token.kind == :greater
            
            return_type << current_leading_trivia << current_token.lexeme
            trivia_after = current_token.trailing_trivia if depth == 0
            return_type << current_token.trailing_trivia unless depth == 0
            advance_raw
            break if depth == 0
          end
        end
        
        while [:asterisk, :ampersand, :ampersand_ampersand].include?(current_token.kind)
          return_type << trivia_after << current_token.lexeme
          trivia_after = current_token.trailing_trivia
          advance_raw
        end
        
        [return_type, trivia_after]
      end
      
      def parse_function_name(is_constructor, trivia_after)
        return_type_suffix = trivia_after
        name = "".dup
        
        if is_constructor
          parse_constructor_name_into(name, return_type_suffix)
        elsif current_token.kind == :identifier
          parse_identifier_function_name_into(name, trivia_after)
          return_type_suffix = trivia_after
        elsif current_token.kind == :keyword_operator
          name << current_token.lexeme
          advance_raw
          name << current_leading_trivia
          parse_operator_symbol(name)
        elsif current_token.kind == :tilde
          name << current_token.lexeme
          advance_raw
          raise ParseError, "Expected class name after ~" unless current_token.kind == :identifier
          name << current_token.lexeme
          advance_raw
        else
          raise ParseError, "Expected function name" unless current_token.kind == :identifier
          name << current_token.lexeme
          advance_raw
        end
        
        [name, return_type_suffix]
      end
      
      def parse_constructor_name_into(name, return_type_suffix)
        name << current_token.lexeme
        advance_raw
        
        scope_trivia = current_leading_trivia
        if current_token.kind == :colon_colon
          name << scope_trivia << current_token.lexeme
          advance_raw
          name << current_leading_trivia << current_token.lexeme
          advance_raw
        else
          return_type_suffix << scope_trivia if scope_trivia.length > 0
        end
      end
      
      def parse_identifier_function_name_into(name, trivia_after)
        saved_pos = @position
        class_name = current_token.lexeme
        scope_trivia = current_token.trailing_trivia
        advance_raw
        
        if current_token.kind == :colon_colon
          after_colon = current_token.trailing_trivia
          advance_raw
          
          if current_token.kind == :keyword_operator
            name << class_name << scope_trivia << "::" << after_colon << current_token.lexeme
            advance_raw
            name << current_leading_trivia
            parse_operator_symbol(name)
          else
            @position = saved_pos
            name << current_token.lexeme
            scope_trivia2 = current_token.trailing_trivia
            advance_raw
            name << scope_trivia2 << current_token.lexeme
            advance_raw
            name << current_token.trailing_trivia
            name << current_token.lexeme
            advance_raw
          end
        else
          @position = saved_pos
          name << current_token.lexeme
          advance_raw
        end
      end
      
      def parse_operator_symbol(name)
        operator_symbols = [:plus, :minus, :asterisk, :slash, :percent, :equals,
                           :equals_equals, :exclamation_equals, :less, :greater,
                           :less_equals, :greater_equals, :plus_plus, :minus_minus,
                           :ampersand, :pipe, :caret, :tilde, :exclamation,
                           :ampersand_ampersand, :pipe_pipe, :less_less, :greater_greater,
                           :comma, :arrow, :arrow_asterisk]
        
        if operator_symbols.include?(current_token.kind)
          name << current_token.lexeme
          advance_raw
        elsif current_token.kind == :lparen
          name << current_token.lexeme
          advance_raw
          name << current_token.lexeme
          advance_raw
        elsif current_token.kind == :lbracket
          name << current_token.lexeme
          advance_raw
          name << current_token.lexeme
          advance_raw
        elsif current_token.kind == :keyword_new || current_token.kind == :keyword_delete
          name << " " << current_token.lexeme
          advance_raw
          if current_token.kind == :lbracket
            name << current_token.lexeme
            advance_raw
            name << current_token.lexeme
            advance_raw
          end
        else
          while current_token.kind != :lparen && !at_end?
            name << current_token.lexeme
            advance_raw
          end
        end
      end
      
      def parse_function_parameters
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        parameters = []
        param_separators = []
        
        until current_token.kind == :rparen || at_end?
          param_text = "".dup
          paren_depth = 0
          
          loop do
            break if at_end?
            param_text << current_leading_trivia
            
            if current_token.kind == :lparen
              paren_depth += 1
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            elsif current_token.kind == :rparen
              break if paren_depth.zero?
              paren_depth -= 1
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            elsif current_token.kind == :comma && paren_depth.zero?
              break
            else
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            end
          end
          
          parameters << param_text unless param_text.empty?
          
          if current_token.kind == :comma
            param_separators << current_token.lexeme + current_token.trailing_trivia
            advance_raw
          end
        end
        
        rparen_suffix = current_leading_trivia
        after_rparen = current_token.trailing_trivia
        expect(:rparen)
        
        [parameters, param_separators, lparen_suffix, rparen_suffix, after_rparen]
      end
      
      def parse_function_modifiers_postfix(after_rparen, is_constructor)
        modifiers_text = "".dup
        
        until [:lbrace, :semicolon, :colon].include?(current_token.kind) || at_end?
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          modifiers_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        if is_constructor && current_token.kind == :colon
          modifiers_text << after_rparen unless after_rparen.empty?
          modifiers_text << current_leading_trivia  # Add leading trivia before ':'
          after_rparen = ""
          
          while ![:lbrace, :semicolon].include?(current_token.kind) && !at_end?
            modifiers_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          after_rparen = current_leading_trivia
        end
        
        [modifiers_text, after_rparen]
      end
    end
  end
end

