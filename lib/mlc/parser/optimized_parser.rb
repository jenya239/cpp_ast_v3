# frozen_string_literal: true

require_relative "parser"

module MLC
  module Parser
    # Optimized parser with memoization and performance improvements
    class OptimizedParser < Parser
      def initialize(source, filename: nil)
        super(source, filename: filename)
        @memo = {}
        @parse_cache = {}
        @expression_cache = {}
      end
      
      # Memoized expression parsing
      def parse_expression
        key = "#{@pos}_expression"
        return @memo[key] if @memo[key]
        
        result = parse_expression_impl
        @memo[key] = result
        result
      end
      
      private
      
      def parse_expression_impl
        # Original expression parsing logic
        case current.type
        when :INTEGER
          parse_integer
        when :FLOAT
          parse_float
        when :STRING
          parse_string
        when :IDENTIFIER
          parse_identifier_expression
        when :INT_LITERAL
          parse_integer_literal
        when :FLOAT_LITERAL
          parse_float_literal
        when :LPAREN
          parse_parenthesized_expression
        when :LBRACKET
          parse_array_literal
        when :LBRACE
          parse_record_literal
        when :IF
          parse_if_expression
        when :MATCH
          parse_match_expression
        when :LAMBDA
          parse_lambda
        when :LET
          parse_let_expression
        when :FOR
          parse_for_loop
        when :WHILE
          parse_while_loop
        else
          raise ParseError, "Unexpected token: #{current.type}"
        end
      end
      
      # Binary operation parsing (caching removed due to left operand dependency)
      def parse_binary_expression(left, min_precedence = 0)
        while current.type == :OPERATOR && precedence(current.value) >= min_precedence
          op = current.value
          consume(:OPERATOR)
          right = parse_primary_expression
          
          while current.type == :OPERATOR && 
                precedence(current.value) > precedence(op)
            right = parse_binary_expression(right, precedence(current.value))
          end
          
          left = AST::BinaryOp.new(left: left, op: op, right: right)
        end
        
        left
      end
      
      # Optimized token consumption with lookahead
      def consume(expected_type)
        if current.type == expected_type
          @last_token = current
          @pos += 1
          @last_token
        else
          raise ParseError, "Expected #{expected_type}, got #{current.type}"
        end
      end
      
      # Batch token processing for better performance
      def consume_multiple(*types)
        results = []
        types.each do |type|
          if current.type == type
            results << consume(type)
          else
            break
          end
        end
        results
      end
      
      # Optimized lookahead
      def lookahead(n = 1)
        return nil if @pos + n >= @tokens.length
        @tokens[@pos + n]
      end
      
      # Clear cache when position changes significantly
      def clear_cache_if_needed
        if @pos > 0 && @pos % 100 == 0
          @memo.clear
          @expression_cache.clear
        end
      end
      
      def parse_integer_literal
        value = current.value
        consume(:INT_LITERAL)
        MLC::AST::IntLit.new(value: value)
      end
      
      def parse_float_literal
        value = current.value
        consume(:FLOAT_LITERAL)
        MLC::AST::FloatLit.new(value: value)
      end
      
      def parse_identifier_expression
        name = current.value
        consume(:IDENTIFIER)
        MLC::AST::VarRef.new(name: name)
      end
    end
  end
end
