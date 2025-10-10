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
      # Lower number = lower precedence
      OPERATOR_INFO = {
        equals: { precedence: 1, right_assoc: true },
        plus: { precedence: 10, right_assoc: false },
        minus: { precedence: 10, right_assoc: false },
        asterisk: { precedence: 20, right_assoc: false },
        slash: { precedence: 20, right_assoc: false },
      }.freeze
      
      def operator_info(kind)
        OPERATOR_INFO[kind]
      end
      
      # Pratt parser for binary expressions
      # Returns (expr, trailing) tuple
      def parse_binary_expression(min_precedence)
        # Parse left side (primary expression)
        left, left_trailing = parse_primary
        
        loop do
          # Collect trivia BEFORE operator
          operator_prefix = left_trailing + collect_trivia_string
          
          # Check if current token is operator
          info = operator_info(current_token&.kind)
          break unless info && info[:precedence] >= min_precedence
          
          # Consume operator
          operator = current_token.lexeme
          advance_raw
          
          # Collect trivia AFTER operator
          operator_suffix = collect_trivia_string
          
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
      
      # Parse primary expression (identifier, number, parenthesized, etc)
      # Returns (expr, trailing) tuple
      def parse_primary
        case current_token.kind
        when :identifier
          name = current_token.lexeme
          advance_raw
          trailing = collect_trivia_string
          [Nodes::Identifier.new(name: name), trailing]
          
        when :number
          value = current_token.lexeme
          advance_raw
          trailing = collect_trivia_string
          [Nodes::NumberLiteral.new(value: value), trailing]
          
        else
          raise ParseError, 
            "Unexpected token in expression: #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
      end
    end
  end
end

