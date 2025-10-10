# frozen_string_literal: true

module CppAst
  module Parsers
    class StatementParser < ExpressionParser
      # Parse statement with leading_trivia
      # Returns (stmt, trailing) tuple
      def parse_statement(leading_trivia = "")
        # Check for return statement
        if current_token.kind == :identifier && current_token.lexeme == "return"
          return parse_return_statement(leading_trivia)
        end
        
        # Otherwise, expression statement
        parse_expression_statement(leading_trivia)
      end
      
      private
      
      # Parse expression statement: `expr;`
      # Returns (stmt, trailing) tuple
      def parse_expression_statement(leading_trivia)
        # Parse expression
        expr, expr_trailing = parse_expression
        
        # Consume semicolon (with any trivia before it)
        semicolon_prefix = expr_trailing + collect_trivia_string
        expect(:semicolon)
        
        # Collect trailing after semicolon
        trailing = collect_trivia_string
        
        # Create statement node
        stmt = Nodes::ExpressionStatement.new(
          leading_trivia: leading_trivia,
          expression: expr
        )
        
        [stmt, trailing]
      end
      
      # Parse return statement: `return expr;`
      # Returns (stmt, trailing) tuple
      def parse_return_statement(leading_trivia)
        # Consume 'return' keyword
        advance_raw  # skip 'return'
        
        # Collect trivia after 'return'
        keyword_suffix = collect_trivia_string
        
        # Parse expression
        expr, expr_trailing = parse_expression
        
        # Consume semicolon (with any trivia before it)
        semicolon_prefix = expr_trailing + collect_trivia_string
        expect(:semicolon)
        
        # Collect trailing after semicolon
        trailing = collect_trivia_string
        
        # Create statement node
        stmt = Nodes::ReturnStatement.new(
          leading_trivia: leading_trivia,
          expression: expr,
          keyword_suffix: keyword_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end

