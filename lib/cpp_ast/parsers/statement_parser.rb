# frozen_string_literal: true

module CppAst
  module Parsers
    # StatementParser - main statement parsing class
    # Combines functionality from multiple modules:
    #   - TypeParser - type parsing utilities
    #   - ControlFlowParser - if/while/for/switch parsing (future)
    #   - DeclarationParser - namespace/class/function parsing (future)
    #
    # Current size: ~1600 lines
    # TODO: Extract methods into ControlFlowParser and DeclarationParser modules
    class StatementParser < ExpressionParser
      include TypeParser
      include ControlFlowParser
      include DeclarationParser
      # Parse statement with leading_trivia
      # Returns (stmt, trailing) tuple
      def parse_statement(leading_trivia = "")
        # Check for keywords
        case current_token.kind
        when :keyword_return
          parse_return_statement(leading_trivia)
        when :lbrace
          parse_block_statement(leading_trivia)
        when :keyword_if
          parse_if_statement(leading_trivia)
        when :keyword_while
          parse_while_statement(leading_trivia)
        when :keyword_for
          parse_for_statement(leading_trivia)
        when :keyword_do
          parse_do_while_statement(leading_trivia)
        when :keyword_switch
          parse_switch_statement(leading_trivia)
        when :keyword_break
          parse_break_statement(leading_trivia)
        when :keyword_continue
          parse_continue_statement(leading_trivia)
        when :keyword_namespace
          parse_namespace_declaration(leading_trivia)
        when :keyword_class
          parse_class_declaration(leading_trivia)
        when :keyword_struct
          parse_struct_declaration(leading_trivia)
        when :keyword_using
          parse_using_declaration(leading_trivia)
        when :keyword_enum
          parse_enum_declaration(leading_trivia)
        when :keyword_template
          parse_template_declaration(leading_trivia)
        else
          # Distinguish between declarations and expressions
          if looks_like_function_declaration?
            parse_function_declaration(leading_trivia)
          elsif looks_like_declaration?
            parse_variable_declaration(leading_trivia)
          else
            # Default: expression statement
            parse_expression_statement(leading_trivia)
          end
        end
      end
      
      private
      
      # Parse expression statement: `expr;`
      # Returns (stmt, trailing) tuple
      def parse_expression_statement(leading_trivia)
        # Parse expression
        expr, expr_trailing = parse_expression
        
        # Consume semicolon (with any trivia before it)
        _semicolon_prefix = expr_trailing + current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
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
        keyword_suffix = current_token.trailing_trivia
        advance_raw  # skip 'return'
        
        # Parse expression
        expr, expr_trailing = parse_expression
        
        # Consume semicolon (with any trivia before it)
        _semicolon_prefix = expr_trailing + current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        # Create statement node
        stmt = Nodes::ReturnStatement.new(
          leading_trivia: leading_trivia,
          expression: expr,
          keyword_suffix: keyword_suffix
        )
        
        [stmt, trailing]
      end
      
      # Parse block statement: `{ stmt1; stmt2; }`
      # Returns (BlockStatement, trailing) tuple
      def parse_block_statement(leading_trivia)
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Parse statements until '}'
        statements = []
        statement_trailings = []
        
        until current_token.kind == :rbrace || at_end?
          stmt_leading = current_leading_trivia
          stmt, trailing = parse_statement(stmt_leading)
          statements << stmt
          statement_trailings << trailing
        end
        
        # Collect trivia before '}'
        rbrace_prefix = current_leading_trivia
        
        # Consume '}'
        trailing = current_token.trailing_trivia
        expect(:rbrace)
        
        stmt = Nodes::BlockStatement.new(
          leading_trivia: leading_trivia,
          statements: statements,
          statement_trailings: statement_trailings,
          lbrace_suffix: lbrace_suffix,
          rbrace_prefix: rbrace_prefix
        )
        
        [stmt, trailing]
      end
    end
  end
end