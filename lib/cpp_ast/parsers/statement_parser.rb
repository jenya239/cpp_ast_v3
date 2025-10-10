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
        _semicolon_prefix = expr_trailing + collect_trivia_string
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
        _semicolon_prefix = expr_trailing + collect_trivia_string
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
      
      # Parse block statement: `{ stmt1; stmt2; }`
      # Returns (BlockStatement, trailing) tuple
      def parse_block_statement(leading_trivia)
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = collect_trivia_string
        
        # Parse statements until '}'
        statements = []
        statement_trailings = []
        
        stmt_leading = ""
        until current_token.kind == :rbrace || at_end?
          stmt, trailing = parse_statement(stmt_leading)
          statements << stmt
          statement_trailings << trailing
          stmt_leading = ""
        end
        
        # Collect trivia before '}'
        rbrace_prefix = collect_trivia_string
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trailing after '}'
        trailing = collect_trivia_string
        
        stmt = Nodes::BlockStatement.new(
          leading_trivia: leading_trivia,
          statements: statements,
          statement_trailings: statement_trailings,
          lbrace_suffix: lbrace_suffix,
          rbrace_prefix: rbrace_prefix
        )
        
        [stmt, trailing]
      end
      
      # Parse if statement: `if (cond) stmt` or `if (cond) stmt else stmt`
      # Returns (IfStatement, trailing) tuple
      def parse_if_statement(leading_trivia)
        # Consume 'if'
        expect(:keyword_if)
        
        # Collect trivia after 'if'
        if_suffix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse condition
        condition, cond_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = cond_trailing + collect_trivia_string
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia after ')' (before then statement)
        then_leading = collect_trivia_string
        
        # Parse then statement
        then_stmt, then_trailing = parse_statement(then_leading)
        
        # Check for else clause
        else_stmt = nil
        else_prefix = ""
        else_suffix = ""
        
        potential_else_prefix = then_trailing + collect_trivia_string
        if current_token.kind == :keyword_else
          else_prefix = potential_else_prefix
          advance_raw  # consume 'else'
          
          # Collect trivia after 'else'
          else_suffix = collect_trivia_string
          
          # Parse else statement
          else_stmt, then_trailing = parse_statement("")
        else
          # No else, restore trivia as trailing
          then_trailing = potential_else_prefix
        end
        
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
        expect(:keyword_while)
        
        # Collect trivia after 'while'
        while_suffix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse condition
        condition, cond_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = cond_trailing + collect_trivia_string
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia after ')' (before body)
        body_leading = collect_trivia_string
        
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
        expect(:keyword_do)
        
        # Collect trivia after 'do'
        do_suffix = collect_trivia_string
        
        # Parse body
        body, body_trailing = parse_statement("")
        
        # Collect trivia before 'while'
        while_prefix = body_trailing + collect_trivia_string
        
        # Consume 'while'
        expect(:keyword_while)
        
        # Collect trivia after 'while'
        while_suffix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse condition
        condition, cond_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = cond_trailing + collect_trivia_string
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
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
        expect(:keyword_for)
        
        # Collect trivia after 'for'
        for_suffix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse init (can be empty)
        init = nil
        init_trailing = ""
        unless current_token.kind == :semicolon
          init, init_trailing = parse_expression
        end
        
        # Collect trivia before first ';'
        _semi1_prefix = init_trailing + collect_trivia_string
        
        # Consume first ';'
        expect(:semicolon)
        
        # Collect trivia after first ';'
        after_semi1 = collect_trivia_string
        
        # Parse condition (can be empty)
        condition = nil
        condition_trailing = ""
        unless current_token.kind == :semicolon
          condition, condition_trailing = parse_expression
        end
        
        # Collect trivia before second ';'
        _semi2_prefix = condition_trailing + collect_trivia_string
        
        # Consume second ';'
        expect(:semicolon)
        
        # Collect trivia after second ';'
        after_semi2 = collect_trivia_string
        
        # Parse increment (can be empty)
        increment = nil
        rparen_prefix = ""
        unless current_token.kind == :rparen
          increment, inc_trailing = parse_expression
          rparen_prefix = inc_trailing + collect_trivia_string
        end
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia after ')' (before body)
        body_leading = collect_trivia_string
        
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
        expect(:keyword_switch)
        
        # Collect trivia after 'switch'
        switch_suffix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse expression
        expression, expr_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = expr_trailing + collect_trivia_string
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia before '{' (space between ) and {)
        lbrace_prefix = collect_trivia_string
        
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = collect_trivia_string
        
        # Parse case clauses
        cases = []
        case_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          case_leading += collect_trivia_string
          
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
        rbrace_prefix = collect_trivia_string
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trailing
        trailing = collect_trivia_string
        
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
        expect(:keyword_case)
        
        # Collect trivia after 'case'
        case_suffix = collect_trivia_string
        
        # Parse value
        value, value_trailing = parse_expression
        
        # Collect trivia before ':'
        _colon_prefix = value_trailing + collect_trivia_string
        
        # Consume ':'
        expect(:colon)
        
        # Collect trivia after ':'
        colon_suffix = collect_trivia_string
        
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
        expect(:keyword_default)
        
        # Collect trivia before ':'
        _colon_prefix = collect_trivia_string
        
        # Consume ':'
        expect(:colon)
        
        # Collect trivia after ':'
        colon_suffix = collect_trivia_string
        
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
        expect(:keyword_break)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::BreakStatement.new(leading_trivia: leading_trivia)
        
        [stmt, trailing]
      end
      
      # Parse continue statement: `continue;`
      # Returns (ContinueStatement, trailing) tuple
      def parse_continue_statement(leading_trivia)
        # Consume 'continue'
        expect(:keyword_continue)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::ContinueStatement.new(leading_trivia: leading_trivia)
        
        [stmt, trailing]
      end
      
      # Parse namespace declaration: `namespace name { ... }` or `namespace { ... }` (anonymous)
      # Returns (NamespaceDeclaration, trailing) tuple
      def parse_namespace_declaration(leading_trivia)
        # Consume 'namespace'
        expect(:keyword_namespace)
        
        # Collect trivia after 'namespace'
        namespace_suffix = collect_trivia_string
        
        # Check if anonymous namespace (no name)
        name = "".dup
        name_suffix = ""
        
        if current_token.kind == :identifier
          # Parse name (can be nested with ::)
          loop do
            name << current_token.lexeme
            advance_raw
            
            # Check for ::
            trivia_before_colon = collect_trivia_string
            if current_token.kind == :colon_colon
              name << trivia_before_colon << current_token.lexeme
              advance_raw
            else
              # No more ::, this is the end of namespace name
              name_suffix = trivia_before_colon
              break
            end
          end
          
          # Collect additional trivia after name
          name_suffix = name_suffix + collect_trivia_string
        end
        
        # Parse body (block statement)
        body, trailing = parse_block_statement("")
        
        stmt = Nodes::NamespaceDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          body: body,
          namespace_suffix: namespace_suffix,
          name_suffix: name_suffix
        )
        
        [stmt, trailing]
      end
      
      # Check if current position looks like a declaration
      # Heuristics:
      # - Starts with type keyword (int, float, const, etc)
      # - Or identifier followed by identifier (CustomType varName)
      # - Followed by = or ; or ,
      def looks_like_declaration?
        # Type keywords
        type_keywords = [:keyword_int, :keyword_float, :keyword_double, :keyword_char, 
                        :keyword_bool, :keyword_void, :keyword_auto,
                        :keyword_const, :keyword_static, :keyword_extern,
                        :keyword_unsigned, :keyword_signed, :keyword_long, :keyword_short]
        
        return true if type_keywords.include?(current_token.kind)
        
        # Check pattern: identifier identifier (CustomType varName) or std::vector<int> varName
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        advance_raw
        collect_trivia_string
        
        # Skip :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          advance_raw
          collect_trivia_string
          if current_token.kind == :identifier
            advance_raw
            collect_trivia_string
          end
        end
        
        # Skip <...> for template types (vector<int>)
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
          
          collect_trivia_string
        end
        
        # Check if followed by identifier (variable name) or * & (pointers/refs)
        result = [:identifier, :asterisk, :ampersand].include?(current_token.kind)
        
        @position = saved_pos
        result
      end
      
      # Simple heuristic to detect function declarations
      # Look for pattern: type name ( or type ~name ( or std::vector<int> name (
      def looks_like_function_declaration?
        return false unless current_token.kind == :identifier || current_token.kind.to_s.start_with?("keyword_")
        
        # Save position
        saved_pos = @position
        
        # Try to scan: type name (
        advance_raw  # skip type
        collect_trivia_string
        
        # Skip :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          advance_raw
          collect_trivia_string
          if current_token.kind == :identifier
            advance_raw
            collect_trivia_string
          end
        end
        
        # Skip <...> for template types (vector<int>)
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
          
          collect_trivia_string
        end
        
        # Check for destructor ~
        if current_token.kind == :tilde
          advance_raw
          collect_trivia_string
        end
        
        is_func = current_token.kind == :identifier
        if is_func
          advance_raw  # skip name
          collect_trivia_string
          is_func = current_token.kind == :lparen
        end
        
        # Restore position
        @position = saved_pos
        
        is_func
      end
      
      # Parse function declaration: `type name(params);` or `type name(params) { ... }`
      # Returns (FunctionDeclaration, trailing) tuple
      def parse_function_declaration(leading_trivia)
        # Parse return type (can be simple or template: int, std::vector<int>, etc)
        return_type = "".dup
        return_type << current_token.lexeme
        advance_raw
        
        # Collect trivia after first part of return type
        trivia_after = collect_trivia_string
        
        # Handle :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          return_type << trivia_after << current_token.lexeme
          advance_raw
          trivia_after = collect_trivia_string
          
          if current_token.kind == :identifier
            return_type << trivia_after << current_token.lexeme
            advance_raw
            trivia_after = collect_trivia_string
          end
        end
        
        # Handle <...> for template types (vector<int>)
        if current_token.kind == :less
          return_type << trivia_after
          return_type << current_token.lexeme
          advance_raw
          
          depth = 1
          while depth > 0 && !at_end?
            if current_token.kind == :less
              depth += 1
            elsif current_token.kind == :greater
              depth -= 1
            end
            
            return_type << current_token.lexeme
            advance_raw
            
            if depth == 0
              break
            end
          end
          
          trivia_after = collect_trivia_string
        end
        
        return_type_suffix = trivia_after
        
        # Check for destructor (~ClassName) or function name
        # Destructor: ~ immediately before identifier
        name = "".dup
        if current_token.kind == :tilde
          name << current_token.lexeme
          advance_raw
          name << collect_trivia_string
        end
        
        # Parse function name
        unless current_token.kind == :identifier
          raise ParseError, "Expected function name"
        end
        
        name << current_token.lexeme
        advance_raw
        
        # Collect trivia before '('
        _lparen_prefix = collect_trivia_string
        
        # Consume '('
        expect(:lparen)
        
        # Collect trivia after '('
        lparen_suffix = collect_trivia_string
        
        # Parse parameters (simplified - just collect as strings until ')')
        parameters = []
        param_separators = []
        
        until current_token.kind == :rparen || at_end?
          param_text = "".dup
          paren_depth = 0
          
          # Collect parameter text until comma or )
          loop do
            break if at_end?
            
            if current_token.kind == :lparen
              paren_depth += 1
              param_text << current_token.lexeme
              advance_raw
            elsif current_token.kind == :rparen
              break if paren_depth.zero?
              paren_depth -= 1
              param_text << current_token.lexeme
              advance_raw
            elsif current_token.kind == :comma && paren_depth.zero?
              break
            else
              param_text << current_token.lexeme
              advance_raw
            end
          end
          
          parameters << param_text unless param_text.empty?
          
          # Check for comma
          if current_token.kind == :comma
            separator = current_token.lexeme.dup
            advance_raw
            separator << collect_trivia_string
            param_separators << separator
          end
        end
        
        # Collect trivia before ')'
        rparen_suffix = collect_trivia_string
        
        # Consume ')'
        expect(:rparen)
        
        # Collect trivia after ')'
        after_rparen = collect_trivia_string
        
        # Collect modifiers (const, override, final, noexcept, = default, etc)
        modifiers_text = "".dup
        until [:lbrace, :semicolon].include?(current_token.kind) || at_end?
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          
          modifiers_text << current_token.lexeme
          advance_raw
          modifiers_text << collect_trivia_string
        end
        
        # Check for body (block) or semicolon
        body = nil
        trailing = ""
        
        if current_token.kind == :lbrace
          body, trailing = parse_block_statement(after_rparen)
        else
          # Declaration only - expect semicolon
          _semicolon_prefix = after_rparen + collect_trivia_string
          expect(:semicolon)
          trailing = collect_trivia_string
        end
        
        stmt = Nodes::FunctionDeclaration.new(
          leading_trivia: leading_trivia,
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
      
      # Parse class declaration: `class Name { ... };` or `class Name : public Base { ... };`
      # Returns (ClassDeclaration, trailing) tuple
      def parse_class_declaration(leading_trivia)
        # Consume 'class'
        expect(:keyword_class)
        
        # Collect trivia after 'class'
        class_suffix = collect_trivia_string
        
        # Parse name
        unless current_token.kind == :identifier
          raise ParseError, "Expected class name"
        end
        
        name = current_token.lexeme
        advance_raw
        
        # Collect trivia after name
        name_suffix = collect_trivia_string
        
        # Check for inheritance: `: public Base`
        base_classes_text = ""
        if current_token.kind == :colon
          # Collect everything from : to {
          base_classes_text = name_suffix.dup
          name_suffix = ""
          
          base_classes_text << current_token.lexeme  # :
          advance_raw
          
          # Collect until {
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_token.lexeme
            advance_raw
          end
        end
        
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = collect_trivia_string
        
        # Parse members
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += collect_trivia_string
          
          # Check for access specifiers
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            advance_raw
            
            # Expect ':'
            _colon_prefix = collect_trivia_string
            expect(:colon)
            
            colon_suffix = collect_trivia_string
            
            member = Nodes::AccessSpecifier.new(
              leading_trivia: member_leading,
              keyword: keyword,
              colon_suffix: colon_suffix
            )
            
            members << member
            member_trailings << ""
            member_leading = ""
          else
            # Parse as statement (could be variable, function, etc)
            member, trailing = parse_statement(member_leading)
            members << member
            member_trailings << trailing
            member_leading = ""
          end
        end
        
        # Collect trivia before '}'
        rbrace_suffix = collect_trivia_string
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::ClassDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          members: members,
          member_trailings: member_trailings,
          class_suffix: class_suffix,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix,
          base_classes_text: base_classes_text
        )
        
        [stmt, trailing]
      end
      
      # Parse struct declaration: `struct Name { ... };` or `struct Name : public Base { ... };`
      # Returns (StructDeclaration, trailing) tuple  
      def parse_struct_declaration(leading_trivia)
        # Consume 'struct'
        expect(:keyword_struct)
        
        # Collect trivia after 'struct'
        struct_suffix = collect_trivia_string
        
        # Parse name
        unless current_token.kind == :identifier
          raise ParseError, "Expected struct name"
        end
        
        name = current_token.lexeme
        advance_raw
        
        # Collect trivia after name
        name_suffix = collect_trivia_string
        
        # Check for inheritance: `: public Base`
        base_classes_text = ""
        if current_token.kind == :colon
          # Collect everything from : to {
          base_classes_text = name_suffix.dup
          name_suffix = ""
          
          base_classes_text << current_token.lexeme  # :
          advance_raw
          
          # Collect until {
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_token.lexeme
            advance_raw
          end
        end
        
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = collect_trivia_string
        
        # Parse members
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += collect_trivia_string
          
          # Check for access specifiers
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            advance_raw
            
            # Expect ':'
            _colon_prefix = collect_trivia_string
            expect(:colon)
            
            colon_suffix = collect_trivia_string
            
            member = Nodes::AccessSpecifier.new(
              leading_trivia: member_leading,
              keyword: keyword,
              colon_suffix: colon_suffix
            )
            
            members << member
            member_trailings << ""
            member_leading = ""
          else
            # Parse as statement (could be variable, function, etc)
            member, trailing = parse_statement(member_leading)
            members << member
            member_trailings << trailing
            member_leading = ""
          end
        end
        
        # Collect trivia before '}'
        rbrace_suffix = collect_trivia_string
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::StructDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          members: members,
          member_trailings: member_trailings,
          struct_suffix: struct_suffix,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix,
          base_classes_text: base_classes_text
        )
        
        [stmt, trailing]
      end
      
      # Parse variable declaration: `int x = 42;` or `const int* ptr, y = 5;`
      # Returns (VariableDeclaration, trailing) tuple
      def parse_variable_declaration(leading_trivia)
        # Parse type (can be multiple tokens: const int*, unsigned long, etc)
        type = "".dup
        
        # Collect type tokens
        loop do
          # Type keywords and modifiers
          if current_token.kind.to_s.start_with?("keyword_") || 
             current_token.kind == :identifier ||
             [:asterisk, :ampersand, :less, :greater, :colon_colon].include?(current_token.kind)
            
            type << current_token.lexeme
            advance_raw
            
            # Collect trivia after this token
            trivia = collect_trivia_string
            
            # Check if we're done with type (next is identifier for variable name)
            if current_token.kind == :identifier
              # This might be the variable name - check what follows
              saved_pos = @position
              advance_raw
              next_trivia = collect_trivia_string
              next_kind = current_token.kind
              @position = saved_pos
              
              # If followed by =, ; or , then this identifier is the variable name
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
          type = type_match[1]
          type_suffix = type_match[2]
        else
          type_suffix = ""
        end
        
        # Parse declarators (variable names with optional initializers)
        declarators = []
        declarator_separators = []
        
        loop do
          decl_text = "".dup
          
          # Parse variable name and initializer
          loop do
            break if at_end?
            
            if [:semicolon, :comma].include?(current_token.kind)
              break
            elsif current_token.kind == :equals
              # Assignment initializer: int x = 42
              decl_text << current_token.lexeme
              advance_raw
              
              # Parse initializer expression
              # Collect tokens until semicolon or comma
              loop do
                break if at_end?
                break if [:semicolon, :comma].include?(current_token.kind)
                
                if current_token.kind == :lparen
                  # Handle nested parens in initializer
                  decl_text << current_token.lexeme
                  advance_raw
                  paren_depth = 1
                  loop do
                    break if at_end?
                    if current_token.kind == :lparen
                      paren_depth += 1
                    elsif current_token.kind == :rparen
                      paren_depth -= 1
                    end
                    decl_text << current_token.lexeme
                    advance_raw
                    break if paren_depth.zero?
                  end
                elsif current_token.kind == :lbrace
                  # Handle nested braces in initializer
                  decl_text << current_token.lexeme
                  advance_raw
                  brace_depth = 1
                  loop do
                    break if at_end?
                    if current_token.kind == :lbrace
                      brace_depth += 1
                    elsif current_token.kind == :rbrace
                      brace_depth -= 1
                    end
                    decl_text << current_token.lexeme
                    advance_raw
                    break if brace_depth.zero?
                  end
                else
                  decl_text << current_token.lexeme
                  advance_raw
                end
              end
              break
            elsif current_token.kind == :lparen
              # Function-style initialization: int x(42) or could be function
              decl_text << current_token.lexeme
              advance_raw
              
              # Collect everything until matching )
              paren_depth = 1
              loop do
                break if at_end?
                
                if current_token.kind == :lparen
                  paren_depth += 1
                elsif current_token.kind == :rparen
                  paren_depth -= 1
                end
                
                decl_text << current_token.lexeme
                advance_raw
                
                break if paren_depth.zero?
              end
            elsif current_token.kind == :lbrace
              # Brace initialization: int x{42}
              decl_text << current_token.lexeme
              advance_raw
              
              # Collect everything until matching }
              brace_depth = 1
              loop do
                break if at_end?
                
                if current_token.kind == :lbrace
                  brace_depth += 1
                elsif current_token.kind == :rbrace
                  brace_depth -= 1
                end
                
                decl_text << current_token.lexeme
                advance_raw
                
                break if brace_depth.zero?
              end
            else
              decl_text << current_token.lexeme
              advance_raw
            end
          end
          
          declarators << decl_text
          
          # Check for comma (more declarators)
          if current_token.kind == :comma
            separator = current_token.lexeme.dup
            advance_raw
            separator << collect_trivia_string
            declarator_separators << separator
          else
            break
          end
        end
        
        # Consume semicolon
        _semicolon_prefix = collect_trivia_string
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::VariableDeclaration.new(
          leading_trivia: leading_trivia,
          type: type,
          declarators: declarators,
          declarator_separators: declarator_separators,
          type_suffix: type_suffix.empty? ? " " : type_suffix
        )
        
        [stmt, trailing]
      end
      
      # Parse using declaration: `using namespace std;` or `using MyType = int;`
      # Returns (UsingDeclaration, trailing) tuple
      def parse_using_declaration(leading_trivia)
        # Consume 'using'
        expect(:keyword_using)
        
        # Collect trivia after 'using'
        using_suffix = collect_trivia_string
        
        # Check if it's 'using namespace'
        if current_token.kind == :keyword_namespace
          advance_raw  # consume 'namespace'
          
          # Collect trivia after 'namespace'
          namespace_suffix = collect_trivia_string
          
          # Parse namespace name (can be nested like std::chrono)
          name = "".dup
          name_suffix = ""
          loop do
            unless current_token.kind == :identifier
              raise ParseError, "Expected namespace name"
            end
            
            name << current_token.lexeme
            advance_raw
            
            # Check for ::
            trivia_before_colon = collect_trivia_string
            if current_token.kind == :colon_colon
              name << trivia_before_colon << current_token.lexeme
              advance_raw
            else
              # No more ::, this is the end
              name_suffix = trivia_before_colon
              break
            end
          end
          
          # Consume semicolon
          _semicolon_prefix = collect_trivia_string
          expect(:semicolon)
          
          # Collect trailing
          trailing = collect_trivia_string
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :namespace,
            name: name + name_suffix,
            using_suffix: using_suffix,
            namespace_suffix: namespace_suffix
          )
          
          return [stmt, trailing]
        end
        
        # Parse name (could be simple name or qualified name like std::vector)
        name = "".dup
        after_name = ""
        loop do
          unless current_token.kind == :identifier
            raise ParseError, "Expected identifier in using declaration"
          end
          
          name << current_token.lexeme
          advance_raw
          
          # Check for ::
          trivia_before_colon = collect_trivia_string
          if current_token.kind == :colon_colon
            name << trivia_before_colon << current_token.lexeme
            advance_raw
          else
            # No more ::, this is the end
            after_name = trivia_before_colon
            break
          end
        end
        
        # Check if it's type alias: using MyType = int;
        after_name_extra = collect_trivia_string
        if current_token.kind == :equals
          equals_prefix = after_name + after_name_extra
          advance_raw  # consume '='
          
          # Collect trivia after '='
          equals_suffix = collect_trivia_string
          
          # Parse target type (collect as string until semicolon)
          alias_target = "".dup
          until current_token.kind == :semicolon || at_end?
            alias_target << current_token.lexeme
            advance_raw
          end
          
          # Consume semicolon
          _semicolon_prefix = collect_trivia_string
          expect(:semicolon)
          
          # Collect trailing
          trailing = collect_trivia_string
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :alias,
            name: name,
            alias_target: alias_target,
            using_suffix: using_suffix,
            equals_prefix: equals_prefix,
            equals_suffix: equals_suffix
          )
          
          return [stmt, trailing]
        else
          # Simple using: using std::vector;
          _semicolon_prefix = after_name + after_name_extra + collect_trivia_string
          expect(:semicolon)
          
          # Collect trailing
          trailing = collect_trivia_string
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :name,
            name: name,
            using_suffix: using_suffix
          )
          
          return [stmt, trailing]
        end
      end
      
      # Parse template declaration: `template<typename T> class Foo { ... };`
      # Returns (TemplateDeclaration, trailing) tuple
      def parse_template_declaration(leading_trivia)
        # Consume 'template'
        expect(:keyword_template)
        
        # Collect trivia after 'template'
        template_suffix = collect_trivia_string
        
        # Consume '<'
        expect(:less)
        
        # Collect template parameters as string (simplified approach)
        # Count < > to handle nested templates like template<typename T, typename U<V>>
        params = "".dup
        depth = 1
        
        loop do
          break if at_end?
          
          case current_token.kind
          when :less
            depth += 1
            params << current_token.lexeme
            advance_raw
          when :greater
            depth -= 1
            if depth == 0
              break
            else
              params << current_token.lexeme
              advance_raw
            end
          else
            params << current_token.lexeme
            advance_raw
          end
        end
        
        # Consume '>'
        expect(:greater)
        
        # Collect trivia after '>'
        params_suffix = collect_trivia_string
        
        # Parse the templated declaration (function, class, struct)
        inner_leading = ""
        declaration, trailing = parse_statement(inner_leading)
        
        stmt = Nodes::TemplateDeclaration.new(
          leading_trivia: leading_trivia,
          template_params: params,
          declaration: declaration,
          template_suffix: template_suffix,
          params_suffix: params_suffix
        )
        
        [stmt, trailing]
      end
      
      # Parse enum declaration: `enum Color { Red, Green };` or `enum class Color { Red, Green };`
      # Returns (EnumDeclaration, trailing) tuple
      def parse_enum_declaration(leading_trivia)
        # Consume 'enum'
        expect(:keyword_enum)
        
        # Collect trivia after 'enum'
        enum_suffix = collect_trivia_string
        
        # Check for 'class' or 'struct' keyword
        class_keyword = ""
        class_suffix = ""
        if [:keyword_class, :keyword_struct].include?(current_token.kind)
          class_keyword = current_token.lexeme
          advance_raw
          class_suffix = collect_trivia_string
        end
        
        # Parse name (optional for anonymous enums)
        name = ""
        name_suffix = ""
        if current_token.kind == :identifier
          name = current_token.lexeme
          advance_raw
          name_suffix = collect_trivia_string
        end
        
        # Check for base type: `: int`
        if current_token.kind == :colon
          name_suffix << current_token.lexeme
          advance_raw
          
          # Collect base type until {
          until current_token.kind == :lbrace || at_end?
            name_suffix << current_token.lexeme
            advance_raw
          end
        end
        
        # Consume '{'
        expect(:lbrace)
        
        # Collect trivia after '{'
        lbrace_suffix = collect_trivia_string
        
        # Collect enumerators as text until '}'
        enumerators = "".dup
        until current_token.kind == :rbrace || at_end?
          enumerators << current_token.lexeme
          advance_raw
        end
        
        # Collect trivia before '}'
        rbrace_suffix = collect_trivia_string
        
        # Consume '}'
        expect(:rbrace)
        
        # Collect trivia before ';'
        _semicolon_prefix = collect_trivia_string
        
        # Consume ';'
        expect(:semicolon)
        
        # Collect trailing
        trailing = collect_trivia_string
        
        stmt = Nodes::EnumDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          enumerators: enumerators,
          enum_suffix: enum_suffix,
          class_keyword: class_keyword,
          class_suffix: class_suffix,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end

