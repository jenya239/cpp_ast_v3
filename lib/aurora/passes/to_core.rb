# frozen_string_literal: true

require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"

module Aurora
  module Passes
    class ToCore
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
        @var_types = {}  # Track variable types for let bindings
        @temp_counter = 0
        @loop_depth = 0
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

        # Transform declarations
        program.declarations.each do |decl|
          case decl
          when AST::TypeDecl
            @type_decl_table[decl.name] = decl
            type_decl = transform_type_decl(decl)
            items << type_decl
            @type_table[decl.name] = type_decl.type
          when AST::FuncDecl
            func = transform_function(decl)
            items << func
            @function_table[decl.name] = func
          end
        end

        # Get module name from module declaration or default to "main"
        module_name = program.module_decl ? program.module_decl.name : "main"

        CoreIR::Module.new(name: module_name, items: items, imports: imports)
      end
      
      def transform_type_decl(decl)
        type = transform_type(decl.type)

        type = case type
               when CoreIR::RecordType
                 CoreIR::Builder.record_type(decl.name, type.fields)
               when CoreIR::SumType
                 CoreIR::Builder.sum_type(decl.name, type.variants)
               else
                 type
               end
        type_params = normalize_type_params(decl.type_params)
        CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: type_params)
      end
      
      def transform_function(func)
        params = func.params.map { |param| transform_param(param) }
        ret_type = transform_type(func.ret_type)
        saved_var_types = @var_types.dup

        params.each do |param|
          @var_types[param.name] = param.type
        end

        body = transform_expression(func.body)

        type_params = normalize_type_params(func.type_params)

        CoreIR::Func.new(
          name: func.name,
          params: params,
          ret_type: ret_type,
          body: body,
          effects: infer_effects(body),
          type_params: type_params
        )
      ensure
        @var_types = saved_var_types if defined?(saved_var_types)
      end

      def normalize_type_params(params)
        params.map do |tp|
          name = tp.respond_to?(:name) ? tp.name : tp
          constraint = tp.respond_to?(:constraint) ? tp.constraint : nil
          validate_constraint_name(constraint)
          CoreIR::TypeParam.new(name: name, constraint: constraint)
        end
      end
      
      def transform_param(param)
        type = transform_type(param.type)
        CoreIR::Param.new(name: param.name, type: type)
      end
      
      def transform_type(type)
        case type
        when AST::PrimType
          # Check if this is a type parameter (uppercase single letter like T, E, R)
          # or starts with uppercase (could be a type parameter)
          # For now, treat all PrimTypes the same - will be resolved by C++ compiler
          CoreIR::Builder.primitive_type(type.name)
        when AST::GenericType
          # Generic type like Option<T> or Result<T, E>
          # In C++, this becomes: Option<T> (template instantiation)
          # For CoreIR, we represent as a special generic type
          base_name = type.base_type.name
          validate_type_constraints(base_name, type.type_params)
          type_arg_names = type.type_params.map { |tp| transform_type(tp).name }.join(", ")
          # Create a synthetic name for the instantiated generic type
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

      def transform_expression(expr)
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
            callee = transform_expression(expr.callee)
            args = expr.args.map { |arg| transform_expression(arg) }
            type = infer_call_type(callee, args)
            CoreIR::Builder.call(callee, args, type)
          end
        when AST::MemberAccess
          object = transform_expression(expr.object)
          type = infer_member_type(object.type, expr.member)
          CoreIR::Builder.member(object, expr.member, type)
        when AST::Let
          value = transform_expression(expr.value)
          previous = @var_types[expr.name]
          @var_types[expr.name] = value.type
          body = transform_expression(expr.body)
          statements = [
            CoreIR::Builder.variable_decl_stmt(expr.name, value.type, value, mutable: expr.mutable)
          ]
          result = CoreIR::Builder.block_expr(statements, body, body.type)
          if previous
            @var_types[expr.name] = previous
          else
            @var_types.delete(expr.name)
          end
          result
        when AST::RecordLit
          type = @type_table[expr.type_name]
          fields = expr.fields.transform_values { |value| transform_expression(value) }
          CoreIR::Builder.record(expr.type_name, fields, type)
        when AST::IfExpr
          condition = transform_expression(expr.condition)
          then_branch = transform_expression(expr.then_branch)
          else_branch = expr.else_branch ? transform_expression(expr.else_branch) : nil
          type = then_branch.type  # Type inference: result type is from then branch
          CoreIR::Builder.if_expr(condition, then_branch, else_branch, type)
        when AST::MatchExpr
          scrutinee = transform_expression(expr.scrutinee)
          arms = expr.arms.map do |arm|
            pattern = transform_pattern(arm[:pattern])
            guard = arm[:guard] ? transform_expression(arm[:guard]) : nil
            body = transform_expression(arm[:body])
            {pattern: pattern, guard: guard, body: body}
          end
          # Type inference: use type from first arm body
          type = arms.first[:body].type
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
        else
          raise "Unknown expression: #{expr.class}"
        end
      end

      def validate_constraint_name(name)
        return if name.nil? || name.empty?
        return if BUILTIN_CONSTRAINTS.key?(name)

        raise Aurora::CompileError, "Unknown constraint '#{name}'"
      end

      def validate_type_constraints(base_name, actual_type_nodes)
        decl = @type_decl_table[base_name]
        return unless decl && decl.type_params.any?

        decl.type_params.zip(actual_type_nodes).each do |param_info, actual_node|
          next unless param_info.respond_to?(:constraint) && param_info.constraint && !param_info.constraint.empty?

          actual_name = extract_actual_type_name(actual_node)
          next if actual_name.nil?

          unless type_satisfies_constraint?(param_info.constraint, actual_name)
            raise Aurora::CompileError, "Type '#{actual_name}' does not satisfy constraint '#{param_info.constraint}' for '#{param_info.name}'"
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
        saved_var_types = @var_types.dup
        if block.stmts.empty?
          if require_value
            raise Aurora::CompileError, "Block must end with an expression"
          else
            return CoreIR::Builder.block_expr(
              [],
              nil,
              CoreIR::Builder.primitive_type("void")
            )
          end
        end

        statements = block.stmts.dup
        result_ir = nil

        if require_value
          tail = statements.pop
          case tail
          when AST::ExprStmt
            result_ir = transform_expression(tail.expr)
          when AST::Return
            statements << tail
            result_ir = nil
          else
            statements << tail if tail
            result_ir = nil
          end
        end

        statement_nodes = transform_statements(statements)
        block_type = result_ir ? result_ir.type : CoreIR::Builder.primitive_type("void")
        CoreIR::Builder.block_expr(statement_nodes, result_ir, block_type)
      ensure
        @var_types = saved_var_types if defined?(saved_var_types)
      end

      def transform_statements(statements)
        statements.each_with_object([]) do |stmt, acc|
          case stmt
          when AST::ExprStmt
            acc.concat(transform_expr_statement(stmt))
          when AST::VariableDecl
            value_ir = transform_expression(stmt.value)
            previous = @var_types[stmt.name]
            @var_types[stmt.name] = value_ir.type
            acc << CoreIR::Builder.variable_decl_stmt(
              stmt.name,
              value_ir.type,
              value_ir,
              mutable: stmt.mutable
            )
          when AST::Assignment
            unless stmt.target.is_a?(AST::VarRef)
              raise Aurora::CompileError, "Assignment target must be a variable"
            end
            target_name = stmt.target.name
            existing_type = @var_types[target_name]
            raise Aurora::CompileError, "Assignment to undefined variable '#{target_name}'" unless existing_type

            value_ir = transform_expression(stmt.value)
            @var_types[target_name] = value_ir.type
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
            raise Aurora::CompileError, "'break' used outside of loop" if @loop_depth.to_i <= 0
            acc << CoreIR::Builder.break_stmt
          when AST::Continue
            raise Aurora::CompileError, "'continue' used outside of loop" if @loop_depth.to_i <= 0
            acc << CoreIR::Builder.continue_stmt
          when AST::Block
            nested = transform_block(stmt, require_value: false)
            acc.concat(nested.statements)
          else
            raise Aurora::CompileError, "Unsupported statement: #{stmt.class}"
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
        then_ir = transform_statement_block(then_node)
        else_ir = else_node ? transform_statement_block(else_node) : nil
        CoreIR::Builder.if_stmt(condition_ir, then_ir, else_ir)
      end

      def transform_while_statement(condition_node, body_node)
        condition_ir = transform_expression(condition_node)
        body_ir = within_loop_scope { transform_statement_block(body_node) }
        CoreIR::Builder.while_stmt(condition_ir, body_ir)
      end

      def transform_return_statement(stmt)
        expr_ir = stmt.expr ? transform_expression(stmt.expr) : nil
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

        # Infer result type
        # If object is an array, result type is the element type
        result_type = if object.type.is_a?(CoreIR::ArrayType)
                        object.type.element_type
                      else
                        # Default fallback
                        CoreIR::Builder.primitive_type("i32")
                      end

        CoreIR::IndexExpr.new(
          object: object,
          index: index,
          type: result_type
        )
      end

      def transform_lambda(lambda_expr)
        saved_var_types = @var_types.dup

        params = lambda_expr.params.map do |param|
          if param.is_a?(AST::LambdaParam)
            param_type = param.type ? transform_type(param.type) : CoreIR::Builder.primitive_type("i32")
            @var_types[param.name] = param_type
            CoreIR::Param.new(name: param.name, type: param_type)
          else
            param_name = param.respond_to?(:name) ? param.name : param
            param_type = CoreIR::Builder.primitive_type("i32")
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

          element_type = if iterable_ir.type.is_a?(CoreIR::ArrayType)
                           iterable_ir.type.element_type
                         else
                           iterable_ir.type || CoreIR::Builder.primitive_type("i32")
                         end

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
      
      def infer_type(name)
        # Check if this is a known variable from a let binding
        if @var_types.key?(name)
          return @var_types[name]
        end

        # Check for known functions
        if @function_table.key?(name)
          func = @function_table[name]
          param_types = func.params.map { |param| {name: param.name, type: param.type} }
          return CoreIR::Builder.function_type(param_types, func.ret_type)
        end

        # Simple type inference - in real implementation would be more sophisticated
        case name
        when "sqrt"
          params = [CoreIR::Builder.primitive_type("f32")]
          ret_type = CoreIR::Builder.primitive_type("f32")
          CoreIR::Builder.function_type(params, ret_type)
        else
          # Default to i32 for now
          CoreIR::Builder.primitive_type("i32")
        end
      end
      
      def infer_binary_type(op, left_type, right_type)
        case op
        when "+", "-", "*", "/", "%"
          # Numeric operations
          if left_type.name == "f32" || right_type.name == "f32"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when "==", "!=", "<", ">", "<=", ">="
          CoreIR::Builder.primitive_type("bool")
        else
          left_type
        end
      end

      def infer_unary_type(op, operand_type)
        case op
        when "!"
          CoreIR::Builder.primitive_type("bool")
        when "-", "+"
          operand_type
        else
          operand_type
        end
      end
      
      def infer_call_type(callee, args)
        case callee
        when CoreIR::VarExpr
          if @function_table.key?(callee.name)
            @function_table[callee.name].ret_type
          elsif callee.name == "sqrt"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when CoreIR::MemberExpr
          object_type = callee.object&.type
          member = callee.member

          if object_type.is_a?(CoreIR::ArrayType)
            case member
            when "length", "size"
              CoreIR::Builder.primitive_type("i32")
            when "is_empty"
              CoreIR::Builder.primitive_type("bool")
            when "map"
              element_type = lambda_return_type(args.first) || object_type.element_type || CoreIR::Builder.primitive_type("auto")
              CoreIR::ArrayType.new(
                element_type: element_type
              )
            when "filter"
              CoreIR::ArrayType.new(
                element_type: object_type.element_type
              )
            when "fold"
              args.first ? args.first.type : CoreIR::Builder.primitive_type("i32")
            else
              CoreIR::Builder.primitive_type("i32")
            end
          elsif object_type && %w[string str].include?(object_type.name)
            case member
            when "split"
              CoreIR::ArrayType.new(
                element_type: CoreIR::Builder.primitive_type("string")
              )
            when "trim", "trim_start", "trim_end", "upper", "lower"
              CoreIR::Builder.primitive_type("string")
            when "is_empty"
              CoreIR::Builder.primitive_type("bool")
            when "length"
              CoreIR::Builder.primitive_type("i32")
            else
              CoreIR::Builder.primitive_type("string")
            end
          else
            CoreIR::Builder.primitive_type("i32")
          end
        else
          CoreIR::Builder.primitive_type("i32")
        end
      end
      
      def infer_member_type(object_type, member)
        # Simple inference for record types
        if object_type.record?
          field = object_type.fields.find { |f| f[:name] == member }
          field ? field[:type] : CoreIR::Builder.primitive_type("i32")
        else
          CoreIR::Builder.primitive_type("i32")
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
          CoreIR::Builder.primitive_type("i32")
        end
      end
    end
  end
end
