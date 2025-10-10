# frozen_string_literal: true

module CppAst
  module Parsers
    class ExpressionParser < BaseParser
      # Parse expression and return (expr, trailing) tuple
      def parse_expression
        parse_binary_expression(0)
      end
      
      private
      
      # Operator precedence table
      # Lower number = lower precedence (C++ standard precedence)
      OPERATOR_INFO = {
        # Assignment (right-associative, precedence 1)
        equals: { precedence: 1, right_assoc: true },
        plus_equals: { precedence: 1, right_assoc: true },
        minus_equals: { precedence: 1, right_assoc: true },
        asterisk_equals: { precedence: 1, right_assoc: true },
        slash_equals: { precedence: 1, right_assoc: true },
        
        # Logical OR (precedence 3)
        pipe_pipe: { precedence: 3, right_assoc: false },
        
        # Logical AND (precedence 4)
        ampersand_ampersand: { precedence: 4, right_assoc: false },
        
        # Bitwise OR (precedence 5)
        pipe: { precedence: 5, right_assoc: false },
        
        # Bitwise XOR (precedence 6)
        caret: { precedence: 6, right_assoc: false },
        
        # Bitwise AND (precedence 7)
        ampersand: { precedence: 7, right_assoc: false },
        
        # Equality (precedence 8)
        equals_equals: { precedence: 8, right_assoc: false },
        exclamation_equals: { precedence: 8, right_assoc: false },
        
        # Relational (precedence 9)
        less: { precedence: 9, right_assoc: false },
        greater: { precedence: 9, right_assoc: false },
        less_equals: { precedence: 9, right_assoc: false },
        greater_equals: { precedence: 9, right_assoc: false },
        
        # Shift (precedence 10)
        less_less: { precedence: 10, right_assoc: false },
        greater_greater: { precedence: 10, right_assoc: false },
        
        # Additive (precedence 11)
        plus: { precedence: 11, right_assoc: false },
        minus: { precedence: 11, right_assoc: false },
        
        # Multiplicative (precedence 12)
        asterisk: { precedence: 12, right_assoc: false },
        slash: { precedence: 12, right_assoc: false },
        percent: { precedence: 12, right_assoc: false },
      }.freeze
      
      def operator_info(kind)
        OPERATOR_INFO[kind]
      end
      
      # Pratt parser for binary expressions
      # Returns (expr, trailing) tuple
      def parse_binary_expression(min_precedence)
        # Parse left side (unary or primary expression)
        left, left_trailing = parse_unary
        
        loop do
          # Collect trivia BEFORE operator
          operator_prefix = left_trailing + current_leading_trivia
          
          # Check for ternary operator (special case)
          if current_token&.kind == :question && 2 >= min_precedence
            left, left_trailing = parse_ternary(left, operator_prefix)
            next
          end
          
          # Check if current token is operator
          info = operator_info(current_token&.kind)
          break unless info && info[:precedence] >= min_precedence
          
          # Consume operator
          operator = current_token.lexeme
          operator_suffix = current_token.trailing_trivia  # Get trailing BEFORE advance
          advance_raw
          
          # Parse right side with appropriate precedence
          # For right-associative operators, use same precedence
          # For left-associative, use precedence + 1
          next_precedence = info[:right_assoc] ? info[:precedence] : info[:precedence] + 1
          right, right_trailing = parse_binary_expression(next_precedence)
          
          # Build binary expression node
          left = Nodes::BinaryExpression.new(
            left: left,
            operator: operator,
            right: right,
            operator_prefix: operator_prefix,
            operator_suffix: operator_suffix
          )
          left_trailing = right_trailing
        end
        
        # If we didn't consume operator_prefix, it becomes trailing
        [left, left_trailing]
      end
      
      # Parse ternary expression: condition ? true_expr : false_expr
      # Returns (TernaryExpression, trailing) tuple
      def parse_ternary(condition, question_prefix)
        # Consume '?'
        question_suffix = current_token.trailing_trivia
        expect(:question)
        
        # Parse true expression
        true_expr, true_trailing = parse_expression
        
        # Collect trivia before ':'
        colon_prefix = true_trailing + current_leading_trivia
        
        # Consume ':'
        colon_suffix = current_token.trailing_trivia
        expect(:colon)
        
        # Parse false expression (with ternary precedence for right-associativity)
        false_expr, false_trailing = parse_binary_expression(2)
        
        # Create ternary expression
        expr = Nodes::TernaryExpression.new(
          condition: condition,
          true_expression: true_expr,
          false_expression: false_expr,
          question_prefix: question_prefix,
          question_suffix: question_suffix,
          colon_prefix: colon_prefix,
          colon_suffix: colon_suffix
        )
        
        [expr, false_trailing]
      end
      
      # Parse unary expression (prefix operators) or primary
      # Returns (expr, trailing) tuple
      def parse_unary
        # Check for prefix unary operators
        case current_token.kind
        when :exclamation, :tilde, :minus, :plus, :asterisk, :ampersand, :plus_plus, :minus_minus
          operator = current_token.lexeme
          operator_suffix = current_token.trailing_trivia
          advance_raw
          
          # Parse operand (recursively handle chained unary operators)
          operand, operand_trailing = parse_unary
          
          # Create unary expression
          expr = Nodes::UnaryExpression.new(
            operator: operator,
            operand: operand,
            operator_suffix: operator_suffix,
            prefix: true
          )
          
          [expr, operand_trailing]
        else
          # No prefix operator, parse postfix
          parse_postfix
        end
      end
      
      # Parse postfix operators (++, --, function calls)
      # Returns (expr, trailing) tuple
      def parse_postfix
        # Parse primary first
        expr, trailing = parse_primary
        
        # Check for postfix operators
        loop do
          # Collect trivia before potential postfix operator
          operator_prefix = trailing + current_leading_trivia
          
          case current_token.kind
          when :plus_plus, :minus_minus
            operator = current_token.lexeme
            trailing = current_token.trailing_trivia
            advance_raw
            
            # Postfix operators don't have suffix trivia
            # (trivia after them belongs to the whole expression)
            expr = Nodes::UnaryExpression.new(
              operator: operator,
              operand: expr,
              prefix: false
            )
            
          when :lparen
            # Function call
            expr, trailing = parse_function_call(expr, operator_prefix)
            
          when :dot, :arrow, :colon_colon
            # Member access
            operator = current_token.lexeme
            operator_suffix = current_token.trailing_trivia
            advance_raw
            
            # Parse member name (identifier)
            unless current_token.kind == :identifier
              raise ParseError, "Expected identifier after #{operator}"
            end
            
            member = Nodes::Identifier.new(name: current_token.lexeme)
            trailing = current_token.trailing_trivia
            advance_raw
            
            # Create member access expression
            expr = Nodes::MemberAccessExpression.new(
              object: expr,
              operator: operator,
              member: member,
              operator_prefix: operator_prefix,
              operator_suffix: operator_suffix
            )
            
          when :lbracket
            # Array subscript
            expr, trailing = parse_array_subscript(expr, operator_prefix)
            
          when :lbrace
            # Brace initialization: Type{args...}
            expr, trailing = parse_brace_initializer(expr, operator_prefix)
            
          else
            # No more postfix operators
            # Return the operator_prefix as part of trailing
            return [expr, operator_prefix]
          end
        end
      end
      
      # Parse array subscript: array[index]
      # Returns (ArraySubscriptExpression, trailing) tuple
      def parse_array_subscript(array, lbracket_prefix)
        # Consume '['
        expect(:lbracket)
        
        # Collect trivia after '['
        lbracket_suffix = current_leading_trivia
        
        # Parse index expression
        index, index_trailing = parse_expression
        
        # Collect trivia before ']'
        rbracket_prefix = index_trailing + current_leading_trivia
        
        # Consume ']'
        trailing = current_token.trailing_trivia
        expect(:rbracket)
        
        # Create array subscript expression
        expr = Nodes::ArraySubscriptExpression.new(
          array: array,
          index: index,
          lbracket_suffix: lbracket_suffix,
          rbracket_prefix: rbracket_prefix
        )
        
        [expr, trailing]
      end
      
      # Parse brace initializer: Type{arg1, arg2, ...}
      # Returns (FunctionCallExpression, trailing) tuple
      # Note: We reuse FunctionCallExpression node for brace initializers
      def parse_brace_initializer(callee, lbrace_prefix)
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = current_leading_trivia
        
        # Parse arguments (same as function call)
        arguments = []
        argument_separators = []
        rbrace_prefix = ""
        
        # Check for empty initializer list
        unless current_token.kind == :rbrace
          loop do
            # Parse argument expression
            arg, arg_trailing = parse_expression
            arguments << arg
            
            # Collect trivia before comma or '}'
            separator_prefix = arg_trailing + current_leading_trivia
            
            # Check for comma (more arguments) or '}' (done)
            if current_token.kind == :comma
              separator_suffix = current_token.trailing_trivia
              advance_raw
              argument_separators << "#{separator_prefix},#{separator_suffix}"
            else
              # No more arguments, the separator_prefix becomes rbrace_prefix
              rbrace_prefix = separator_prefix
              break
            end
          end
        end
        
        # Consume '}'
        trailing = current_token.trailing_trivia
        expect(:rbrace)
        
        # Create function call expression (reusing for brace init)
        # Store lbrace/rbrace info in lparen/rparen fields
        expr = Nodes::BraceInitializerExpression.new(
          type: callee,
          arguments: arguments,
          argument_separators: argument_separators,
          lbrace_prefix: lbrace_prefix,
          lbrace_suffix: lbrace_suffix,
          rbrace_prefix: rbrace_prefix
        )
        
        [expr, trailing]
      end
      
      # Parse function call: callee(arg1, arg2, ...)
      # Returns (FunctionCallExpression, trailing) tuple
      def parse_function_call(callee, lparen_prefix)
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse arguments
        arguments = []
        argument_separators = []
        rparen_prefix = ""
        
        # Check for empty argument list
        unless current_token.kind == :rparen
          loop do
            # Parse argument expression
            arg, arg_trailing = parse_expression
            arguments << arg
            
            # Collect trivia before comma or ')'
            separator_prefix = arg_trailing + current_leading_trivia
            
            # Check for comma (more arguments) or ')' (done)
            if current_token.kind == :comma
              separator_suffix = current_token.trailing_trivia
              advance_raw
              # Include leading trivia of next argument (for multiline formatting)
              next_arg_leading = current_leading_trivia
              argument_separators << "#{separator_prefix},#{separator_suffix}#{next_arg_leading}"
              
              # Clear leading_trivia to avoid duplication in arg.to_source
              current_token.leading_trivia = ""
            else
              # No more arguments, the separator_prefix becomes rparen_prefix
              rparen_prefix = separator_prefix
              break
            end
          end
        end
        
        # Consume ')'
        trailing = current_token.trailing_trivia
        expect(:rparen)
        
        # Create function call expression
        expr = Nodes::FunctionCallExpression.new(
          callee: callee,
          arguments: arguments,
          argument_separators: argument_separators,
          lparen_suffix: lparen_suffix,
          rparen_prefix: rparen_prefix
        )
        
        [expr, trailing]
      end
      
      # Parse primary expression (identifier, number, string, char, parenthesized, etc)
      # Returns (expr, trailing) tuple
      def parse_primary
        case current_token.kind
        when :identifier
          name = current_token.lexeme
          trailing = current_token.trailing_trivia
          advance_raw
          [Nodes::Identifier.new(name: name), trailing]
          
        when :number
          value = current_token.lexeme
          trailing = current_token.trailing_trivia
          advance_raw
          [Nodes::NumberLiteral.new(value: value), trailing]
          
        when :string
          value = current_token.lexeme
          trailing = current_token.trailing_trivia
          advance_raw
          [Nodes::StringLiteral.new(value: value), trailing]
          
        when :char
          value = current_token.lexeme
          trailing = current_token.trailing_trivia
          advance_raw
          [Nodes::CharLiteral.new(value: value), trailing]
          
        when :keyword_true, :keyword_false, :keyword_nullptr, :keyword_this
          value = current_token.lexeme
          trailing = current_token.trailing_trivia
          advance_raw
          [Nodes::Identifier.new(name: value), trailing]  # For now, treat as identifiers
          
        when :lparen
          parse_parenthesized_expression
          
        when :lbracket
          parse_lambda_expression
          
        else
          raise ParseError, 
            "Unexpected token in expression: #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
      end
      
      # Parse parenthesized expression: (expr)
      # Returns (ParenthesizedExpression, trailing) tuple
      def parse_parenthesized_expression
        # Consume '('
        open_paren_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse inner expression
        inner_expr, inner_trailing = parse_expression
        
        # Collect trivia before ')'
        close_paren_prefix = inner_trailing + current_leading_trivia
        
        # Consume ')'
        trailing = current_token.trailing_trivia
        expect(:rparen)
        
        # Create parenthesized expression node
        expr = Nodes::ParenthesizedExpression.new(
          expression: inner_expr,
          open_paren_suffix: open_paren_suffix,
          close_paren_prefix: close_paren_prefix
        )
        
        [expr, trailing]
      end
      
      # Parse lambda expression: [capture](params) { body }
      # Returns (LambdaExpression, trailing) tuple
      def parse_lambda_expression
        # Consume '['
        expect(:lbracket)
        
        # Collect capture list (simplified - just raw text)
        capture_text = "".dup
        until current_token.kind == :rbracket || at_end?
          capture_text << current_token.lexeme
          advance_raw
        end
        
        # Consume ']'
        capture_suffix = current_token.trailing_trivia
        expect(:rbracket)
        
        # Consume '('
        expect(:lparen)
        
        # Collect parameters (simplified - just raw text)
        params_text = "".dup
        paren_depth = 1
        until paren_depth.zero? || at_end?
          if current_token.kind == :lparen
            paren_depth += 1
          elsif current_token.kind == :rparen
            paren_depth -= 1
            break if paren_depth.zero?
          end
          
          params_text << current_token.lexeme
          advance_raw
        end
        
        # Consume ')'
        params_suffix = current_token.trailing_trivia
        expect(:rparen)
        
        # Optional: mutable, constexpr, etc.
        specifiers_text = "".dup
        until current_token.kind == :lbrace || at_end?
          specifiers_text << current_token.lexeme
          advance_raw
        end
        
        # Parse body (block statement)
        body_text = "".dup
        if current_token.kind == :lbrace
          expect(:lbrace)
          
          brace_depth = 1
          until brace_depth.zero? || at_end?
            if current_token.kind == :lbrace
              brace_depth += 1
            elsif current_token.kind == :rbrace
              brace_depth -= 1
              break if brace_depth.zero?
            end
            
            body_text << current_token.lexeme
            advance_raw
          end
          
          # Consume '}'
          expect(:rbrace)
        end
        
        trailing = current_leading_trivia
        
        expr = Nodes::LambdaExpression.new(
          capture: capture_text,
          parameters: params_text,
          specifiers: specifiers_text,
          body: body_text,
          capture_suffix: capture_suffix,
          params_suffix: params_suffix
        )
        
        [expr, trailing]
      end
    end
  end
end