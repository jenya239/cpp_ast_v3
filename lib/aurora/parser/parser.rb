# frozen_string_literal: true

require_relative "lexer"
require_relative "../ast/nodes"

module Aurora
  module Parser
    class Parser
      def initialize(source, filename: nil)
        @lexer = Lexer.new(source, filename: filename)
        @tokens = @lexer.tokenize
        @pos = 0
        @last_token = nil
      end
      
      def parse
        parse_program
      end
      
      private
      
      def parse_program
        module_decl = nil
        imports = []
        declarations = []

        # Parse optional module declaration
        if current.type == :MODULE
          module_decl = parse_module_decl
          # Skip any remaining tokens on the module line (for malformed input like module app/geom)
          while !eof? && current.type != :FN && current.type != :TYPE && current.type != :IMPORT
            @pos += 1
          end
        end

        # Parse imports
        while current.type == :IMPORT
          imports << parse_import_decl
        end

        # Parse declarations
        while !eof?
          case current.type
          when :EXPORT
            # Parse exported declaration
            consume(:EXPORT)
            case current.type
            when :FN
              func = parse_function
              func.instance_variable_set(:@exported, true)
              declarations << func
            when :TYPE
              type_decl = parse_type_decl
              type_decl.instance_variable_set(:@exported, true)
              declarations << type_decl
            else
              raise "Expected FN or TYPE after export, got #{current.type}"
            end
          when :FN
            declarations << parse_function
          when :TYPE
            declarations << parse_type_decl
          else
            break
          end
        end

        AST::Program.new(
          module_decl: module_decl,
          imports: imports,
          declarations: declarations
        )
      end

      def parse_module_decl
        module_token = consume(:MODULE)
        path = parse_module_path
        with_origin(module_token) { AST::ModuleDecl.new(name: path) }
      end

      def parse_import_decl
        import_token = consume(:IMPORT)

        # Four syntaxes:
        # 1. import { add, subtract } from "./math"  (ESM with file path)
        # 2. import * as Math from "./math"          (ESM wildcard with file path)
        # 3. import Math (backward compat - module name)
        # 4. import Math::{...} (backward compat - module name with selective)

        items = nil
        import_all = false
        alias_name = nil
        path = nil

        if current.type == :LBRACE
          # Syntax 1: import { add, subtract } from "./math"
          consume(:LBRACE)
          items = []
          loop do
            items << consume(:IDENTIFIER).value
            break if current.type != :COMMA
            consume(:COMMA)
          end
          consume(:RBRACE)
          consume(:FROM)
          path = parse_import_path  # Can be string or identifier
        elsif current.type == :OPERATOR && current.value == "*"
          # Syntax 2: import * as Math from "./math"
          consume(:OPERATOR)  # *
          consume(:AS)
          alias_name = consume(:IDENTIFIER).value
          consume(:FROM)
          path = parse_import_path  # Can be string or identifier
          import_all = true
        else
          # Syntax 3-4 (backward compat): import Math or import Math::{...}
          path = parse_module_path

          # Check for old-style selective imports: import Math::{sqrt, pow}
          if current.type == :COLON
            consume(:COLON)
            consume(:COLON)
            consume(:LBRACE)
            items = []
            loop do
              items << consume(:IDENTIFIER).value
              break if current.type != :COMMA
              consume(:COMMA)
            end
            consume(:RBRACE)
          end
        end

        with_origin(import_token) do
          AST::ImportDecl.new(
            path: path,
            items: items,
            import_all: import_all,
            alias_name: alias_name
          )
        end
      end

      def parse_import_path
        # Can be string literal (ESM-style) or identifier (backward compat)
        if current.type == :STRING_LITERAL
          consume(:STRING_LITERAL).value
        else
          parse_module_path
        end
      end

      def parse_module_path
        # Parse path like Math::Vector or just Math
        result = consume(:IDENTIFIER).value.dup

        loop do
          if current.type == :COLON && peek_ahead(1)&.type == :COLON && peek_ahead(2)&.type == :IDENTIFIER
            consume(:COLON)
            consume(:COLON)
            result << "::"
            result << consume(:IDENTIFIER).value
          elsif current.type == :OPERATOR && current.value == "/" && peek_ahead(1)&.type == :IDENTIFIER
            consume(:OPERATOR)  # /
            result << "/"
            result << consume(:IDENTIFIER).value
          else
            break
          end
        end

        result
      end

      def peek_ahead(offset)
        @tokens[@pos + offset] if @pos + offset < @tokens.length
      end
      
      def parse_function
        consume(:FN)
        name_token = consume(:IDENTIFIER)
        name = name_token.value

        # Parse optional type parameters: fn identity<T>(x: T) -> T
        type_params = []
        if current.type == :OPERATOR && current.value == "<"
          consume(:OPERATOR)  # <
          type_params = parse_type_params
          expect_operator(">")
        end

        consume(:LPAREN)
        params = parse_params
        consume(:RPAREN)

        consume(:ARROW)
        ret_type = parse_type

        consume(:EQUAL)
        body = parse_expression

        with_origin(name_token) do
          AST::FuncDecl.new(
            name: name,
            params: params,
            ret_type: ret_type,
            body: body,
            type_params: type_params
          )
        end
      end
      
      def parse_params
        params = []
        
        while current.type != :RPAREN
          name_token = consume(:IDENTIFIER)
          name = name_token.value
          consume(:COLON)
          type = parse_type
          
          params << with_origin(name_token) { AST::Param.new(name: name, type: type) }
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        params
      end
      
      def parse_type_decl
        consume(:TYPE)
        name_token = consume(:IDENTIFIER)
        name = name_token.value

        # Parse optional type parameters: type Option<T> = ...
        type_params = []
        if current.type == :OPERATOR && current.value == "<"
          consume(:OPERATOR)  # <
          type_params = parse_type_params
          expect_operator(">")
        end

        consume(:EQUAL)

        type = case current.type
               when :LBRACE
                 parse_record_type
               when :ENUM
                 parse_enum_type
               when :OPERATOR
                 if current.value == "|"
                   parse_sum_type
                 else
                   parse_type
                 end
               when :IDENTIFIER
                 # Could be sum type (Variant1 | Variant2) or named type
                 # Look ahead to see if there's a | after the identifier
                 parse_type_or_sum
               else
                 parse_type
               end

        with_origin(name_token) { AST::TypeDecl.new(name: name, type: type, type_params: type_params) }
      end

      def parse_type_params
        # Parse comma-separated list of type parameters: T, E, R or T: Constraint
        params = []
        loop do
          name_token = consume(:IDENTIFIER)
          name = name_token.value
          constraint = nil

          if current.type == :COLON
            consume(:COLON)

            if current.type == :IDENTIFIER
              constraint = consume(:IDENTIFIER).value
            else
              raise "Expected constraint identifier, got #{current.type}(#{current.value})"
            end
          end

          params << with_origin(name_token) { AST::TypeParam.new(name: name, constraint: constraint) }

          break unless current.type == :COMMA
          consume(:COMMA)
        end
        params
      end

      def expect_operator(op)
        if current.type == :OPERATOR && current.value == op
          consume(:OPERATOR)
        else
          raise "Expected operator '#{op}', got #{current.type}(#{current.value})"
        end
      end

      def parse_type_or_sum
        # Try parsing as sum type first
        start_pos = @pos
        first_variant_name = consume(:IDENTIFIER).value

        # Check if this is a sum type variant
        # Patterns: Variant(...) or Variant {...} or Variant | ...
        is_sum_type = current.type == :LPAREN ||
                      (current.type == :LBRACE && peek_for_sum_type?) ||
                      (current.type == :OPERATOR && current.value == "|")

        if is_sum_type
          # Reset and parse as sum type
          @pos = start_pos
          return parse_sum_type
        end

        # Otherwise, it's just a type reference
        @pos = start_pos
        parse_type
      end

      def peek_for_sum_type?
        # Look ahead to see if this is a sum type variant with named fields
        # Check if after { there's eventually a | (indicating more variants)
        saved_pos = @pos
        depth = 0

        while @pos < @tokens.size
          case current.type
          when :LBRACE
            depth += 1
          when :RBRACE
            depth -= 1
            if depth == 0
              @pos += 1
              # After closing brace, check for | indicating another variant
              result = current.type == :OPERATOR && current.value == "|"
              @pos = saved_pos
              return result
            end
          end
          @pos += 1
        end

        @pos = saved_pos
        false
      end
      
      def parse_type
        base_token = nil
        base_type = case current.type
                    when :I32
                      base_token = consume(:I32)
                      with_origin(base_token) { AST::PrimType.new(name: "i32") }
                    when :F32
                      base_token = consume(:F32)
                      with_origin(base_token) { AST::PrimType.new(name: "f32") }
                    when :BOOL
                      base_token = consume(:BOOL)
                      with_origin(base_token) { AST::PrimType.new(name: "bool") }
                    when :VOID
                      base_token = consume(:VOID)
                      with_origin(base_token) { AST::PrimType.new(name: "void") }
                    when :STR
                      base_token = consume(:STR)
                      with_origin(base_token) { AST::PrimType.new(name: "str") }
                    when :IDENTIFIER
                      base_token = consume(:IDENTIFIER)
                      name = base_token.value
                      with_origin(base_token) { AST::PrimType.new(name: name) }
                    when :LBRACE
                      base_type = parse_record_type
                      base_token = @last_token
                      base_type
                    else
                      raise "Unexpected token: #{current}"
                    end

        # Check for generic type parameters <T1, T2, ...>
        if current.type == :OPERATOR && current.value == "<"
          consume_operator("<")
          type_params = []

          loop do
            type_params << parse_type
            break unless current.type == :COMMA
            consume(:COMMA)
          end

          consume_operator(">")

          base_type = with_origin(base_token) do
            AST::GenericType.new(
              base_type: base_type,
              type_params: type_params
            )
          end
        end

        # Check for array type suffix []
        if current.type == :LBRACKET
          lbracket_token = consume(:LBRACKET)
          consume(:RBRACKET)
          with_origin(lbracket_token) { AST::ArrayType.new(element_type: base_type) }
        else
          base_type
        end
      end

      def consume_operator(expected_value)
        if current.type != :OPERATOR || current.value != expected_value
          raise "Expected operator #{expected_value}, got #{current.type}:#{current.value}"
        end
        token = current
        @pos += 1
        @last_token = token
        token
      end
      
      def parse_record_type
        lbrace_token = consume(:LBRACE)
        fields = []

        while current.type != :RBRACE
          field_name = consume(:IDENTIFIER).value
          consume(:COLON)
          field_type = parse_type

          fields << {name: field_name, type: field_type}

          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end

        consume(:RBRACE)
        with_origin(lbrace_token) { AST::RecordType.new(name: "record", fields: fields) }
      end

      def parse_enum_type
        enum_token = consume(:ENUM)
        consume(:LBRACE)
        variants = []

        while current.type != :RBRACE
          variant_name = consume(:IDENTIFIER).value
          variants << variant_name

          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end

        consume(:RBRACE)
        with_origin(enum_token) { AST::EnumType.new(name: "enum", variants: variants) }
      end

      def parse_sum_type
        variants = []
        sum_origin_token = nil

        # Parse first variant (may or may not have leading |)
        if current.type == :OPERATOR && current.value == "|"
          consume(:OPERATOR)
        end

        loop do
          name_token = consume(:IDENTIFIER)
          sum_origin_token ||= name_token
          variant_name = name_token.value
          variant_fields = []

          # Check if variant has fields
          if current.type == :LPAREN
            # Tuple-like variant: Circle(f32, f32)
            consume(:LPAREN)
            field_index = 0
            while current.type != :RPAREN
              field_type = parse_type
              # Generate field name for tuple-like variants
              variant_fields << {name: "field#{field_index}", type: field_type}
              field_index += 1

              if current.type == :COMMA
                consume(:COMMA)
              else
                break
              end
            end
            consume(:RPAREN)
          elsif current.type == :LBRACE
            # Named fields variant: Ok { value: i32 }
            consume(:LBRACE)
            while current.type != :RBRACE
              field_name = consume(:IDENTIFIER).value
              consume(:COLON)
              field_type = parse_type
              variant_fields << {name: field_name, type: field_type}

              if current.type == :COMMA
                consume(:COMMA)
              else
                break
              end
            end
            consume(:RBRACE)
          end

          variants << {name: variant_name, fields: variant_fields}

          # Check for next variant
          break unless current.type == :OPERATOR && current.value == "|"
          consume(:OPERATOR)  # consume |
        end

        with_origin(sum_origin_token) { AST::SumType.new(name: "sum", variants: variants) }
      end
      
      def parse_expression
        if current.type == :MATCH
          parse_match_expression
        else
          parse_let_expression
        end
      end
      
      def parse_let_expression
        return parse_if_expression unless current.type == :LET

        consume(:LET)
        mutable = false
        if current.type == :MUT
          consume(:MUT)
          mutable = true
        end

        name_token = consume(:IDENTIFIER)
        name = name_token.value
        consume(:EQUAL)
        value = parse_if_expression

        unless current.type == :SEMICOLON
          body = parse_expression
          return with_origin(name_token) { AST::Let.new(name: name, value: value, body: body, mutable: mutable) }
        end

        consume(:SEMICOLON)
        statements = [with_origin(name_token) { AST::VariableDecl.new(name: name, value: value, mutable: mutable) }]
        block = parse_statement_sequence(statements)
        ensure_block_has_result(block, require_value: false)
        block
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

      def parse_if_expression
        if current.type == :IF
          if_token = consume(:IF)
          condition = parse_logical_or
          consume(:THEN) if current.type == :THEN
          then_branch = parse_if_branch_expression

          else_branch = nil
          if current.type == :ELSE
            consume(:ELSE)
            else_branch = parse_if_branch_expression
          end

          with_origin(if_token) { AST::IfExpr.new(condition: condition, then_branch: then_branch, else_branch: else_branch) }
        else
          parse_logical_or
        end
      end

      def parse_if_branch_expression
        if current.type == :LBRACE
          parse_block_expression
        else
          parse_if_expression
        end
      end

      def parse_match_scrutinee
        # Parse scrutinee for match expression - special handling to avoid
        # consuming { as record literal when it's actually the start of match arms
        # We parse at comparison level to get most operators but stop before
        # consuming record literals
        left = parse_comparison

        # Don't parse record literal here - that's handled by match arms
        # Just return the identifier/expression
        left
      end

      def parse_match_expression
        match_token = consume(:MATCH)
        scrutinee = parse_match_scrutinee

        arms = []

        # Check for brace-style or pipe-style match
        if current.type == :LBRACE
          # Brace style: match expr { pattern => body, ... }
          consume(:LBRACE)

          while current.type != :RBRACE
            # Parse pattern
            pattern = parse_pattern

            # Parse guard (optional: "if condition")
            guard = nil
            if current.type == :IF
              consume(:IF)
              guard = parse_equality
            end

            # Expect =>
            if current.type == :FAT_ARROW
              consume(:FAT_ARROW)
            else
              raise "Expected => in match arm"
            end

            # Parse body
            body = parse_if_expression

            arms << {pattern: pattern, guard: guard, body: body}

            # Expect comma or closing brace
            if current.type == :COMMA
              consume(:COMMA)
            elsif current.type != :RBRACE
              raise "Expected , or } in match expression"
            end
          end

          consume(:RBRACE)
        else
          # Pipe style: match expr | pattern => body | ...
          while current.type == :OPERATOR && current.value == "|"
            consume(:OPERATOR)  # consume |

            # Parse pattern
            pattern = parse_pattern

            # Parse guard (optional: "if condition")
            guard = nil
            if current.type == :IF
              consume(:IF)
              guard = parse_equality
            end

            # Expect =>
            if current.type == :FAT_ARROW
              consume(:FAT_ARROW)
            elsif current.type == :OPERATOR && current.value == "=>"
              # Fallback for old lexer compatibility
              consume(:OPERATOR)
            else
              raise "Expected => in match arm"
            end

            # Parse body
            body = parse_if_expression

            arms << {pattern: pattern, guard: guard, body: body}
          end
        end

        with_origin(match_token) { AST::MatchExpr.new(scrutinee: scrutinee, arms: arms) }
      end

      def parse_pattern
        case current.type
        when :UNDERSCORE, :OPERATOR
          if current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
            token = current
            consume(current.type)
            return with_origin(token) { AST::Pattern.new(kind: :wildcard, data: {}) }
          end
          raise "Unexpected operator in pattern: #{current.value}"
        when :REGEX
          regex_token = consume(:REGEX)
          regex_data = regex_token.value
          bindings = []

          if current.type == :AS
            consume(:AS)

            if current.type == :LBRACKET
              consume(:LBRACKET)

              while current.type != :RBRACKET
                if current.type == :IDENTIFIER
                  bindings << consume(:IDENTIFIER).value
                elsif current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
                  consume(current.type)
                  bindings << "_"
                else
                  raise "Expected identifier or _ in regex bindings"
                end

                if current.type == :COMMA
                  consume(:COMMA)
                else
                  break
                end
              end

              consume(:RBRACKET)
            end
          end

          return with_origin(regex_token) do
            AST::Pattern.new(
              kind: :regex,
              data: {
                pattern: regex_data[:pattern],
                flags: regex_data[:flags],
                bindings: bindings
              }
            )
          end
        when :INT_LITERAL
          token = consume(:INT_LITERAL)
          value = token.value.to_i
          return with_origin(token) { AST::Pattern.new(kind: :literal, data: {value: value}) }
        when :FLOAT_LITERAL
          token = consume(:FLOAT_LITERAL)
          value = token.value.to_f
          return with_origin(token) { AST::Pattern.new(kind: :literal, data: {value: value}) }
        when :IDENTIFIER
          constructor_token = consume(:IDENTIFIER)
          constructor = constructor_token.value

          if current.type == :LPAREN
            consume(:LPAREN)
            fields = []

            while current.type != :RPAREN
              if current.type == :IDENTIFIER
                field_name = consume(:IDENTIFIER).value
                fields << field_name
              elsif current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
                consume(current.type)
                fields << "_"
              else
                raise "Expected identifier or _ in pattern, got #{current.type}"
              end

              if current.type == :COMMA
                consume(:COMMA)
              else
                break
              end
            end

            consume(:RPAREN)

            return with_origin(constructor_token) do
              AST::Pattern.new(
                kind: :constructor,
                data: {name: constructor, fields: fields}
              )
            end
          elsif current.type == :LBRACE
            consume(:LBRACE)
            bindings = []

            while current.type != :RBRACE
              binding_name = consume(:IDENTIFIER).value
              bindings << binding_name

              if current.type == :COMMA
                consume(:COMMA)
              else
                break
              end
            end

            consume(:RBRACE)

            return with_origin(constructor_token) do
              AST::Pattern.new(
                kind: :constructor,
                data: {name: constructor, fields: bindings}
              )
            end
          else
            return with_origin(constructor_token) do
              if constructor == "_"
                AST::Pattern.new(kind: :wildcard, data: {})
              elsif constructor[0] == constructor[0].upcase
                AST::Pattern.new(
                  kind: :constructor,
                  data: {name: constructor, fields: []}
                )
              else
                AST::Pattern.new(kind: :var, data: {name: constructor})
              end
            end
          end
        else
          raise "Unexpected token in pattern: #{current}"
        end
      end
      
      def parse_logical_or
        left = parse_logical_and

        while current.type == :OPERATOR && current.value == "||"
          token = consume(:OPERATOR)
          right = parse_logical_and
          node = AST::BinaryOp.new(op: "||", left: left, right: right)
          left = attach_origin(node, token)
        end

        left
      end

      def parse_logical_and
        left = parse_equality

        while current.type == :OPERATOR && current.value == "&&"
          token = consume(:OPERATOR)
          right = parse_equality
          node = AST::BinaryOp.new(op: "&&", left: left, right: right)
          left = attach_origin(node, token)
        end

        left
      end

      def parse_equality
        left = parse_pipe

        while current.type == :OPERATOR && %w[== !=].include?(current.value)
          token = consume(:OPERATOR)
          op = token.value
          right = parse_pipe
          node = AST::BinaryOp.new(op: op, left: left, right: right)
          left = attach_origin(node, token)
        end

        left
      end

      def parse_pipe
        left = parse_comparison

        while current.type == :PIPE || (current.type == :OPERATOR && current.value == "|>")
          token = consume(current.type)  # Consume PIPE or OPERATOR
          right = parse_comparison
          node = AST::BinaryOp.new(op: "|>", left: left, right: right)
          left = attach_origin(node, token)
        end

        left
      end
      
      def parse_comparison
        left = parse_addition
        
        while current.type == :OPERATOR && %w[< > <= >=].include?(current.value)
          token = consume(:OPERATOR)
          op = token.value
          right = parse_addition
          node = AST::BinaryOp.new(op: op, left: left, right: right)
          left = attach_origin(node, token)
        end
        
        left
      end
      
      def parse_addition
        left = parse_multiplication
        
        while current.type == :OPERATOR && %w[+ -].include?(current.value)
          token = consume(:OPERATOR)
          op = token.value
          right = parse_multiplication
          node = AST::BinaryOp.new(op: op, left: left, right: right)
          left = attach_origin(node, token)
        end
        
        left
      end
      
      def parse_multiplication
        left = parse_unary

        while current.type == :OPERATOR && %w[* / %].include?(current.value)
          token = consume(:OPERATOR)
          op = token.value
          right = parse_unary
          node = AST::BinaryOp.new(op: op, left: left, right: right)
          left = attach_origin(node, token)
        end

        left
      end

      def parse_unary
        # Check for unary operators: !, -, +
        if current.type == :OPERATOR && %w[! - +].include?(current.value)
          token = consume(:OPERATOR)
          op = token.value
          operand = parse_unary  # Right-associative
          attach_origin(AST::UnaryOp.new(op: op, operand: operand), token)
        else
          parse_postfix
        end
      end

      def parse_postfix
        expr = parse_primary
        expr_line = last_token&.line

        # Handle member access, method calls, and array indexing
        loop do
          case current.type
          when :OPERATOR
            if current.value == "."
              consume(:OPERATOR) # consume '.'
              member_token = consume(:IDENTIFIER)
              member = member_token.value
              member_line = member_token.line

              # Check if it's a method call: obj.method()
              # Only treat LPAREN as method call if it's on the same line as the member name
              if current.type == :LPAREN && current.line == member_line
                consume(:LPAREN)
                args = parse_args
                consume(:RPAREN)
                # Create a call with member access as callee
                member_access = attach_origin(AST::MemberAccess.new(object: expr, member: member), member_token)
                expr = attach_origin(AST::Call.new(callee: member_access, args: args), member_token)
              else
                # Just member access: obj.field
                expr = attach_origin(AST::MemberAccess.new(object: expr, member: member), member_token)
              end
              expr_line = last_token&.line
            else
              break
            end
          when :LBRACKET
            # Array indexing: expr[index]
            lbracket_token = consume(:LBRACKET)
            index = parse_expression
            consume(:RBRACKET)
            expr = attach_origin(AST::IndexAccess.new(object: expr, index: index), lbracket_token)
            expr_line = last_token&.line
          when :LPAREN
            paren_line = current.line
            break unless expr_line && paren_line == expr_line
            lparen_token = consume(:LPAREN)
            args = parse_args
            consume(:RPAREN)
            expr = attach_origin(AST::Call.new(callee: expr, args: args), lparen_token)
            expr_line = last_token&.line
          else
            break
          end
        end

        expr
      end

      def parse_primary
        case current.type
        when :FOR
          parse_for_loop
        when :WHILE
          parse_while_loop
        when :INT_LITERAL
          token = consume(:INT_LITERAL)
          value = token.value
          attach_origin(AST::IntLit.new(value: value), token)
        when :FLOAT_LITERAL
          token = consume(:FLOAT_LITERAL)
          value = token.value
          attach_origin(AST::FloatLit.new(value: value), token)
        when :STRING_LITERAL
          token = consume(:STRING_LITERAL)
          value = token.value
          attach_origin(AST::StringLit.new(value: value), token)
        when :REGEX
          token = consume(:REGEX)
          regex_data = token.value
          attach_origin(AST::RegexLit.new(pattern: regex_data[:pattern], flags: regex_data[:flags]), token)
        when :IDENTIFIER
          # Check for lambda: x => expr
          if peek && peek.type == :FAT_ARROW
            parse_lambda
          else
            name_token = consume(:IDENTIFIER)
            name = name_token.value

            if current.type == :LPAREN
              # Function call
              lparen_token = consume(:LPAREN)
              args = parse_args
              consume(:RPAREN)
              callee = attach_origin(AST::VarRef.new(name: name), name_token)
              attach_origin(AST::Call.new(callee: callee, args: args), lparen_token)
            elsif current.type == :LBRACE && !looks_like_match_arms?
              # Record literal (but not match arms)
              lbrace_token = consume(:LBRACE)
              fields = parse_record_fields
              consume(:RBRACE)
              attach_origin(AST::RecordLit.new(type_name: name, fields: fields), lbrace_token)
            else
              # Variable reference
              attach_origin(AST::VarRef.new(name: name), name_token)
            end
          end
        when :LPAREN
          # Could be lambda or grouped expression
          # Lookahead to determine
          if looks_like_lambda?
            parse_lambda
          else
            consume(:LPAREN)
            expr = parse_expression
            consume(:RPAREN)
            expr
          end
        when :LBRACE
          # Anonymous record literal
          lbrace_token = consume(:LBRACE)
          fields = parse_record_fields
          consume(:RBRACE)
          attach_origin(AST::RecordLit.new(type_name: "record", fields: fields), lbrace_token)
        when :LBRACKET
          parse_array_literal_or_comprehension
        else
          raise "Unexpected token: #{current}"
        end
      end

      # Parse for loops
      def parse_for_loop
        for_token = consume(:FOR)
        var_token = consume(:IDENTIFIER)
        var_name = var_token.value
        consume(:IN)
        iterable = parse_if_expression
        consume(:DO)
        body = if current.type == :LBRACE
                 parse_block_expression
               else
                 parse_expression
               end

        with_origin(for_token) do
          AST::ForLoop.new(
            var_name: var_name,
            iterable: iterable,
            body: body
          )
        end
      end

      def parse_while_loop
        while_token = consume(:WHILE)
        condition = parse_if_expression
        consume(:DO)
        body = if current.type == :LBRACE
                 parse_block_expression
               else
                 parse_expression
               end

        with_origin(while_token) do
          AST::WhileLoop.new(
            condition: condition,
            body: body
          )
        end
      end

      # Parse lambda expressions
      def parse_lambda
        if current.type == :IDENTIFIER && peek && peek.type == :FAT_ARROW
          # Single parameter: x => expr
          param_token = consume(:IDENTIFIER)
          param_name = param_token.value
          consume(:FAT_ARROW)
          body = parse_if_expression

          param = with_origin(param_token) { AST::LambdaParam.new(name: param_name) }
          with_origin(param_token) { AST::Lambda.new(params: [param], body: body) }

        elsif current.type == :LPAREN
          # Multiple parameters: (x, y) => expr or (x: i32, y: i32) => expr
          lparen_token = consume(:LPAREN)
          params = parse_lambda_params
          consume(:RPAREN)
          consume(:FAT_ARROW)
          body = parse_lambda_body

          with_origin(lparen_token) { AST::Lambda.new(params: params, body: body) }
        else
          raise "Expected lambda expression"
        end
      end

      def parse_lambda_params
        params = []

        while current.type != :RPAREN
          name_token = consume(:IDENTIFIER)
          name = name_token.value
          param_type = nil

          if current.type == :COLON
            consume(:COLON)
            param_type = parse_type
          end

          params << with_origin(name_token) { AST::LambdaParam.new(name: name, type: param_type) }

          break unless current.type == :COMMA
          consume(:COMMA)
        end

        params
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

      def parse_variable_decl_statement
        consume(:LET)
        mutable = false
        if current.type == :MUT
          consume(:MUT)
          mutable = true
        end

        name_token = consume(:IDENTIFIER)
        name = name_token.value
        consume(:EQUAL)
        value = parse_expression
        consume(:SEMICOLON) if current.type == :SEMICOLON

        with_origin(name_token) { AST::VariableDecl.new(name: name, value: value, mutable: mutable) }
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

      def parse_return_statement
        return_token = consume(:RETURN)
        expr = nil
        unless current.type == :SEMICOLON || current.type == :RBRACE || current.type == :EOF
          expr = parse_expression
        end
        consume(:SEMICOLON) if current.type == :SEMICOLON

        with_origin(return_token) { AST::Return.new(expr: expr) }
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

      def ensure_block_has_result(block, require_value: true)
        return unless require_value
        return if block.stmts.last.is_a?(AST::ExprStmt)

        raise "Block must end with an expression"
      end
      def parse_lambda_body
        if current.type == :LBRACE
          # Block body: { stmts }
          consume(:LBRACE)
          body = parse_expression
          consume(:RBRACE)
          body
        else
          # Single expression
          parse_if_expression
        end
      end

      # Check if we're looking at a lambda
      def looks_like_lambda?
        # Save position
        saved_pos = @pos

        return false unless current.type == :LPAREN

        @pos += 1  # Skip (

        # Skip params
        while !eof? && current.type != :RPAREN && current.type != :FAT_ARROW
          @pos += 1
        end

        # Check if we find =>
        found_arrow = false
        if current.type == :RPAREN
          @pos += 1
          found_arrow = current.type == :FAT_ARROW
        end

        # Restore position
        @pos = saved_pos
        found_arrow
      end

      # Parse array literal or list comprehension
      def parse_array_literal_or_comprehension
        lbracket_token = consume(:LBRACKET)

        # Empty array
        if current.type == :RBRACKET
          consume(:RBRACKET)
          return with_origin(lbracket_token) { AST::ArrayLiteral.new(elements: []) }
        end

        # Parse first expression
        first_expr = parse_if_expression

        if current.type == :FOR
          # It's a comprehension: [expr for var in iterable]
          generators = []
          filters = []

          while current.type == :FOR
            for_token = consume(:FOR)
            var_token = consume(:IDENTIFIER)
            var_name = var_token.value
            consume(:IN)
            iterable = parse_if_expression

            generators << with_origin(for_token) do
              AST::Generator.new(
                var_name: var_name,
                iterable: iterable
              )
            end

            # Check for filter
            if current.type == :IF
              consume(:IF)
              filters << parse_if_expression
            end
          end

          consume(:RBRACKET)

          with_origin(lbracket_token) do
            AST::ListComprehension.new(
              output_expr: first_expr,
              generators: generators,
              filters: filters
            )
          end
        else
          # Regular array literal
          elements = [first_expr]

          while current.type == :COMMA
            consume(:COMMA)
            break if current.type == :RBRACKET  # Trailing comma
            elements << parse_if_expression
          end

          consume(:RBRACKET)

          with_origin(lbracket_token) { AST::ArrayLiteral.new(elements: elements) }
        end
      end
      
      def parse_args
        args = []
        
        while current.type != :RPAREN
          args << parse_expression
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        args
      end
      
      def parse_record_fields
        fields = {}
        
        while current.type != :RBRACE
          field_name = consume(:IDENTIFIER).value
          consume(:COLON)
          value = parse_expression
          
          fields[field_name] = value
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        fields
      end

      def looks_like_match_arms?
        # Lookahead to determine if { starts match arms or record literal
        # Match arms start with patterns: /, _, uppercase IDENTIFIER, lowercase identifier, etc.
        # Record literals start with: lowercase_identifier :
        return false unless current.type == :LBRACE

        next_token = peek
        return false unless next_token

        # If next token is /, _, or RBRACE, it's match arms
        return true if next_token.type == :REGEX
        return true if next_token.type == :UNDERSCORE
        return true if next_token.type == :RBRACE

        # If next token is IDENTIFIER followed by :, it's a record field
        # If next token is IDENTIFIER followed by =>, it's a match arm
        if next_token.type == :IDENTIFIER
          token_after_next = @tokens[@pos + 2] if @pos + 2 < @tokens.length
          return false if token_after_next && token_after_next.type == :COLON
          return true if token_after_next && token_after_next.type == :FAT_ARROW

          # Otherwise, assume it's a match arm if identifier is uppercase (constructor pattern)
          # or lowercase (variable binding pattern)
          return true
        end

        false
      end

      def current
        @tokens[@pos]
      end

      def peek
        @tokens[@pos + 1] if @pos + 1 < @tokens.length
      end

      def eof?
        @pos >= @tokens.length || current.type == :EOF
      end

      def consume(expected_type)
        if eof?
          raise "Unexpected EOF, expected #{expected_type}"
        end

        token = current
        if token.type != expected_type
          raise "Expected #{expected_type}, got #{token.type}"
        end

        @pos += 1
        @last_token = token
        token
      end

      def last_token
        @last_token
      end

      def origin_from(token)
        return nil unless token

        SourceOrigin.new(
          file: token.file,
          line: token.line,
          column: token.column
        )
      end

      def attach_origin(node, token)
        return node unless node.is_a?(Aurora::AST::Node)
        origin = case token
                 when SourceOrigin
                   token
                 else
                   origin_from(token)
                 end
        return node unless origin
        node.instance_variable_set(:@origin, origin)
        node
      end

      def with_origin(token)
        node = yield
        attach_origin(node, token)
      end
    end
  end
end
