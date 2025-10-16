# frozen_string_literal: true

module CppAst
  module Parsers
    # ControlFlowParser - module with control flow parsing methods
    # Handles: if, while, for, do-while, switch/case, break, continue
    #
    # This module contains all control flow statement parsing logic.
    # It is included in StatementParser to modularize the codebase.
    #
    # Methods:
    #   - parse_if_statement
    #   - parse_while_statement
    #   - parse_for_statement
    #   - parse_do_while_statement
    #   - parse_switch_statement
    #   - parse_case_clause
    #   - parse_default_clause
    #   - parse_break_statement
    #   - parse_continue_statement
    module ControlFlowParser
      # Parse if statement: `if (cond) stmt else stmt`
      # Returns (IfStatement, trailing) tuple
      def parse_if_statement(leading_trivia)
        # Consume 'if'
        if_suffix = current_token.trailing_trivia
        expect(:keyword_if)

        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)

        # Parse condition
        condition, cond_trailing = parse_expression

        # Collect trivia before ')'
        rparen_prefix = cond_trailing

        # Consume ')'
        then_leading = current_token.trailing_trivia
        expect(:rparen)

        # Parse then statement
        then_stmt, then_trailing = parse_statement(then_leading)
        
        # Check for else clause
        else_stmt = nil
        else_prefix = ""
        else_suffix = ""
        
        potential_else_prefix = then_trailing + current_leading_trivia
        if current_token.kind == :keyword_else
          else_prefix = potential_else_prefix
          else_suffix = current_token.trailing_trivia
          advance_raw  # consume 'else'
          
          # Parse else statement
          else_stmt, then_trailing = parse_statement("")
        end
        # Note: if no else, then_trailing stays as-is (don't add current_leading_trivia)
        
        stmt = Nodes::IfStatement.new(
          leading_trivia: leading_trivia,
          condition: condition,
          then_statement: then_stmt,
          else_statement: else_stmt,
          if_suffix: if_suffix,
          condition_lparen_suffix: lparen_suffix,
          condition_rparen_suffix: rparen_prefix,
          else_prefix: else_prefix,
          else_suffix: else_suffix
        )
        
        [stmt, then_trailing]
      end
      
      # Parse while statement: `while (cond) stmt`
      # Returns (WhileStatement, trailing) tuple
      def parse_while_statement(leading_trivia)
        # Consume 'while'
        while_suffix = current_token.trailing_trivia
        expect(:keyword_while)

        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)

        # Parse condition
        condition, cond_trailing = parse_expression

        # Collect trivia before ')'
        rparen_prefix = cond_trailing

        # Consume ')'
        body_leading = current_token.trailing_trivia
        expect(:rparen)

        # Parse body
        body, trailing = parse_statement(body_leading)
        
        stmt = Nodes::WhileStatement.new(
          leading_trivia: leading_trivia,
          condition: condition,
          body: body,
          while_suffix: while_suffix,
          condition_lparen_suffix: lparen_suffix,
          condition_rparen_suffix: rparen_prefix
        )
        
        [stmt, trailing]
      end
      
      # Parse do-while statement: `do stmt while (cond);`
      # Returns (DoWhileStatement, trailing) tuple
      def parse_do_while_statement(leading_trivia)
        # Consume 'do'
        do_suffix = current_token.trailing_trivia
        expect(:keyword_do)
        
        # Parse body
        body, body_trailing = parse_statement("")
        
        # Collect trivia before 'while'
        while_prefix = body_trailing + current_leading_trivia
        
        # Consume 'while'
        while_suffix = current_token.trailing_trivia
        expect(:keyword_while)
        
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse condition
        condition, cond_trailing = parse_expression

        # Collect trivia before ')'
        rparen_prefix = cond_trailing

        # Consume ')'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rparen)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::DoWhileStatement.new(
          leading_trivia: leading_trivia,
          body: body,
          condition: condition,
          do_suffix: do_suffix,
          while_prefix: while_prefix,
          while_suffix: while_suffix,
          condition_lparen_suffix: lparen_suffix,
          condition_rparen_suffix: rparen_prefix
        )
        
        [stmt, trailing]
      end
      
      # Parse for statement: `for (init; cond; inc) stmt`
      # Returns (ForStatement, trailing) tuple
      def parse_for_statement(leading_trivia)
        # Consume 'for'
        for_suffix = current_token.trailing_trivia
        expect(:keyword_for)
        
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Try to parse as range-based for first
        # Range-based for has pattern: for (decl : range)
        # Classic for has pattern: for (init; cond; inc)
        
        # Look ahead to determine which type
        saved_pos = @position
        depth = 0
        found_colon = false
        found_semicolon = false
        
        while !at_end? && depth >= 0
          case current_token.kind
          when :lparen, :lbracket
            depth += 1
          when :rparen
            break if depth == 0
            depth -= 1
          when :rbracket
            depth -= 1
          when :colon
            found_colon = true if depth == 0
            break if depth == 0
          when :semicolon
            found_semicolon = true if depth == 0
            break if depth == 0
          end
          advance_raw
        end
        
        @position = saved_pos
        
        if found_colon && !found_semicolon
          parse_range_based_for(leading_trivia, for_suffix, lparen_suffix)
        else
          parse_classic_for(leading_trivia, for_suffix, lparen_suffix)
        end
      end
      
      def parse_range_based_for(leading_trivia, for_suffix, lparen_suffix)
        # Collect declaration as text (everything until ':')
        decl_text = "".dup
        
        until current_token.kind == :colon || at_end?
          decl_text << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        # Consume ':'
        colon_suffix = current_token.trailing_trivia
        expect(:colon)
        
        # Parse range expression
        range, range_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = range_trailing + current_leading_trivia
        
        # Consume ')'
        body_leading = current_token.trailing_trivia
        expect(:rparen)

        # Parse body
        body, trailing = parse_statement(body_leading)
        
        # Create node with range-based format
        stmt = Nodes::ForStatement.new(
          leading_trivia: leading_trivia,
          init: Nodes::Identifier.new(name: decl_text),  # Store as text
          condition: range,
          increment: nil,
          body: body,
          for_suffix: for_suffix,
          lparen_suffix: lparen_suffix,
          init_trailing: ":#{colon_suffix}",  # Store colon with suffix
          condition_trailing: "",
          rparen_suffix: rparen_prefix
        )
        
        [stmt, trailing]
      end
      
      def parse_classic_for(leading_trivia, for_suffix, lparen_suffix)
        # Parse init (can be empty)
        init = nil
        init_trailing = ""
        unless current_token.kind == :semicolon
          init, init_trailing = parse_expression
        end

        # Collect trivia before first ';'
        _semi1_prefix = init_trailing + current_leading_trivia

        # Consume first ';'
        after_semi1 = current_token.trailing_trivia
        expect(:semicolon)

        # Parse condition (can be empty)
        condition = nil
        condition_trailing = ""
        unless current_token.kind == :semicolon
          condition, condition_trailing = parse_expression
        end

        # Collect trivia before second ';'
        _semi2_prefix = condition_trailing + current_leading_trivia

        # Consume second ';'
        after_semi2 = current_token.trailing_trivia
        expect(:semicolon)

        # Parse increment (can be empty)
        increment = nil
        rparen_prefix = ""
        unless current_token.kind == :rparen
          increment, inc_trailing = parse_expression
          rparen_prefix = inc_trailing
        end

        # Consume ')'
        body_leading = current_token.trailing_trivia
        expect(:rparen)

        # Parse body
        body, trailing = parse_statement(body_leading)
        
        stmt = Nodes::ForStatement.new(
          leading_trivia: leading_trivia,
          init: init,
          condition: condition,
          increment: increment,
          body: body,
          for_suffix: for_suffix,
          lparen_suffix: lparen_suffix,
          init_trailing: after_semi1,
          condition_trailing: after_semi2,
          rparen_suffix: rparen_prefix
        )
        
        [stmt, trailing]
      end
      
      # Parse switch statement: `switch (expr) { case 1: ...; default: ...; }`
      # Returns (SwitchStatement, trailing) tuple
      def parse_switch_statement(leading_trivia)
        # Consume 'switch'
        switch_suffix = current_token.trailing_trivia
        expect(:keyword_switch)
        
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse expression
        expression, expr_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = expr_trailing + current_leading_trivia
        
        # Consume ')'
        lbrace_prefix = current_token.trailing_trivia
        expect(:rparen)
        
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Parse case clauses
        cases = []
        case_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          case_leading += current_leading_trivia
          
          if current_token.kind == :keyword_case
            cases << parse_case_clause(case_leading)
            case_leading = ""
          elsif current_token.kind == :keyword_default
            cases << parse_default_clause(case_leading)
            case_leading = ""
          else
            # Statement inside case - collect as trivia for now
            # In real implementation, would need better handling
            break
          end
        end
        
        # Collect trivia before '}'
        rbrace_prefix = current_leading_trivia
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trailing
        trailing = current_leading_trivia
        
        stmt = Nodes::SwitchStatement.new(
          leading_trivia: leading_trivia,
          expression: expression,
          cases: cases,
          switch_suffix: switch_suffix,
          lparen_suffix: lparen_suffix,
          rparen_suffix: rparen_prefix,
          lbrace_prefix: lbrace_prefix,
          lbrace_suffix: lbrace_suffix,
          rbrace_prefix: rbrace_prefix
        )
        
        [stmt, trailing]
      end
      
      # Parse case clause: `case value: statements`
      def parse_case_clause(leading_trivia)
        # Consume 'case'
        case_suffix = current_token.trailing_trivia
        expect(:keyword_case)
        
        # Parse value
        value, value_trailing = parse_expression
        
        # Collect trivia before ':'
        _colon_prefix = value_trailing + current_leading_trivia
        
        # Consume ':'
        colon_suffix = current_token.trailing_trivia
        expect(:colon)
        
        # Parse statements until next case/default/rbrace
        statements = []
        statement_trailings = []
        stmt_leading = ""
        
        loop do
          break if [:keyword_case, :keyword_default, :rbrace].include?(current_token.kind)
          break if at_end?
          
          stmt, trailing = parse_statement(stmt_leading)
          statements << stmt
          statement_trailings << trailing
          stmt_leading = ""
        end
        
        Nodes::CaseClause.new(
          leading_trivia: leading_trivia,
          value: value,
          statements: statements,
          statement_trailings: statement_trailings,
          case_suffix: case_suffix,
          colon_suffix: colon_suffix
        )
      end
      
      # Parse default clause: `default: statements`
      def parse_default_clause(leading_trivia)
        # Consume 'default'
        _colon_prefix = current_token.trailing_trivia
        expect(:keyword_default)
        
        # Consume ':'
        colon_suffix = current_token.trailing_trivia
        expect(:colon)
        
        # Parse statements until next case/default/rbrace
        statements = []
        statement_trailings = []
        stmt_leading = ""
        
        loop do
          break if [:keyword_case, :keyword_default, :rbrace].include?(current_token.kind)
          break if at_end?
          
          stmt, trailing = parse_statement(stmt_leading)
          statements << stmt
          statement_trailings << trailing
          stmt_leading = ""
        end
        
        Nodes::DefaultClause.new(
          leading_trivia: leading_trivia,
          statements: statements,
          statement_trailings: statement_trailings,
          colon_suffix: colon_suffix
        )
      end
      
      # Parse break statement: `break;`
      # Returns (BreakStatement, trailing) tuple
      def parse_break_statement(leading_trivia)
        # Consume 'break'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:keyword_break)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::BreakStatement.new(leading_trivia: leading_trivia)
        
        [stmt, trailing]
      end
      
      # Parse continue statement: `continue;`
      # Returns (ContinueStatement, trailing) tuple
      def parse_continue_statement(leading_trivia)
        # Consume 'continue'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:keyword_continue)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::ContinueStatement.new(leading_trivia: leading_trivia)
        
        [stmt, trailing]
      end
    end
  end
end

