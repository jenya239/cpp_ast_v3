# frozen_string_literal: true

require_relative "lexer"
require_relative "../ast/nodes"

module Aurora
  module Parser
    class Parser
      def initialize(source)
        @lexer = Lexer.new(source)
        @tokens = @lexer.tokenize
        @pos = 0
      end
      
      def parse
        parse_program
      end
      
      private
      
      def parse_program
        declarations = []

        while !eof?
          case current.type
          when :MODULE
            # Skip module declarations for now - consume until we find FN or TYPE
            @pos += 1  # skip MODULE keyword
            # Skip tokens until we find a top-level declaration
            while !eof? && current.type != :FN && current.type != :TYPE
              @pos += 1
            end
          when :FN
            declarations << parse_function
          when :TYPE
            declarations << parse_type_decl
          else
            break
          end
        end

        AST::Program.new(declarations: declarations)
      end
      
      def parse_function
        consume(:FN)
        name = consume(:IDENTIFIER).value

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

        AST::FuncDecl.new(
          name: name,
          params: params,
          ret_type: ret_type,
          body: body,
          type_params: type_params
        )
      end
      
      def parse_params
        params = []
        
        while current.type != :RPAREN
          name = consume(:IDENTIFIER).value
          consume(:COLON)
          type = parse_type
          
          params << AST::Param.new(name: name, type: type)
          
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
        name = consume(:IDENTIFIER).value

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

        AST::TypeDecl.new(name: name, type: type, type_params: type_params)
      end

      def parse_type_params
        # Parse comma-separated list of type parameters: T, E, R
        params = []
        loop do
          params << consume(:IDENTIFIER).value
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
        base_type = case current.type
                    when :I32
                      consume(:I32)
                      AST::PrimType.new(name: "i32")
                    when :F32
                      consume(:F32)
                      AST::PrimType.new(name: "f32")
                    when :BOOL
                      consume(:BOOL)
                      AST::PrimType.new(name: "bool")
                    when :VOID
                      consume(:VOID)
                      AST::PrimType.new(name: "void")
                    when :STR
                      consume(:STR)
                      AST::PrimType.new(name: "str")
                    when :IDENTIFIER
                      name = consume(:IDENTIFIER).value
                      AST::PrimType.new(name: name)
                    when :LBRACE
                      parse_record_type
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

          base_type = AST::GenericType.new(
            base_type: base_type,
            type_params: type_params
          )
        end

        # Check for array type suffix []
        if current.type == :LBRACKET
          consume(:LBRACKET)
          consume(:RBRACKET)
          AST::ArrayType.new(element_type: base_type)
        else
          base_type
        end
      end

      def consume_operator(expected_value)
        if current.type != :OPERATOR || current.value != expected_value
          raise "Expected operator #{expected_value}, got #{current.type}:#{current.value}"
        end
        @pos += 1
      end
      
      def parse_record_type
        consume(:LBRACE)
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
        AST::RecordType.new(name: "record", fields: fields)
      end

      def parse_enum_type
        consume(:ENUM)
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
        AST::EnumType.new(name: "enum", variants: variants)
      end

      def parse_sum_type
        variants = []

        # Parse first variant (may or may not have leading |)
        if current.type == :OPERATOR && current.value == "|"
          consume(:OPERATOR)
        end

        loop do
          variant_name = consume(:IDENTIFIER).value
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

        AST::SumType.new(name: "sum", variants: variants)
      end
      
      def parse_expression
        if current.type == :MATCH
          parse_match_expression
        else
          parse_let_expression
        end
      end
      
      def parse_let_expression
        if current.type == :LET
          consume(:LET)
          name = consume(:IDENTIFIER).value
          consume(:EQUAL)
          value = parse_if_expression
          # Skip newline if present
          if current.type == :SEMICOLON
            consume(:SEMICOLON)
          end
          body = parse_expression

          AST::Let.new(name: name, value: value, body: body)
        else
          parse_if_expression
        end
      end

      def parse_if_expression
        if current.type == :IF
          consume(:IF)
          condition = parse_equality
          consume(:THEN) if current.type == :THEN
          then_branch = parse_if_expression

          else_branch = nil
          if current.type == :ELSE
            consume(:ELSE)
            else_branch = parse_if_expression
          end

          AST::IfExpr.new(condition: condition, then_branch: then_branch, else_branch: else_branch)
        else
          parse_equality
        end
      end

      def parse_match_expression
        consume(:MATCH)
        scrutinee = parse_equality

        arms = []

        # Parse match arms
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

        AST::MatchExpr.new(scrutinee: scrutinee, arms: arms)
      end

      def parse_pattern
        case current.type
        when :UNDERSCORE, :OPERATOR
          # Wildcard pattern: _
          if current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
            consume(current.type)
            return AST::Pattern.new(kind: :wildcard, data: {})
          end
          raise "Unexpected operator in pattern: #{current.value}"
        when :INT_LITERAL
          # Literal pattern: 0, 1, 42
          value = consume(:INT_LITERAL).value.to_i
          AST::Pattern.new(kind: :literal, data: {value: value})
        when :FLOAT_LITERAL
          # Float literal pattern
          value = consume(:FLOAT_LITERAL).value.to_f
          AST::Pattern.new(kind: :literal, data: {value: value})
        when :IDENTIFIER
          constructor = consume(:IDENTIFIER).value

          # Check for constructor pattern with fields
          if current.type == :LPAREN
            # Tuple-like constructor: Circle(r) or Rect(w, h)
            consume(:LPAREN)
            fields = []

            while current.type != :RPAREN
              if current.type == :IDENTIFIER
                field_name = consume(:IDENTIFIER).value
                fields << field_name
              elsif current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
                # Wildcard field binding
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

            AST::Pattern.new(
              kind: :constructor,
              data: {name: constructor, fields: fields}
            )
          elsif current.type == :LBRACE
            # Named fields constructor: Ok { value }
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

            AST::Pattern.new(
              kind: :constructor,
              data: {name: constructor, fields: bindings}
            )
          else
            # Constructor without fields (like Point), wildcard, or variable pattern
            if constructor == "_"
              # Wildcard pattern
              AST::Pattern.new(kind: :wildcard, data: {})
            elsif constructor[0] == constructor[0].upcase
              # Constructor without fields (like Point)
              AST::Pattern.new(
                kind: :constructor,
                data: {name: constructor, fields: []}
              )
            else
              # Variable pattern
              AST::Pattern.new(kind: :var, data: {name: constructor})
            end
          end
        else
          raise "Unexpected token in pattern: #{current}"
        end
      end
      
      def parse_equality
        left = parse_pipe

        while current.type == :OPERATOR && %w[== !=].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_pipe
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end

        left
      end

      def parse_pipe
        left = parse_comparison

        while current.type == :PIPE || (current.type == :OPERATOR && current.value == "|>")
          consume(current.type)  # Consume PIPE or OPERATOR
          right = parse_comparison
          left = AST::BinaryOp.new(op: "|>", left: left, right: right)
        end

        left
      end
      
      def parse_comparison
        left = parse_addition
        
        while current.type == :OPERATOR && %w[< > <= >=].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_addition
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_addition
        left = parse_multiplication
        
        while current.type == :OPERATOR && %w[+ -].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_multiplication
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_multiplication
        left = parse_unary

        while current.type == :OPERATOR && %w[* / %].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_unary
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end

        left
      end

      def parse_unary
        # Check for unary operators: !, -, +
        if current.type == :OPERATOR && %w[! - +].include?(current.value)
          op = consume(:OPERATOR).value
          operand = parse_unary  # Right-associative
          AST::UnaryOp.new(op: op, operand: operand)
        else
          parse_postfix
        end
      end

      def parse_postfix
        expr = parse_primary

        # Handle member access and method calls
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
                member_access = AST::MemberAccess.new(object: expr, member: member)
                expr = AST::Call.new(callee: member_access, args: args)
              else
                # Just member access: obj.field
                expr = AST::MemberAccess.new(object: expr, member: member)
              end
            else
              break
            end
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
        when :INT_LITERAL
          value = consume(:INT_LITERAL).value
          AST::IntLit.new(value: value)
        when :FLOAT_LITERAL
          value = consume(:FLOAT_LITERAL).value
          AST::FloatLit.new(value: value)
        when :STRING_LITERAL
          value = consume(:STRING_LITERAL).value
          AST::StringLit.new(value: value)
        when :IDENTIFIER
          # Check for lambda: x => expr
          if peek && peek.type == :FAT_ARROW
            parse_lambda
          else
            name = consume(:IDENTIFIER).value

            if current.type == :LPAREN
              # Function call
              consume(:LPAREN)
              args = parse_args
              consume(:RPAREN)
              AST::Call.new(callee: AST::VarRef.new(name: name), args: args)
            elsif current.type == :LBRACE
              # Record literal
              consume(:LBRACE)
              fields = parse_record_fields
              consume(:RBRACE)
              AST::RecordLit.new(type_name: name, fields: fields)
            else
              # Variable reference
              AST::VarRef.new(name: name)
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
          consume(:LBRACE)
          fields = parse_record_fields
          consume(:RBRACE)
          AST::RecordLit.new(type_name: "record", fields: fields)
        when :LBRACKET
          parse_array_literal_or_comprehension
        else
          raise "Unexpected token: #{current}"
        end
      end

      # Parse for loops
      def parse_for_loop
        consume(:FOR)
        var_name = consume(:IDENTIFIER).value
        consume(:IN)
        iterable = parse_if_expression
        consume(:DO)
        body = parse_expression

        AST::ForLoop.new(
          var_name: var_name,
          iterable: iterable,
          body: body
        )
      end

      # Parse lambda expressions
      def parse_lambda
        if current.type == :IDENTIFIER && peek && peek.type == :FAT_ARROW
          # Single parameter: x => expr
          param_name = consume(:IDENTIFIER).value
          consume(:FAT_ARROW)
          body = parse_if_expression

          AST::Lambda.new(params: [param_name], body: body)

        elsif current.type == :LPAREN
          # Multiple parameters: (x, y) => expr or (x: i32, y: i32) => expr
          consume(:LPAREN)
          params = parse_lambda_params
          consume(:RPAREN)
          consume(:FAT_ARROW)
          body = parse_lambda_body

          AST::Lambda.new(params: params, body: body)
        else
          raise "Expected lambda expression"
        end
      end

      def parse_lambda_params
        params = []

        while current.type != :RPAREN
          name = consume(:IDENTIFIER).value

          # Skip type annotation for now (type inference)
          if current.type == :COLON
            consume(:COLON)
            parse_type  # Just consume, ignore for now
          end

          params << name

          break unless current.type == :COMMA
          consume(:COMMA)
        end

        params
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
        consume(:LBRACKET)

        # Empty array
        if current.type == :RBRACKET
          consume(:RBRACKET)
          return AST::ArrayLiteral.new(elements: [])
        end

        # Parse first expression
        first_expr = parse_if_expression

        if current.type == :FOR
          # It's a comprehension: [expr for var in iterable]
          generators = []
          filters = []

          while current.type == :FOR
            consume(:FOR)
            var_name = consume(:IDENTIFIER).value
            consume(:IN)
            iterable = parse_if_expression

            generators << AST::Generator.new(
              var_name: var_name,
              iterable: iterable
            )

            # Check for filter
            if current.type == :IF
              consume(:IF)
              filters << parse_if_expression
            end
          end

          consume(:RBRACKET)

          AST::ListComprehension.new(
            output_expr: first_expr,
            generators: generators,
            filters: filters
          )
        else
          # Regular array literal
          elements = [first_expr]

          while current.type == :COMMA
            consume(:COMMA)
            break if current.type == :RBRACKET  # Trailing comma
            elements << parse_if_expression
          end

          consume(:RBRACKET)

          AST::ArrayLiteral.new(elements: elements)
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
        token
      end
    end
  end
end
