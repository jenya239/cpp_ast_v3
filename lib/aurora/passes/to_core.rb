# frozen_string_literal: true

require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"

module Aurora
  module Passes
    class ToCore
      def initialize
        @type_table = {}
        @function_table = {}
        @var_types = {}  # Track variable types for let bindings
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
        CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: decl.type_params)
      end
      
      def transform_function(func)
        params = func.params.map { |param| transform_param(param) }
        ret_type = transform_type(func.ret_type)
        body = transform_expression(func.body)

        CoreIR::Func.new(
          name: func.name,
          params: params,
          ret_type: ret_type,
          body: body,
          effects: infer_effects(body),
          type_params: func.type_params
        )
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
        when AST::Call
          callee = transform_expression(expr.callee)
          args = expr.args.map { |arg| transform_expression(arg) }
          type = infer_call_type(callee, args)
          CoreIR::Builder.call(callee, args, type)
        when AST::MemberAccess
          object = transform_expression(expr.object)
          type = infer_member_type(object.type, expr.member)
          CoreIR::Builder.member(object, expr.member, type)
        when AST::Let
          value = transform_expression(expr.value)
          # Save the type of the bound variable
          @var_types[expr.name] = value.type
          body = transform_expression(expr.body)
          # Clean up after processing body
          @var_types.delete(expr.name)
          type = body.type
          CoreIR::Builder.let(expr.name, value, body, type)
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
        when AST::ArrayLiteral
          transform_array_literal(expr)
        when AST::IndexAccess
          transform_index_access(expr)
        else
          raise "Unknown expression: #{expr.class}"
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
        # Transform lambda parameters
        params = lambda_expr.params.map do |param_name|
          # For now, infer param type as i32 (will be improved with proper type inference)
          param_type = CoreIR::Builder.primitive_type("i32")
          CoreIR::Param.new(name: param_name, type: param_type)
        end

        # Transform body
        body = transform_expression(lambda_expr.body)

        # Infer return type from body
        ret_type = body.type

        # Build function type
        param_types = params.map { |p| {name: p.name, type: p.type} }
        function_type = CoreIR::FunctionType.new(
          params: param_types,
          ret_type: ret_type
        )

        # For now, no captures (simple lambdas only)
        # TODO: Implement proper capture analysis
        captures = []

        CoreIR::LambdaExpr.new(
          captures: captures,
          params: params,
          body: body,
          function_type: function_type
        )
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
        else
          raise "Unknown pattern kind: #{pattern.kind}"
        end
      end
      
      def infer_type(name)
        # Check if this is a known variable from a let binding
        if @var_types.key?(name)
          return @var_types[name]
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
      
      def infer_call_type(callee, args)
        # Simple inference - in real implementation would check function signatures
        case callee
        when CoreIR::VarExpr
          # Simple function call like sqrt(x)
          if callee.name == "sqrt"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when CoreIR::MemberExpr
          # Method call like (expr).sqrt()
          if callee.member == "sqrt"
            CoreIR::Builder.primitive_type("f32")
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
        when CoreIR::CallExpr
          # Assume all calls are pure for now
          true
        when CoreIR::MemberExpr
          is_pure_expression(expr.object)
        when CoreIR::LetExpr
          is_pure_expression(expr.value) && is_pure_expression(expr.body)
        when CoreIR::RecordExpr
          expr.fields.values.all? { |field| is_pure_expression(field) }
        else
          false
        end
      end
    end
  end
end
