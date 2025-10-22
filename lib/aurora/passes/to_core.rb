# frozen_string_literal: true

require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"

module Aurora
  module Passes
    class ToCore
      FunctionInfo = Struct.new(:name, :param_types, :ret_type)
      NUMERIC_PRIMITIVES = %w[i32 f32 i64 f64 u32 u64].freeze
      IO_RETURN_TYPES = {
        "print" => "i32",
        "println" => "i32",
        "eprint" => "i32",
        "eprintln" => "i32",
        "read_line" => "string",
        "input" => "string",
        "args" => :array_of_string,
        "to_string" => "string",
        "format" => "string"
      }.freeze
      BUILTIN_CONSTRAINTS = {
        "Numeric" => %w[i32 f32 i64 f64 u32 u64]
      }.freeze

      def initialize
        @type_table = {}
        @function_table = {}
        @type_decl_table = {}
        @sum_type_constructors = {}
        @var_types = {}  # Track variable types for let bindings
        @temp_counter = 0
        @loop_depth = 0
        @lambda_param_type_stack = []
        @function_return_type_stack = []
        @current_node = nil
        @current_type_params = []  # Track type parameters of current function/type
      end
      
      def transform(ast)
        case ast
        when AST::Program
          transform_program(ast)
        when AST::FuncDecl
          transform_function(ast)
        when AST::TypeDecl
          transform_type_decl(ast)
        else
          raise "Unknown AST node: #{ast.class}"
        end
      end
      
      private
      
      def transform_program(program)
        items = []
        imports = []

        # Transform imports
        program.imports.each do |import_decl|
          imports << CoreIR::Import.new(
            path: import_decl.path,
            items: import_decl.items
          )
        end

        # Pre-register type declarations for constraint checks
        program.declarations.each do |decl|
          @type_decl_table[decl.name] = decl if decl.is_a?(AST::TypeDecl)
        end

        # Pre-register function signatures to support recursion and forward references
        program.declarations.each do |decl|
          register_function_signature(decl) if decl.is_a?(AST::FuncDecl)
        end

        type_items = []
        func_items = []

        # Transform declarations (types first, then functions)
        program.declarations.each do |decl|
          case decl
          when AST::TypeDecl
            type_decl = transform_type_decl(decl)
            type_items << type_decl
            @type_table[decl.name] = type_decl.type
            refresh_function_signatures!(decl.name)
          when AST::FuncDecl
            func_items << transform_function(decl)
          end
        end

        items.concat(type_items)
        items.concat(func_items)

        # Get module name from module declaration or default to "main"
        module_name = program.module_decl ? program.module_decl.name : "main"

        CoreIR::Module.new(name: module_name, items: items, imports: imports)
      end
      
      def transform_type_decl(decl)
        with_current_node(decl) do
          type = transform_type(decl.type)

          type = case type
                 when CoreIR::RecordType
                   CoreIR::Builder.record_type(decl.name, type.fields)
                 when CoreIR::SumType
                   CoreIR::Builder.sum_type(decl.name, type.variants)
                 else
                   type
                 end
          register_sum_type_constructors(decl.name, type) if type.is_a?(CoreIR::SumType)
          type_params = normalize_type_params(decl.type_params)
          CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: type_params)
        end
      end
      
      def transform_function(func)
        with_current_node(func) do
          signature = ensure_function_signature(func)
          param_types = signature.param_types

          if param_types.length != func.params.length
            type_error("Function '#{func.name}' expects #{param_types.length} parameter(s), got #{func.params.length}")
          end

          params = func.params.each_with_index.map do |param, index|
            CoreIR::Param.new(name: param.name, type: param_types[index])
          end

          ret_type = signature.ret_type
          type_params = normalize_type_params(func.type_params)

          # For external functions, skip body transformation
          if func.external
            return CoreIR::Func.new(
              name: func.name,
              params: params,
              ret_type: ret_type,
              body: nil,
              effects: [],
              type_params: type_params,
              external: true
            )
          end

          saved_var_types = @var_types.dup
          saved_type_params = @current_type_params
          @function_return_type_stack.push(ret_type)

          # Save type parameters for constraint checking
          @current_type_params = type_params

          params.each do |param|
            @var_types[param.name] = param.type
          end

          body = transform_expression(func.body)

          unless void_type?(ret_type)
            ensure_compatible_type(body.type, ret_type, "function '#{func.name}' result")
          else
            type_error("function '#{func.name}' should not return a value") unless void_type?(body.type)
          end

          CoreIR::Func.new(
            name: func.name,
            params: params,
            ret_type: ret_type,
            body: body,
            effects: infer_effects(body),
            type_params: type_params
          )
        end
      ensure
        @function_return_type_stack.pop if @function_return_type_stack.any?
        @var_types = saved_var_types if defined?(saved_var_types)
        @current_type_params = saved_type_params if defined?(saved_type_params)
      end
      
      def normalize_type_params(params)
        params.map do |tp|
          with_current_node(tp) do
            name = tp.respond_to?(:name) ? tp.name : tp
            constraint = tp.respond_to?(:constraint) ? tp.constraint : nil
            validate_constraint_name(constraint)
            CoreIR::TypeParam.new(name: name, constraint: constraint)
          end
        end
      end

      def transform_type(type)
        with_current_node(type) do
          case type
          when AST::PrimType
            CoreIR::Builder.primitive_type(type.name)
          when AST::GenericType
            base_name = type.base_type.name
            validate_type_constraints(base_name, type.type_params)
            type_arg_names = type.type_params.map { |tp| transform_type(tp).name }.join(", ")
            CoreIR::Builder.primitive_type("#{base_name}<#{type_arg_names}>")
          when AST::RecordType
            fields = type.fields.map { |field| {name: field[:name], type: transform_type(field[:type])} }
            CoreIR::Builder.record_type(type.name, fields)
          when AST::SumType
            variants = type.variants.map do |variant|
              fields = variant[:fields].map { |field| {name: field[:name], type: transform_type(field[:type])} }
              {name: variant[:name], fields: fields}
            end
            CoreIR::Builder.sum_type(type.name, variants)
          when AST::ArrayType
            element_type = transform_type(type.element_type)
            CoreIR::ArrayType.new(element_type: element_type)
          else
            raise "Unknown type: #{type.class}"
          end
        end
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

      def validate_constraint_name(name)
        return if name.nil? || name.empty?
        return if BUILTIN_CONSTRAINTS.key?(name)

        type_error("Unknown constraint '#{name}'")
      end

      def validate_type_constraints(base_name, actual_type_nodes)
        decl = @type_decl_table[base_name]
        return unless decl && decl.type_params.any?

        decl.type_params.zip(actual_type_nodes).each do |param_info, actual_node|
          next unless param_info.respond_to?(:constraint) && param_info.constraint && !param_info.constraint.empty?

          actual_name = extract_actual_type_name(actual_node)
          next if actual_name.nil?

          unless type_satisfies_constraint?(param_info.constraint, actual_name)
            type_error("Type '#{actual_name}' does not satisfy constraint '#{param_info.constraint}' for '#{param_info.name}'")
          end
        end
      end

      def extract_actual_type_name(type_node)
        case type_node
        when AST::PrimType
          name = type_node.name
          return nil if name.nil?
          return nil if name[0]&.match?(/[A-Z]/)
          name
        else
          nil
        end
      end

      def type_satisfies_constraint?(constraint, type_name)
        allowed = BUILTIN_CONSTRAINTS[constraint]
        allowed && allowed.include?(type_name)
      end

      def io_return_type(name)
        case IO_RETURN_TYPES[name]
        when "i32"
          CoreIR::Builder.primitive_type("i32")
        when "string"
          CoreIR::Builder.primitive_type("string")
        when :array_of_string
          CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
        else
          CoreIR::Builder.primitive_type("i32")
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

      def transform_block(block, require_value: true)
        with_current_node(block) do
          saved_var_types = @var_types.dup
          if block.stmts.empty?
            if require_value
              type_error("Block must end with an expression")
            else
              return CoreIR::Builder.block_expr(
                [],
                nil,
                CoreIR::Builder.primitive_type("void")
              )
            end
          end

          statements = block.stmts.dup
          tail = require_value ? statements.pop : nil

          statement_nodes = transform_statements(statements)
          result_ir = nil

          if require_value && tail
            case tail
            when AST::ExprStmt
              result_ir = transform_expression(tail.expr)
            when AST::Return
              statement_nodes << transform_return_statement(tail)
            else
              statement_nodes.concat(transform_statements([tail]))
            end
          end

          block_type = result_ir ? result_ir.type : CoreIR::Builder.primitive_type("void")
          CoreIR::Builder.block_expr(statement_nodes, result_ir, block_type)
        ensure
          @var_types = saved_var_types if defined?(saved_var_types)
        end
      end

      def transform_statements(statements)
        statements.each_with_object([]) do |stmt, acc|
          with_current_node(stmt) do
            case stmt
            when AST::ExprStmt
              acc.concat(transform_expr_statement(stmt))
            when AST::VariableDecl
              value_ir = transform_expression(stmt.value)
              previous_type = @var_types[stmt.name]
              @var_types[stmt.name] = value_ir.type
              acc << CoreIR::Builder.variable_decl_stmt(
                stmt.name,
                value_ir.type,
                value_ir,
                mutable: stmt.mutable
              )
            when AST::Assignment
              unless stmt.target.is_a?(AST::VarRef)
                type_error("Assignment target must be a variable", node: stmt)
              end
              target_name = stmt.target.name
              existing_type = @var_types[target_name]
              type_error("Assignment to undefined variable '#{target_name}'", node: stmt) unless existing_type

              value_ir = transform_expression(stmt.value)
              ensure_compatible_type(value_ir.type, existing_type, "assignment to '#{target_name}'")
              @var_types[target_name] = existing_type
              target_ir = CoreIR::Builder.var(target_name, existing_type)
              acc << CoreIR::Builder.assignment_stmt(target_ir, value_ir)
            when AST::ForLoop
              acc << transform_for_statement(stmt)
            when AST::IfStmt
              acc << transform_if_statement(stmt.condition, stmt.then_branch, stmt.else_branch)
            when AST::WhileStmt
              acc << transform_while_statement(stmt.condition, stmt.body)
            when AST::Return
              acc << transform_return_statement(stmt)
            when AST::Break
              type_error("'break' used outside of loop", node: stmt) if @loop_depth.to_i <= 0
              acc << CoreIR::Builder.break_stmt
            when AST::Continue
              type_error("'continue' used outside of loop", node: stmt) if @loop_depth.to_i <= 0
              acc << CoreIR::Builder.continue_stmt
            when AST::Block
              nested = transform_block(stmt, require_value: false)
              acc.concat(nested.statements)
            else
              type_error("Unsupported statement: #{stmt.class}", node: stmt)
            end
          end
        end
      end

      def transform_for_statement(stmt)
        iterable_ir = transform_expression(stmt.iterable)
        saved = @var_types[stmt.var_name]
        element_type = infer_iterable_type(iterable_ir)
        @var_types[stmt.var_name] = element_type
        body_ir = within_loop_scope { transform_statement_block(stmt.body) }

        CoreIR::Builder.for_stmt(stmt.var_name, element_type, iterable_ir, body_ir)
      ensure
        if saved
          @var_types[stmt.var_name] = saved
        else
          @var_types.delete(stmt.var_name)
        end
      end

      def transform_if_statement(condition_node, then_node, else_node)
        condition_ir = transform_expression(condition_node)
        ensure_boolean_type(condition_ir.type, "if condition", node: condition_node)
        then_ir = transform_statement_block(then_node)
        else_ir = else_node ? transform_statement_block(else_node) : nil
        CoreIR::Builder.if_stmt(condition_ir, then_ir, else_ir)
      end

      def transform_while_statement(condition_node, body_node)
        condition_ir = transform_expression(condition_node)
        ensure_boolean_type(condition_ir.type, "while condition", node: condition_node)
        body_ir = within_loop_scope { transform_statement_block(body_node) }
        CoreIR::Builder.while_stmt(condition_ir, body_ir)
      end

      def transform_return_statement(stmt)
        expected = @function_return_type_stack.last
        type_error("return statement outside of function") unless expected

        expr_ir = stmt.expr ? transform_expression(stmt.expr) : nil

        if void_type?(expected)
          type_error("return value not allowed in void function", node: stmt) if expr_ir
        else
          unless expr_ir
            expected_name = describe_type(expected)
            type_error("return statement requires a value of type #{expected_name}", node: stmt)
          end
          ensure_compatible_type(expr_ir.type, expected, "return statement", node: stmt)
        end

        CoreIR::Builder.return_stmt(expr_ir)
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

      def transform_while_loop(while_loop)
        condition = transform_expression(while_loop.condition)
        body = within_loop_scope { transform_statement_block(while_loop.body) }
        CoreIR::Builder.while_loop_expr(condition, body)
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

      def transform_expr_statement(expr_stmt)
        expr = expr_stmt.expr
        case expr
        when AST::ForLoop
          [transform_for_statement(expr)]
        when AST::IfExpr
          [transform_if_statement(expr.condition, expr.then_branch, expr.else_branch)]
        when AST::WhileLoop
          [transform_while_statement(expr.condition, expr.body)]
        when AST::Block
          transform_block(expr, require_value: false).statements
        else
          ir = transform_expression(expr)
          if expr.is_a?(AST::IfExpr) && ir.is_a?(CoreIR::IfExpr)
            CoreIR::Builder.if_stmt(ir.condition, transform_statement_block(expr.then_branch), expr.else_branch ? transform_statement_block(expr.else_branch) : nil)
            []
          else
            [CoreIR::Builder.expr_statement(ir)]
          end
        end
      end

      def transform_statement_block(node)
        block_ast =
          case node
          when AST::Block
            node
          when AST::Stmt
            AST::Block.new(stmts: [node])
          else
            AST::Block.new(stmts: [AST::ExprStmt.new(expr: node)])
          end

        transform_block(block_ast, require_value: false)
      end

      def within_loop_scope
        @loop_depth ||= 0
        @loop_depth += 1
        yield
      ensure
        @loop_depth -= 1
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

      def infer_type(name)
        return @var_types[name] if @var_types.key?(name)

        if (info = lookup_function_info(name))
          return function_type_from_info(info)
        end

        return CoreIR::Builder.primitive_type("bool") if %w[true false].include?(name)

        scope = @var_types.keys.sort.join(", ")
        type_error("Unknown identifier '#{name}' (in scope: #{scope})")
      end
      
      def infer_binary_type(op, left_type, right_type)
        ensure_type!(left_type, "Left operand of '#{op}' has no type")
        ensure_type!(right_type, "Right operand of '#{op}' has no type")

        case op
        when "+"
          # Support both numeric addition and string concatenation
          if string_type?(left_type) && string_type?(right_type)
            CoreIR::Builder.primitive_type("string")
          elsif numeric_type?(left_type) && numeric_type?(right_type)
            combine_numeric_type(left_type, right_type)
          else
            type_error("Cannot add #{describe_type(left_type)} and #{describe_type(right_type)}")
          end
        when "-", "*", "%"
          ensure_numeric_type(left_type, "left operand of '#{op}'")
          ensure_numeric_type(right_type, "right operand of '#{op}'")
          combine_numeric_type(left_type, right_type)
        when "/"
          ensure_numeric_type(left_type, "left operand of '/' ")
          ensure_numeric_type(right_type, "right operand of '/' ")
          if float_type?(left_type) || float_type?(right_type)
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when "==", "!="
          ensure_compatible_type(left_type, right_type, "comparison '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        when "<", ">", "<=", ">="
          ensure_numeric_type(left_type, "left operand of '#{op}'")
          ensure_numeric_type(right_type, "right operand of '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        when "&&", "||"
          ensure_boolean_type(left_type, "left operand of '#{op}'")
          ensure_boolean_type(right_type, "right operand of '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        else
          left_type
        end
      end

      def infer_unary_type(op, operand_type)
        ensure_type!(operand_type, "Unary operand for '#{op}' has no type")

        case op
        when "!"
          ensure_boolean_type(operand_type, "operand of '!'")
          CoreIR::Builder.primitive_type("bool")
        when "-", "+"
          ensure_numeric_type(operand_type, "operand of '#{op}'")
          operand_type
        else
          operand_type
        end
      end
      
      def infer_call_type(callee, args)
        case callee
        when CoreIR::VarExpr
          if IO_RETURN_TYPES.key?(callee.name)
            return io_return_type(callee.name)
          end

          info = lookup_function_info(callee.name)
          unless info
            return CoreIR::Builder.primitive_type("auto")
          end
          validate_function_call(info, args, callee.name)
          info.ret_type
        when CoreIR::LambdaExpr
          function_type = callee.function_type
          expected = function_type.params || []

          if expected.length != args.length
            type_error("Lambda expects #{expected.length} argument(s), got #{args.length}")
          end

          expected.each_with_index do |param, index|
            ensure_compatible_type(args[index].type, param[:type], "lambda argument #{index + 1}")
          end

          function_type.ret_type
        when CoreIR::MemberExpr
          object_type = callee.object&.type
          type_error("Cannot call member on value without type") unless object_type

          member = callee.member

          if object_type.is_a?(CoreIR::ArrayType)
            case member
            when "length", "size"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("i32")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("bool")
            when "map"
              ensure_argument_count(member, args, 1)
              element_type = lambda_return_type(args.first)
              type_error("Unable to infer return type of map lambda") unless element_type
              CoreIR::ArrayType.new(element_type: element_type)
            when "filter"
              ensure_argument_count(member, args, 1)
              CoreIR::ArrayType.new(element_type: object_type.element_type)
            when "fold"
              ensure_argument_count(member, args, 2)
              accumulator_type = args.first&.type
              ensure_type!(accumulator_type, "Unable to determine accumulator type for fold")
              accumulator_type
            else
              type_error("Unknown array method '#{member}'. Supported methods: length, size, is_empty, map, filter, fold")
            end
          elsif string_type?(object_type)
            case member
            when "split"
              ensure_argument_count(member, args, 1)
              CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
            when "trim", "trim_start", "trim_end", "upper", "lower"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("string")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("bool")
            when "length"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("i32")
            else
              type_error("Unknown string method '#{member}'. Supported methods: split, trim, trim_start, trim_end, upper, lower, is_empty, length")
            end
          elsif numeric_type?(object_type) && member == "sqrt"
            ensure_argument_count(member, args, 0)
            CoreIR::Builder.primitive_type("f32")
          else
            type_error("Unknown member '#{member}' for type #{describe_type(object_type)}")
          end
        else
          type_error("Cannot call value of type #{describe_type(callee.type)}")
        end
      end
      
      def infer_member_type(object_type, member)
        type_error("Cannot access member '#{member}' on value without type") unless object_type

        if object_type.record?
          field = object_type.fields.find { |f| f[:name] == member }
          type_error("Unknown field '#{member}' for type #{object_type.name}") unless field
          field[:type]
        elsif object_type.is_a?(CoreIR::ArrayType)
          case member
          when "length", "size"
            CoreIR::Builder.primitive_type("i32")
          when "is_empty"
            CoreIR::Builder.primitive_type("bool")
          when "map", "filter", "fold"
            CoreIR::Builder.function_type([], CoreIR::Builder.primitive_type("auto"))
          else
            type_error("Unknown array member '#{member}'. Known members: length, size, is_empty, map, filter, fold")
          end
        elsif string_type?(object_type)
          case member
          when "split"
            CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
          when "trim", "trim_start", "trim_end", "upper", "lower"
            CoreIR::Builder.primitive_type("string")
          when "is_empty"
            CoreIR::Builder.primitive_type("bool")
          when "length"
            CoreIR::Builder.primitive_type("i32")
          else
            type_error("Unknown string member '#{member}'. Known members: split, trim, trim_start, trim_end, upper, lower, is_empty, length")
          end
        elsif numeric_type?(object_type) && member == "sqrt"
          f32 = CoreIR::Builder.primitive_type("f32")
          CoreIR::Builder.function_type([], f32)
        else
          type_error("Unknown member '#{member}' for type #{describe_type(object_type)}")
        end
      end
      
      def infer_effects(body)
        # Simple effect inference
        effects = []
        
        # Check if function is pure (no side effects)
        if is_pure_expression(body)
          effects << :constexpr
        end
        
        effects << :noexcept
        
        effects
      end
      
      def is_pure_expression(expr)
        case expr
        when CoreIR::LiteralExpr, CoreIR::VarExpr
          true
        when CoreIR::BinaryExpr
          is_pure_expression(expr.left) && is_pure_expression(expr.right)
        when CoreIR::UnaryExpr
          is_pure_expression(expr.operand)
        when CoreIR::CallExpr
          # Assume all calls are pure for now
          true
        when CoreIR::MemberExpr
          is_pure_expression(expr.object)
        when CoreIR::RecordExpr
          expr.fields.values.all? { |field| is_pure_expression(field) }
        when CoreIR::BlockExpr
          false
        else
          false
        end
      end

      def fresh_temp_name
        name = "__tmp#{@temp_counter}"
        @temp_counter += 1
        name
      end

      def infer_iterable_type(iterable_ir)
        if iterable_ir.type.is_a?(CoreIR::ArrayType)
          iterable_ir.type.element_type
        else
          type_error("Iterable expression must be an array, got #{describe_type(iterable_ir.type)}")
        end
      end

      def register_function_signature(func_decl)
        return @function_table[func_decl.name] if @function_table.key?(func_decl.name)

        param_types = func_decl.params.map { |param| transform_type(param.type) }
        ret_type = transform_type(func_decl.ret_type)
        info = FunctionInfo.new(func_decl.name, param_types, ret_type)
        @function_table[func_decl.name] = info
      end

      def ensure_function_signature(func_decl)
        register_function_signature(func_decl)
        @function_table[func_decl.name]
      end

      def register_sum_type_constructors(sum_type_name, sum_type)
        return unless sum_type.respond_to?(:variants)

        sum_type.variants.each do |variant|
          field_types = (variant[:fields] || []).map { |field| field[:type] }
          @sum_type_constructors[variant[:name]] = FunctionInfo.new(variant[:name], field_types, sum_type)
        end
      end

      def constructor_info_for(name, scrutinee_type)
        info = @sum_type_constructors[name]
        return unless info

        if scrutinee_type && type_name(info.ret_type) && type_name(scrutinee_type)
          return info if type_name(info.ret_type) == type_name(scrutinee_type)
        end

        info
      end

      def refresh_function_signatures!(resolved_name)
        resolved = @type_table[resolved_name]
        return unless resolved

        @function_table.each_value do |info|
          info.param_types = info.param_types.map do |type|
            type_name(type) == resolved_name ? resolved : type
          end
          info.ret_type = resolved if type_name(info.ret_type) == resolved_name
        end
      end

      def lookup_function_info(name)
        @function_table[name] || @sum_type_constructors[name] || builtin_function_info(name)
      end

      def builtin_function_info(name)
        case name
        when "sqrt"
          f32 = CoreIR::Builder.primitive_type("f32")
          FunctionInfo.new("sqrt", [f32], f32)
        else
          if IO_RETURN_TYPES.key?(name)
            FunctionInfo.new(name, [], io_return_type(name))
          else
            nil
          end
        end
      end

      def function_type_from_info(info)
        params = info.param_types.each_with_index.map do |type, index|
          {name: "arg#{index}", type: type}
        end
        CoreIR::Builder.function_type(params, info.ret_type)
      end

      def function_placeholder_type(name)
        if (info = lookup_function_info(name))
          function_type_from_info(info)
        else
          CoreIR::Builder.function_type([], CoreIR::Builder.primitive_type("auto"))
        end
      end

      def ensure_type!(type, message, node: nil)
        type_error(message, node: node) unless type
      end

      def type_error(message, node: nil, origin: nil)
        origin ||= node&.origin
        origin ||= @current_node&.origin
        raise Aurora::CompileError.new(message, origin: origin)
      end

      def with_current_node(node)
        previous = @current_node
        @current_node = node if node
        yield
      ensure
        @current_node = previous
      end

      def type_name(type)
        type&.name
      end

      def describe_type(type)
        normalized_type_name(type_name(type)) || "unknown"
      end

      def normalized_type_name(name)
        case name
        when "str"
          "string"
        else
          name
        end
      end

      def generic_type_name?(name)
        name && name.match?(/\A[A-Z][A-Za-z0-9_]*\z/)
      end

      def void_type?(type)
        normalized_type_name(type_name(type)) == "void"
      end

      def numeric_type?(type)
        type_str = normalized_type_name(type_name(type))
        return true if NUMERIC_PRIMITIVES.include?(type_str)

        # Check if this is a generic type parameter with Numeric constraint
        type_param = @current_type_params.find { |tp| tp.name == type_str }
        type_param && type_param.constraint == "Numeric"
      end

      def float_type?(type)
        normalized_type_name(type_name(type)) == "f32"
      end

      def string_type?(type)
        %w[string str].include?(normalized_type_name(type_name(type)))
      end

      def ensure_numeric_type(type, context, node: nil)
        name = normalized_type_name(type_name(type))
        return if generic_type_name?(name)
        type_error("#{context} must be numeric, got #{describe_type(type)}", node: node) unless numeric_type?(type)
      end

      def ensure_boolean_type(type, context, node: nil)
        name = normalized_type_name(type_name(type))
        return if generic_type_name?(name)
        type_error("#{context} must be bool, got #{describe_type(type)}", node: node) unless name == "bool"
      end

      def combine_numeric_type(left_type, right_type)
        if type_name(left_type) == type_name(right_type)
          left_type
        elsif float_type?(left_type) || float_type?(right_type)
          CoreIR::Builder.primitive_type("f32")
        else
          type_error("Numeric operands must have matching types, got #{describe_type(left_type)} and #{describe_type(right_type)}")
        end
      end

      def ensure_compatible_type(actual, expected, context, node: nil)
        ensure_type!(actual, "#{context} has unknown type", node: node)
        ensure_type!(expected, "#{context} has unspecified expected type", node: node)

        actual_name = normalized_type_name(type_name(actual))
        expected_name = normalized_type_name(type_name(expected))

        return if expected_name.nil? || expected_name.empty?
        return if expected_name == "auto"
        return if generic_type_name?(expected_name)
        return if actual_name == "auto"
        return if actual_name == expected_name

        type_error("#{context} expected #{expected_name}, got #{actual_name}", node: node)
      end

      def validate_function_call(info, args, name)
        expected = info.param_types || []
        return if expected.empty?

        if expected.length != args.length
          type_error("Function '#{name}' expects #{expected.length} argument(s), got #{args.length}")
        end

        expected.each_with_index do |type, index|
          ensure_compatible_type(args[index].type, type, "argument #{index + 1} of '#{name}'")
        end
      end

      def ensure_argument_count(member, args, expected)
        return if args.length == expected

        type_error("Method '#{member}' expects #{expected} argument(s), got #{args.length}")
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

      def transform_do_expr(expr)
        # Transform do-block: do expr1; expr2; ...; exprN end
        # Returns the value of the last expression
        return CoreIR::Builder.literal(nil, CoreIR::Builder.primitive_type("void")) if expr.body.empty?

        statements = []
        expr.body[0..-2].each do |e|
          statements << CoreIR::Builder.expr_statement(transform_expression(e))
        end

        # Last expression is the result value
        result_expr = transform_expression(expr.body.last)
        CoreIR::Builder.block_expr(statements, result_expr, result_expr.type)
      end
    end
  end
end
