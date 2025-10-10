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
      
      # Parse if statement: `if (cond) stmt` or `if (cond) stmt else stmt`
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
        rparen_prefix = cond_trailing + current_leading_trivia
        
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
        while_suffix = current_token.trailing_trivia
        expect(:keyword_while)
        
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse condition
        condition, cond_trailing = parse_expression
        
        # Collect trivia before ')'
        rparen_prefix = cond_trailing + current_leading_trivia
        
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
        rparen_prefix = cond_trailing + current_leading_trivia
        
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
          rparen_prefix = inc_trailing + current_leading_trivia
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
      
      # Parse namespace declaration: `namespace name { ... }` or `namespace { ... }` (anonymous)
      # Returns (NamespaceDeclaration, trailing) tuple
      def parse_namespace_declaration(leading_trivia)
        # Consume 'namespace'
        namespace_suffix = current_token.trailing_trivia
        expect(:keyword_namespace)
        
        # Check if anonymous namespace (no name)
        name = "".dup
        name_suffix = ""
        
        if current_token.kind == :identifier
          # Parse name (can be nested with ::)
          loop do
            name << current_token.lexeme
            trivia_before_colon = current_token.trailing_trivia
            advance_raw
            
            # Check for ::
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
          name_suffix = name_suffix + current_leading_trivia
        end
        
        # Parse body (block statement)
        push_context(:namespace, name: name)
        body, trailing = parse_block_statement("")
        pop_context
        
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
        current_leading_trivia
        
        # Skip :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier
            advance_raw
            current_leading_trivia
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
          
          current_leading_trivia
        end
        
        # Check if followed by identifier (variable name) or * & (pointers/refs)
        result = [:identifier, :asterisk, :ampersand].include?(current_token.kind)
        
        @position = saved_pos
        result
      end
      
      # Simple heuristic to detect function declarations
      # Look for pattern: type name ( or type ~name ( or std::vector<int> name (
      # Can have modifiers before: virtual, inline, static, explicit, constexpr
      def looks_like_function_declaration?
        return false unless current_token.kind == :identifier || current_token.kind.to_s.start_with?("keyword_")
        
        # Check for constructor (ClassName(...) inside class/struct)
        if in_context?(:class)
          saved_pos = @position
          
          # Skip explicit modifier if present
          if current_token.kind == :keyword_explicit
            advance_raw
            current_leading_trivia
          end
          
          # Check if identifier matches class name
          if current_token.kind == :identifier && current_token.lexeme == current_class_name
            advance_raw
            current_leading_trivia
            
            # Check for (
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
          
          @position = saved_pos
        end
        
        # Check for out-of-line constructor (ClassName::ClassName(...))
        if current_token.kind == :identifier
          saved_pos = @position
          class_name = current_token.lexeme
          advance_raw
          current_leading_trivia
          
          # Check for ::
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            
            # Check if next identifier matches class name
            if current_token.kind == :identifier && current_token.lexeme == class_name
              advance_raw
              current_leading_trivia
              
              # Check for (
              if current_token.kind == :lparen
                @position = saved_pos
                return true
              end
            end
          end
          
          @position = saved_pos
        end
        
        # Save position
        saved_pos = @position
        
        # Skip function modifiers (virtual, inline, static, explicit, constexpr, friend)
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          advance_raw
          current_leading_trivia
        end
        
        # Don't treat class/struct/enum/namespace/using/template as return type
        if [:keyword_class, :keyword_struct, :keyword_enum, :keyword_namespace, 
            :keyword_using, :keyword_template, :keyword_typedef].include?(current_token.kind)
          @position = saved_pos
          return false
        end
        
        # Try to scan: type name (
        advance_raw  # skip type
        current_leading_trivia
        
        # Skip :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier
            advance_raw
            current_leading_trivia
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
          
          current_leading_trivia
        end
        
        # Check for operator overloading BEFORE skipping *&
        # Pattern: Type operator+ or Type* ClassName::operator+
        if current_token.kind == :keyword_operator
          # Inline operator: Type operator+
          @position = saved_pos
          return true
        end
        
        # Check for out-of-line operator: Type ClassName::operator+ or Type* ClassName::operator+
        if current_token.kind == :asterisk || current_token.kind == :ampersand
          # Save position before skipping *&
          saved_before_ptr = @position
          
          # Skip all * and &
          while [:asterisk, :ampersand].include?(current_token.kind)
            advance_raw
            current_leading_trivia
          end
          
          # Check for inline operator after *&: Buffer& operator=
          if current_token.kind == :keyword_operator
            # Skip 'operator' keyword
            advance_raw
            current_leading_trivia
            
            # Skip operator symbol(s)
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
              # operator()
              advance_raw
              if current_token.kind == :rparen
                advance_raw
                current_leading_trivia
              end
            elsif current_token.kind == :lbracket
              # operator[]
              advance_raw
              if current_token.kind == :rbracket
                advance_raw
                current_leading_trivia
              end
            end
            
            # Now check for (
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
          
          # Check if followed by ClassName::operator
          if current_token.kind == :identifier
            saved_after_ptr = @position
            advance_raw
            current_leading_trivia
            
            if current_token.kind == :colon_colon
              advance_raw
              current_leading_trivia
              
              if current_token.kind == :keyword_operator
                # Out-of-line operator with pointer/reference return type
                @position = saved_pos
                return true
              end
            end
            
            # Not operator, restore to after pointer
            @position = saved_after_ptr
          end
          
          # Continue with this position (after *)
        elsif current_token.kind == :identifier
          # No pointer, check directly for ClassName::operator
          saved_operator_pos = @position
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            
            if current_token.kind == :keyword_operator
              # Out-of-line operator without pointer
              @position = saved_pos
              return true
            end
          end
          
          # Restore if not operator
          @position = saved_operator_pos
        end
        
        # Check for destructor ~
        if current_token.kind == :tilde
          advance_raw
          current_leading_trivia
        end
        
        is_func = current_token.kind == :identifier
        if is_func
          advance_raw  # skip name
          current_leading_trivia
          is_func = current_token.kind == :lparen
        end
        
        # Restore position
        @position = saved_pos
        
        is_func
      end
      
      # Parse function declaration: `type name(params);` or `type name(params) { ... }`
      # Or constructor: `[explicit] ClassName(params) [: initializers] ;` or `{ body }`
      # Returns (FunctionDeclaration, trailing) tuple
      def parse_function_declaration(leading_trivia)
        # Collect function prefix modifiers (virtual, inline, static, explicit, constexpr, friend)
        prefix_modifiers = "".dup
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          prefix_modifiers << current_token.lexeme
          prefix_suffix = current_token.trailing_trivia

          advance_raw
          prefix_modifiers << prefix_suffix
        end
        
        # Check if this is a constructor
        is_constructor = false
        constructor_class_name = nil
        
        # In-class constructor: ClassName(...)
        # Must be followed by ( or :: (not by & or other tokens)
        if in_context?(:class) && current_token.kind == :identifier && 
           current_token.lexeme == current_class_name
          # Look ahead to check if followed by ( or ::
          saved_constructor_pos = @position
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :lparen || current_token.kind == :colon_colon
            is_constructor = true
            constructor_class_name = current_class_name
          end
          
          @position = saved_constructor_pos
        end
        
        # Out-of-line constructor: ClassName::ClassName(...)
        if !is_constructor && current_token.kind == :identifier
          saved_check_pos = @position
          class_name = current_token.lexeme
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            
            if current_token.kind == :identifier && current_token.lexeme == class_name
              is_constructor = true
              constructor_class_name = class_name
            end
          end
          
          @position = saved_check_pos
        end
        
        # Parse return type (skip for constructors)
        return_type = "".dup
        trivia_after = ""
        unless is_constructor
          return_type << current_token.lexeme
          trivia_after = current_token.trailing_trivia
          advance_raw
        end
        
        unless is_constructor
          # Handle :: for qualified names (std::vector)
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
          
          # Handle <...> for template types (vector<int>)
          if current_token.kind == :less
            return_type << trivia_after
            return_type << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            
            depth = 1
            while depth > 0 && !at_end?
              if current_token.kind == :less
                depth += 1
              elsif current_token.kind == :greater
                depth -= 1
              end
              
              return_type << current_leading_trivia << current_token.lexeme
              if depth == 0
                # Это закрывающий >, сохраняем его trailing trivia
                trivia_after = current_token.trailing_trivia
              else
                return_type << current_token.trailing_trivia
              end
              advance_raw
              
              if depth == 0
                break
              end
            end
          end
          
          # Handle * and & for pointers and references (int*, A&, const int*)
          while [:asterisk, :ampersand].include?(current_token.kind)
            return_type << trivia_after
            return_type << current_token.lexeme
            trivia_after = current_token.trailing_trivia

            advance_raw
          end
          
          # Store return_type_suffix before checking for operator
          return_type_suffix = trivia_after
        end
        
        # Check for operator overloading or destructor or constructor or regular function name
        name = "".dup
        
        if is_constructor
          # Constructor: name is class name or ClassName::ClassName
          return_type_suffix = trivia_after
          name << current_token.lexeme
          advance_raw
          
          # Check for :: (out-of-line constructor)
          scope_trivia = current_leading_trivia
          if current_token.kind == :colon_colon
            name << scope_trivia << current_token.lexeme
            advance_raw
            name << current_leading_trivia << current_token.lexeme
            advance_raw
          else
            # Restore trivia for in-class constructor
            return_type_suffix << scope_trivia if scope_trivia.length > 0
          end
        elsif current_token.kind == :identifier
          # Check for out-of-line operator: ClassName::operator+
          saved_name_pos = @position
          class_name = current_token.lexeme
          scope_trivia = current_token.trailing_trivia

          advance_raw
          
          if current_token.kind == :colon_colon
            after_colon = current_token.trailing_trivia

            advance_raw
            
            if current_token.kind == :keyword_operator
              # Out-of-line operator overloading
              return_type_suffix = trivia_after
              name << class_name << scope_trivia << "::" << after_colon
              name << current_token.lexeme
              advance_raw
              # Collect trivia between 'operator' and the operator symbol
              operator_trivia = current_leading_trivia
              name << operator_trivia
              
              # Collect the operator symbol(s)
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
                # operator()
                name << current_token.lexeme  # '('
                advance_raw
                name << current_token.lexeme  # ')'
                expect(:rparen)  # consume ')'
              elsif current_token.kind == :lbracket
                # operator[]
                name << current_token.lexeme  # '['
                advance_raw
                name << current_token.lexeme  # ']'
                expect(:rbracket)  # consume ']'
              elsif current_token.kind == :keyword_new || current_token.kind == :keyword_delete
                # operator new, operator delete
                name << " " << current_token.lexeme
                advance_raw
                # Check for [] after new/delete
                if current_token.kind == :lbracket
                  name << current_token.lexeme  # '['
                  advance_raw
                  name << current_token.lexeme  # ']'
                  expect(:rbracket)  # consume ']'
                end
              end
            else
              # Not operator, regular function: ClassName::method
              @position = saved_name_pos
              return_type_suffix = trivia_after
              name << current_token.lexeme
              scope_trivia2 = current_token.trailing_trivia

              advance_raw
              name << scope_trivia2 << current_token.lexeme  # ::
              expect(:colon_colon)
              after_colon2 = current_token.trailing_trivia

              advance_raw
              name << after_colon2 << current_token.lexeme  # method name
              expect_identifier
            end
          else
            # Regular function name
            @position = saved_name_pos
            return_type_suffix = trivia_after
            name << current_token.lexeme
            advance_raw
          end
        elsif current_token.kind == :keyword_operator
          # Operator overloading: operator+, operator[], operator==, etc
          # The trivia_after is space between return type and 'operator'
          return_type_suffix = trivia_after
          name << current_token.lexeme
          advance_raw
          # Collect trivia between 'operator' and the operator symbol
          operator_trivia = current_leading_trivia
          name << operator_trivia
          
          # Collect the operator symbol(s)
          # Can be: +, -, *, /, %, =, ==, !=, <, >, <=, >=, ++, --, [], (), etc
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
            # operator()
            name << current_token.lexeme
            advance_raw
            expect(:rparen)
            name << current_token.lexeme
            advance_raw
          elsif current_token.kind == :lbracket
            # operator[]
            name << current_token.lexeme
            advance_raw
            expect(:rbracket)
            name << current_token.lexeme
            advance_raw
          elsif current_token.kind == :keyword_new || current_token.kind == :keyword_delete
            # operator new, operator delete
            name << " " << current_token.lexeme
            advance_raw
            # Check for [] after new/delete
            if current_token.kind == :lbracket
              name << current_token.lexeme
              advance_raw
              expect(:rbracket)
              name << current_token.lexeme
              advance_raw
            end
          else
            # Could be conversion operator: operator int()
            # In this case, the type follows 'operator'
            # For now, collect until '('
            while current_token.kind != :lparen && !at_end?
              name << current_token.lexeme
              advance_raw
            end
          end
        elsif current_token.kind == :tilde
          # Destructor: ~ClassName
          return_type_suffix = trivia_after  # Use trivia before '~'
          name << current_token.lexeme
          advance_raw
          # NO trivia between ~ and class name
          
          unless current_token.kind == :identifier
            raise ParseError, "Expected class name after ~"
          end
          name << current_token.lexeme
          advance_raw
        else
          # Regular function name
          return_type_suffix = trivia_after
          unless current_token.kind == :identifier
            raise ParseError, "Expected function name"
          end
          
          name << current_token.lexeme
          advance_raw
        end
        
        # Collect trivia before '('
        _lparen_prefix = current_leading_trivia
        
        # Consume '('
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        # Parse parameters (simplified - just collect as strings until ')')
        parameters = []
        param_separators = []
        
        until current_token.kind == :rparen || at_end?
          param_text = "".dup
          paren_depth = 0
          
          # Collect parameter text until comma or )
          loop do
            break if at_end?
            
            # Include leading trivia (for attributes like [[maybe_unused]])
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
          
          # Check for comma
          if current_token.kind == :comma
            separator = current_token.lexeme.dup
            separator << current_token.trailing_trivia
            advance_raw
            param_separators << separator
          end
        end
        
        # Collect trivia before ')'
        rparen_suffix = current_leading_trivia
        
        # Consume ')'
        after_rparen = current_token.trailing_trivia
        expect(:rparen)
        
        # Collect modifiers (const, override, final, noexcept, = default, etc)
        # For constructors: also collect modifiers before : (like noexcept)
        modifiers_text = "".dup
        until [:lbrace, :semicolon, :colon].include?(current_token.kind) || at_end?
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          
          modifiers_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        # Check for constructor initializer list (: member_(value), ...)
        if is_constructor && current_token.kind == :colon
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          
          # Collect everything from : to { or ;
          while ![:lbrace, :semicolon].include?(current_token.kind) && !at_end?
            modifiers_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          
          # Collect trivia before { or ;
          after_rparen = current_leading_trivia
        end
        
        # Check for body (block) or semicolon
        body = nil
        trailing = ""
        
        if current_token.kind == :lbrace
          body, trailing = parse_block_statement(after_rparen)
        else
          # Declaration only - expect semicolon
          _semicolon_prefix = after_rparen + current_leading_trivia
          trailing = current_token.trailing_trivia

          expect(:semicolon)
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
      
      # Parse class declaration: `class Name { ... };` or `class Name : public Base { ... };`
      # Returns (ClassDeclaration, trailing) tuple
      def parse_class_declaration(leading_trivia)
        # Consume 'class'
        class_suffix = current_token.trailing_trivia
        expect(:keyword_class)
        
        # Parse name
        unless current_token.kind == :identifier
          raise ParseError, "Expected class name"
        end
        
        name = current_token.lexeme
        name_suffix = current_token.trailing_trivia
        advance_raw
        
        # Check for inheritance: `: public Base`
        base_classes_text = ""
        if current_token.kind == :colon
          # Collect everything from : to {
          base_classes_text = name_suffix.dup
          name_suffix = ""
          
          base_classes_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          # Collect until {
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Push class context
        push_context(:class, name: name)
        
        # Parse members
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += current_leading_trivia
          
          # Check for access specifiers
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            _colon_prefix = current_token.trailing_trivia
            advance_raw
            
            # Expect ':'
            colon_suffix = current_token.trailing_trivia
            expect(:colon)
            
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
        
        # Pop class context
        pop_context
        
        # Collect trivia before '}'
        rbrace_suffix = current_leading_trivia
        
        # Consume '}'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
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
        struct_suffix = current_token.trailing_trivia
        expect(:keyword_struct)
        
        # Parse name
        unless current_token.kind == :identifier
          raise ParseError, "Expected struct name"
        end
        
        name = current_token.lexeme
        name_suffix = current_token.trailing_trivia
        advance_raw
        
        # Check for inheritance: `: public Base`
        base_classes_text = ""
        if current_token.kind == :colon
          # Collect everything from : to {
          base_classes_text = name_suffix.dup
          name_suffix = ""
          
          base_classes_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          # Collect until {
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Push struct context (treat as class for constructors)
        push_context(:class, name: name)
        
        # Parse members
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += current_leading_trivia
          
          # Check for access specifiers
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            _colon_prefix = current_token.trailing_trivia
            advance_raw
            
            # Expect ':'
            colon_suffix = current_token.trailing_trivia
            expect(:colon)
            
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
        
        # Pop struct context
        pop_context
        
        # Collect trivia before '}'
        rbrace_suffix = current_leading_trivia
        
        # Consume '}'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
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
        template_depth = 0
        
        # Collect type tokens
        loop do
          # Type keywords and modifiers
          if current_token.kind.to_s.start_with?("keyword_") || 
             current_token.kind == :identifier ||
             [:asterisk, :ampersand, :less, :greater, :colon_colon, :comma, :lparen, :rparen].include?(current_token.kind)
            
            was_colon_colon = current_token.kind == :colon_colon
            
            # Track template depth
            if current_token.kind == :less
              template_depth += 1
            elsif current_token.kind == :greater
              template_depth -= 1
            end
            
            # Don't include comma in type if not in template
            if current_token.kind == :comma && template_depth == 0
              break
            end
            
            type << current_token.lexeme
            trivia = current_token.trailing_trivia
            advance_raw
            
            # Don't add trivia after :: if next is identifier/keyword (qualified name)
            if was_colon_colon && (current_token.kind == :identifier || 
                                   current_token.kind.to_s.start_with?("keyword_"))
              # Skip trivia - it will be added by the next iteration
              next
            end
            
            # Don't add trivia if next token is template delimiter and we're in template
            if template_depth > 0 && [:comma, :greater, :lparen, :rparen].include?(current_token.kind)
              # Skip trivia before template delimiters and parens (function types)
              next
            end
            
            # Check if we're done with type (next is identifier for variable name)
            if current_token.kind == :identifier
              # This might be the variable name - check what follows
              saved_pos = @position
              next_trivia = current_token.trailing_trivia

              advance_raw
              next_kind = current_token.kind
              @position = saved_pos
              
              # If followed by =, ;, ,, {, (, [ then this identifier is the variable name
              if [:equals, :semicolon, :comma, :lparen, :lbracket, :lbrace].include?(next_kind)
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
              decl_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
              
              # Parse initializer expression
              # Collect tokens until semicolon or comma
              loop do
                break if at_end?
                break if [:semicolon, :comma].include?(current_token.kind)
                
                if current_token.kind == :lparen
                  # Handle nested parens in initializer
                  decl_text << current_token.lexeme << current_token.trailing_trivia
                  advance_raw
                  paren_depth = 1
                  loop do
                    break if at_end?
                    if current_token.kind == :lparen
                      paren_depth += 1
                    elsif current_token.kind == :rparen
                      paren_depth -= 1
                    end
                    decl_text << current_token.lexeme << current_token.trailing_trivia
                    advance_raw
                    break if paren_depth.zero?
                  end
                elsif current_token.kind == :lbrace
                  # Handle nested braces in initializer
                  decl_text << current_token.lexeme << current_token.trailing_trivia
                  advance_raw
                  brace_depth = 1
                  loop do
                    break if at_end?
                    if current_token.kind == :lbrace
                      brace_depth += 1
                    elsif current_token.kind == :rbrace
                      brace_depth -= 1
                    end
                    decl_text << current_token.lexeme << current_token.trailing_trivia
                    advance_raw
                    break if brace_depth.zero?
                  end
                else
                  decl_text << current_token.lexeme << current_token.trailing_trivia
                  advance_raw
                end
              end
              break
            elsif current_token.kind == :lparen
              # Function-style initialization: int x(42) or could be function
              decl_text << current_token.lexeme << current_token.trailing_trivia
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
                
                decl_text << current_token.lexeme << current_token.trailing_trivia
                advance_raw
                
                break if paren_depth.zero?
              end
            elsif current_token.kind == :lbrace
              # Brace initialization: int x{42}
              decl_text << current_token.lexeme << current_token.trailing_trivia
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
                
                decl_text << current_token.lexeme << current_token.trailing_trivia
                advance_raw
                
                break if brace_depth.zero?
              end
            else
              decl_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            end
          end
          
          declarators << decl_text
          
          # Check for comma (more declarators)
          if current_token.kind == :comma
            separator = current_token.lexeme.dup
            separator << current_token.trailing_trivia
            advance_raw
            declarator_separators << separator
          else
            break
          end
        end
        
        # Consume semicolon
        _semicolon_prefix = current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
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
        using_suffix = current_token.trailing_trivia
        expect(:keyword_using)
        
        # Check if it's 'using namespace'
        if current_token.kind == :keyword_namespace
          namespace_suffix = current_token.trailing_trivia
          advance_raw  # consume 'namespace'
          
          # Parse namespace name (can be nested like std::chrono)
          name = "".dup
          name_suffix = ""
          loop do
            unless current_token.kind == :identifier
              raise ParseError, "Expected namespace name"
            end
            
            name << current_token.lexeme
            trivia_before_colon = current_token.trailing_trivia
            advance_raw
            
            # Check for ::
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
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
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
          trivia_before_colon = current_token.trailing_trivia
          advance_raw
          
          # Check for ::
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
        after_name_extra = current_leading_trivia
        if current_token.kind == :equals
          equals_prefix = after_name + after_name_extra
          equals_suffix = current_token.trailing_trivia
          advance_raw  # consume '='
          
          # Parse target type (collect as string until semicolon)
          alias_target = "".dup
          until current_token.kind == :semicolon || at_end?
            alias_target << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          
          # Consume semicolon
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
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
          _semicolon_prefix = after_name + after_name_extra + current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
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
        template_suffix = current_token.trailing_trivia
        expect(:keyword_template)
        
        # Consume '<'
        less_suffix = current_token.trailing_trivia
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
            params << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          when :greater
            depth -= 1
            if depth == 0
              break
            else
              params << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            end
          else
            params << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '>'
        params_suffix = current_token.trailing_trivia
        expect(:greater)
        
        # Parse the templated declaration (function, class, struct)
        inner_leading = current_leading_trivia
        declaration, trailing = parse_statement(inner_leading)
        
        stmt = Nodes::TemplateDeclaration.new(
          leading_trivia: leading_trivia,
          template_params: params,
          declaration: declaration,
          template_suffix: template_suffix,
          less_suffix: less_suffix,
          params_suffix: params_suffix
        )
        
        [stmt, trailing]
      end
      
      # Parse enum declaration: `enum Color { Red, Green };` or `enum class Color { Red, Green };`
      # Returns (EnumDeclaration, trailing) tuple
      def parse_enum_declaration(leading_trivia)
        # Consume 'enum'
        enum_suffix = current_token.trailing_trivia
        expect(:keyword_enum)
        
        # Check for 'class' or 'struct' keyword
        class_keyword = ""
        class_suffix = ""
        if [:keyword_class, :keyword_struct].include?(current_token.kind)
          class_keyword = current_token.lexeme
          class_suffix = current_token.trailing_trivia

          advance_raw
        end
        
        # Parse name (optional for anonymous enums)
        name = ""
        name_suffix = ""
        if current_token.kind == :identifier
          name = current_token.lexeme
          name_suffix = current_token.trailing_trivia

          advance_raw
        end
        
        # Check for base type: `: int`
        if current_token.kind == :colon
          name_suffix << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          # Collect base type until {
          until current_token.kind == :lbrace || at_end?
            name_suffix << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Collect enumerators as text until '}'
        enumerators = "".dup
        until current_token.kind == :rbrace || at_end?
          enumerators << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        # Collect trivia before '}'
        rbrace_suffix = current_leading_trivia
        
        # Consume '}'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
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