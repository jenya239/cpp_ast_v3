# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # ExpressionTransformer
      # Expression transformation from AST to CoreIR
      # Auto-extracted from to_core.rb during refactoring
      module ExpressionTransformer
      def bind_pattern_variables(pattern, scrutinee_type)
        case pattern[:kind]
        when :constructor
          info = constructor_info_for(pattern[:name], scrutinee_type)
          field_types = info ? info.param_types : []
          bindings = []

          Array(pattern[:fields]).each_with_index do |field_name, idx|
            next if field_name.nil? || field_name == "_"
            field_type = field_types[idx] || CoreIR::Builder.primitive_type("auto")
            @var_types[field_name] = field_type
            bindings << field_name
          end

          pattern[:bindings] = bindings unless bindings.empty?
        when :var
          name = pattern[:name]
          @var_types[name] = scrutinee_type if name && name != "_"
        when :regex
          Array(pattern[:bindings]).each do |binding|
            next if binding.nil? || binding == "_"
            @var_types[binding] = CoreIR::Builder.primitive_type("string")
          end
        end
      end

      def expected_lambda_param_types(object_ir, member_name, transformed_args, index)
        return [] unless object_ir && member_name

        object_type = object_ir.type
        return [] unless object_type

        case member_name
        when "map"
          if index.zero? && object_type.is_a?(CoreIR::ArrayType)
            [object_type.element_type]
          else
            []
          end
        when "filter"
          if index.zero? && object_type.is_a?(CoreIR::ArrayType)
            [object_type.element_type]
          else
            []
          end
        when "fold"
          if index == 1 && object_type.is_a?(CoreIR::ArrayType)
            accumulator_type = transformed_args.first&.type
            element_type = object_type.element_type
            accumulator_type ? [accumulator_type, element_type] : []
          else
            []
          end
        else
          []
        end
      end

      def lambda_return_type(arg)
        return nil unless arg

        if arg.respond_to?(:function_type) && arg.function_type
          arg.function_type.ret_type
        elsif arg.respond_to?(:type) && arg.type.is_a?(CoreIR::FunctionType)
          arg.type.ret_type
        else
          nil
        end
      end

      def transform_array_literal(array_lit)
        # Transform each element
        elements = array_lit.elements.map { |elem| transform_expression(elem) }

        # Infer element type from first element (or default to i32)
        element_type = if elements.any?
                         elements.first.type
                       else
                         CoreIR::Builder.primitive_type("i32")
                       end

        elements.each_with_index do |elem, index|
          next if index.zero?
          ensure_compatible_type(elem.type, element_type, "array element #{index}")
        end

        # Create array type
        array_type = CoreIR::ArrayType.new(element_type: element_type)

        CoreIR::ArrayLiteralExpr.new(
          elements: elements,
          type: array_type
        )
      end

      def transform_do_expr(expr)
        # Transform do-block: do expr1; expr2; ...; exprN end
        # Returns the value of the last expression
        return CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void")) if expr.body.empty?


        statements = []

        # Process all expressions
        expr.body.each_with_index do |e, idx|
          is_last = (idx == expr.body.length - 1)

          if e.is_a?(AST::VariableDecl) && !is_last
            # Statement-style variable declaration (let x = value or let mut x = value)
            value = transform_expression(e.value)
            @var_types[e.name] = value.type
            statements << CoreIR::Builder.variable_decl_stmt(e.name, value.type, value, mutable: e.mutable)
          elsif e.is_a?(AST::Let) && e.body.nil? && !is_last
            # Legacy statement-style let (let x = value without 'in')
            value = transform_expression(e.value)
            @var_types[e.name] = value.type
            statements << CoreIR::Builder.variable_decl_stmt(e.name, value.type, value, mutable: e.mutable)
          elsif e.is_a?(AST::Assignment) && !is_last
            # Assignment statement: x = value
            unless e.target.is_a?(AST::VarRef)
              type_error("Assignment target must be a variable", node: e)
            end
            target_name = e.target.name
            existing_type = @var_types[target_name]
            type_error("Assignment to undefined variable '#{target_name}'", node: e) unless existing_type

            value_ir = transform_expression(e.value)
            ensure_compatible_type(value_ir.type, existing_type, "assignment to '#{target_name}'")
            target_ir = CoreIR::Builder.var(target_name, existing_type)
            statements << CoreIR::Builder.assignment_stmt(target_ir, value_ir)
          elsif e.is_a?(AST::WhileLoop) && !is_last
            # While loop is always a statement (returns void)
            statements << CoreIR::Builder.expr_statement(transform_expression(e))
          elsif !is_last
            # Not the last expression - convert to statement
            statements << CoreIR::Builder.expr_statement(transform_expression(e))
          end
        end

        # Last expression is the result value
        last_expr = expr.body.last
        if last_expr.is_a?(AST::WhileLoop)
          # If last is while loop, add as statement and return void
          statements << CoreIR::Builder.expr_statement(transform_expression(last_expr))
          result_expr = CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void"))
        elsif last_expr.is_a?(AST::VariableDecl)
          # If last is a variable declaration, return void
          value = transform_expression(last_expr.value)
          @var_types[last_expr.name] = value.type
          statements << CoreIR::Builder.variable_decl_stmt(last_expr.name, value.type, value, mutable: last_expr.mutable)
          result_expr = CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void"))
        elsif last_expr.is_a?(AST::Let) && last_expr.body.nil?
          # Legacy: if last is a let statement, return void
          value = transform_expression(last_expr.value)
          @var_types[last_expr.name] = value.type
          statements << CoreIR::Builder.variable_decl_stmt(last_expr.name, value.type, value, mutable: last_expr.mutable)
          result_expr = CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void"))
        elsif last_expr.is_a?(AST::Assignment)
          # If last is an assignment, treat as statement and return void
          unless last_expr.target.is_a?(AST::VarRef)
            type_error("Assignment target must be a variable", node: last_expr)
          end
          target_name = last_expr.target.name
          existing_type = @var_types[target_name]
          type_error("Assignment to undefined variable '#{target_name}'", node: last_expr) unless existing_type

          value_ir = transform_expression(last_expr.value)
          ensure_compatible_type(value_ir.type, existing_type, "assignment to '#{target_name}'")
          target_ir = CoreIR::Builder.var(target_name, existing_type)
          statements << CoreIR::Builder.assignment_stmt(target_ir, value_ir)
          result_expr = CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void"))
        else
          result_expr = transform_expression(last_expr)
        end

        CoreIR::Builder.block_expr(statements, result_expr, result_expr.type)
      end

      def transform_expression(expr)
        with_current_node(expr) do
          case expr
          when AST::IntLit
            type = CoreIR::Builder.primitive_type("i32")
            CoreIR::Builder.literal(expr.value, type)
          when AST::FloatLit
            type = CoreIR::Builder.primitive_type("f32")
            CoreIR::Builder.literal(expr.value, type)
          when AST::StringLit
            type = CoreIR::Builder.primitive_type("string")
            CoreIR::Builder.literal(expr.value, type)
          when AST::RegexLit
            type = CoreIR::Builder.primitive_type("regex")
            CoreIR::Builder.regex(expr.pattern, expr.flags, type)
          when AST::VarRef
            type = infer_type(expr.name)
            CoreIR::Builder.var(expr.name, type)
          when AST::BinaryOp
            # Check if this is a pipe operator - desugar it
            if expr.op == "|>"
              transform_pipe(expr)
            else
              left = transform_expression(expr.left)
              right = transform_expression(expr.right)
              type = infer_binary_type(expr.op, left.type, right.type)
              CoreIR::Builder.binary(expr.op, left, right, type)
            end
          when AST::UnaryOp
            operand = transform_expression(expr.operand)
            type = infer_unary_type(expr.op, operand.type)
            CoreIR::Builder.unary(expr.op, operand, type)
          when AST::Call
            if expr.callee.is_a?(AST::VarRef) && IO_RETURN_TYPES.key?(expr.callee.name)
              callee = transform_expression(expr.callee)
              args = expr.args.map { |arg| transform_expression(arg) }
              type = io_return_type(expr.callee.name)
              CoreIR::Builder.call(callee, args, type)
            else
              callee_ast = expr.callee
              object_ir = nil
              member_name = nil

              if callee_ast.is_a?(AST::MemberAccess)
                object_ir = transform_expression(callee_ast.object)
                member_name = callee_ast.member
                callee = CoreIR::Builder.member(object_ir, member_name, infer_member_type(object_ir.type, member_name))
            elsif callee_ast.is_a?(AST::VarRef)
              var_type = function_placeholder_type(callee_ast.name)
              callee = CoreIR::Builder.var(callee_ast.name, var_type)
            else
              callee = transform_expression(callee_ast)
            end

            args = []
            expr.args.each_with_index do |arg, index|
              expected_params = expected_lambda_param_types(object_ir, member_name, args, index)
              if arg.is_a?(AST::Lambda)
                @lambda_param_type_stack.push(expected_params)
                transformed_arg = transform_expression(arg)
                @lambda_param_type_stack.pop
              else
                transformed_arg = transform_expression(arg)
              end
              args << transformed_arg
            end

            type = infer_call_type(callee, args)
            CoreIR::Builder.call(callee, args, type)
          end
          when AST::MemberAccess
            object = transform_expression(expr.object)
            type = infer_member_type(object.type, expr.member)
            CoreIR::Builder.member(object, expr.member, type)
          when AST::Let
            value = transform_expression(expr.value)
            previous_type = @var_types[expr.name]
            @var_types[expr.name] = value.type
            body = transform_expression(expr.body)
            statements = [
              CoreIR::Builder.variable_decl_stmt(expr.name, value.type, value, mutable: expr.mutable)
            ]
            result = CoreIR::Builder.block_expr(statements, body, body.type)
            if previous_type
              @var_types[expr.name] = previous_type
            else
              @var_types.delete(expr.name)
            end
            result
          when AST::RecordLit
            fields = expr.fields.transform_values { |value| transform_expression(value) }
            type = @type_table[expr.type_name]

            unless type
              inferred_fields = fields.map { |name, value| {name: name, type: value.type} }
              type = CoreIR::Builder.record_type(expr.type_name, inferred_fields)
            end

            CoreIR::Builder.record(expr.type_name, fields, type)
          when AST::IfExpr
            condition = transform_expression(expr.condition)
            then_branch = transform_expression(expr.then_branch)
            else_branch = expr.else_branch ? transform_expression(expr.else_branch) : nil
            if else_branch
              ensure_compatible_type(else_branch.type, then_branch.type, "if expression branches")
            end
            type = then_branch.type
            CoreIR::Builder.if_expr(condition, then_branch, else_branch, type)
          when AST::MatchExpr
            scrutinee = transform_expression(expr.scrutinee)
            arms = expr.arms.map { |arm| transform_match_arm(scrutinee.type, arm) }
            type = arms.first[:body].type
            arms.each_with_index do |arm, index|
              ensure_compatible_type(arm[:body].type, type, "match arm #{index + 1}")
            end
            CoreIR::Builder.match_expr(scrutinee, arms, type)
          when AST::Lambda
            transform_lambda(expr)
          when AST::Block
            transform_block(expr)
          when AST::ArrayLiteral
            transform_array_literal(expr)
          when AST::IndexAccess
            transform_index_access(expr)
          when AST::ForLoop
            transform_for_loop(expr)
          when AST::WhileLoop
            transform_while_loop(expr)
          when AST::ListComprehension
            transform_list_comprehension(expr)
          when AST::DoExpr
            transform_do_expr(expr)
          else
            raise "Unknown expression: #{expr.class}"
          end
        end
      end

      def transform_for_loop(for_loop)
        iterable = transform_expression(for_loop.iterable)
        saved = @var_types[for_loop.var_name]
        var_type = infer_iterable_type(iterable)
        @var_types[for_loop.var_name] = var_type

        body = within_loop_scope { transform_expression(for_loop.body) }

        CoreIR::ForLoopExpr.new(
          var_name: for_loop.var_name,
          var_type: var_type,
          iterable: iterable,
          body: body
        )
      ensure
        if saved
          @var_types[for_loop.var_name] = saved
        else
          @var_types.delete(for_loop.var_name)
        end
      end

      def transform_index_access(index_access)
        # Transform array indexing: arr[index]
        object = transform_expression(index_access.object)
        index = transform_expression(index_access.index)

        unless object.type.is_a?(CoreIR::ArrayType)
          type_error("Indexing requires an array, got #{describe_type(object.type)}", node: index_access.object)
        end

        ensure_numeric_type(index.type, "array index", node: index_access.index)

        result_type = object.type.element_type

        CoreIR::IndexExpr.new(
          object: object,
          index: index,
          type: result_type
        )
      end

      def transform_lambda(lambda_expr)
        saved_var_types = @var_types.dup

        expected_param_types = @lambda_param_type_stack.last || []

        params = lambda_expr.params.each_with_index.map do |param, index|
          if param.is_a?(AST::LambdaParam)
            param_type = if param.type
                           transform_type(param.type)
                         elsif expected_param_types[index]
                           expected_param_types[index]
                         else
                           CoreIR::Builder.primitive_type("i32")
                         end
            @var_types[param.name] = param_type
            CoreIR::Param.new(name: param.name, type: param_type)
          else
            param_name = param.respond_to?(:name) ? param.name : param
            param_type = expected_param_types[index] || CoreIR::Builder.primitive_type("i32")
            @var_types[param_name] = param_type
            CoreIR::Param.new(name: param_name, type: param_type)
          end
        end

        body = transform_expression(lambda_expr.body)

        ret_type = body.type

        param_types = params.map { |p| {name: p.name, type: p.type} }
        function_type = CoreIR::FunctionType.new(
          params: param_types,
          ret_type: ret_type
        )

        captures = []

        CoreIR::LambdaExpr.new(
          captures: captures,
          params: params,
          body: body,
          function_type: function_type
        )
      ensure
        @var_types = saved_var_types
      end

      def transform_list_comprehension(list_comp)
        saved_var_types = @var_types.dup

        generators = []

        list_comp.generators.each do |gen|
          iterable_ir = transform_expression(gen.iterable)
          element_type = infer_iterable_type(iterable_ir)

          generators << {
            var_name: gen.var_name,
            iterable: iterable_ir,
            var_type: element_type
          }

          @var_types[gen.var_name] = element_type
        end

        filters = list_comp.filters.map { |filter| transform_expression(filter) }

        output_expr = transform_expression(list_comp.output_expr)
        element_type = output_expr.type || CoreIR::Builder.primitive_type("i32")

        array_type = CoreIR::ArrayType.new(element_type: element_type)

        CoreIR::ListCompExpr.new(
          element_type: element_type,
          generators: generators,
          filters: filters,
          output_expr: output_expr,
          type: array_type
        )
      ensure
        @var_types = saved_var_types
      end

      def transform_match_arm(scrutinee_type, arm)
        saved_var_types = @var_types.dup
        pattern = transform_pattern(arm[:pattern])
        bind_pattern_variables(pattern, scrutinee_type)
        guard = arm[:guard] ? transform_expression(arm[:guard]) : nil
        body = transform_expression(arm[:body])
        {pattern: pattern, guard: guard, body: body}
      ensure
        @var_types = saved_var_types
      end

      def transform_pattern(pattern)
        case pattern.kind
        when :wildcard
          {kind: :wildcard}
        when :literal
          {kind: :literal, value: pattern.data[:value]}
        when :constructor
          {kind: :constructor, name: pattern.data[:name], fields: pattern.data[:fields]}
        when :var
          {kind: :var, name: pattern.data[:name]}
        when :regex
          {
            kind: :regex,
            pattern: pattern.data[:pattern],
            flags: pattern.data[:flags],
            bindings: pattern.data[:bindings] || []
          }
        else
          raise "Unknown pattern kind: #{pattern.kind}"
        end
      end

      def transform_pipe(pipe_expr)
        # Desugar pipe operator: left |> right
        # If right is a function call, insert left as first argument
        # Otherwise, treat right as function name and create call with left

        left = transform_expression(pipe_expr.left)

        if pipe_expr.right.is_a?(AST::Call)
          # right is f(args) => transform to f(left, args)
          callee = transform_expression(pipe_expr.right.callee)
          args = pipe_expr.right.args.map { |arg| transform_expression(arg) }

          # Insert left as first argument
          all_args = [left] + args

          # Infer return type
          type = infer_call_type(callee, all_args)

          CoreIR::Builder.call(callee, all_args, type)
        else
          # right is just a function name => f(left)
          callee = transform_expression(pipe_expr.right)
          type = infer_call_type(callee, [left])

          CoreIR::Builder.call(callee, [left], type)
        end
      end

      def transform_while_loop(while_loop)
        condition = transform_expression(while_loop.condition)
        body = within_loop_scope { transform_expression(while_loop.body) }
        CoreIR::Builder.while_loop_expr(condition, body)
      end

      end
    end
  end
end
