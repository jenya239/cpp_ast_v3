# frozen_string_literal: true

module MLC
  module Parser
    # StatementParser
    # Statement parsing - variable declarations, assignments, blocks
    # Auto-extracted from parser.rb during refactoring
    module StatementParser
    def ensure_block_has_result(block, require_value: true)
      return unless require_value
      return if block.stmts.last.is_a?(AST::ExprStmt)

      raise "Block must end with an expression"
    end

    def parse_assignment_statement
      target_token = consume(:IDENTIFIER)
      target_name = target_token.value
      consume(:EQUAL)
      value = parse_expression
      consume(:SEMICOLON) if current.type == :SEMICOLON

      target = attach_origin(AST::VarRef.new(name: target_name), target_token)
      with_origin(target_token) { AST::Assignment.new(target: target, value: value) }
    end

    def parse_block_expression
      lbrace_token = consume(:LBRACE)
      statements = []

      until current.type == :RBRACE
        statements << parse_statement
      end

      consume(:RBRACE)
      with_origin(lbrace_token) { AST::Block.new(stmts: statements) }
    end

    def parse_return_statement
      return_token = consume(:RETURN)
      expr = nil
      unless current.type == :SEMICOLON || current.type == :RBRACE || current.type == :EOF
        expr = parse_expression
      end
      consume(:SEMICOLON) if current.type == :SEMICOLON

      with_origin(return_token) { AST::Return.new(expr: expr) }
    end

    def parse_statement
      case current.type
      when :LET
        parse_variable_decl_statement
      when :RETURN
        parse_return_statement
      when :BREAK
        break_token = consume(:BREAK)
        consume(:SEMICOLON) if current.type == :SEMICOLON
        attach_origin(AST::Break.new, break_token)
      when :CONTINUE
        continue_token = consume(:CONTINUE)
        consume(:SEMICOLON) if current.type == :SEMICOLON
        attach_origin(AST::Continue.new, continue_token)
      when :IDENTIFIER
        if peek && peek.type == :EQUAL
          parse_assignment_statement
        else
          expr = parse_expression
          consume(:SEMICOLON) if current.type == :SEMICOLON
          attach_origin(AST::ExprStmt.new(expr: expr), expr.origin)
        end
      when :LBRACE
        parse_block_expression
      else
        expr = parse_expression
        consume(:SEMICOLON) if current.type == :SEMICOLON
        attach_origin(AST::ExprStmt.new(expr: expr), expr.origin)
      end
    end

    def parse_statement_sequence(statements)
      loop do
        break if current.type == :EOF || current.type == :RBRACE

        stmt = parse_statement
        statements << stmt

        if current.type == :SEMICOLON
          consume(:SEMICOLON)
          next
        end
      end

      block = AST::Block.new(stmts: statements)
      first_origin = statements.first&.origin
      attach_origin(block, first_origin)
    end

    def parse_variable_decl_statement
      consume(:LET)
      mutable = false
      if current.type == :MUT
        consume(:MUT)
        mutable = true
      end

      name_token = consume(:IDENTIFIER)
      name = name_token.value

      # Optional type annotation: let x: Type = value
      type_annotation = nil
      if current.type == :COLON
        consume(:COLON)
        type_annotation = parse_type
      end

      consume(:EQUAL)
      value = parse_expression
      consume(:SEMICOLON) if current.type == :SEMICOLON

      with_origin(name_token) { AST::VariableDecl.new(name: name, value: value, mutable: mutable, type: type_annotation) }
    end

    end
  end
end
