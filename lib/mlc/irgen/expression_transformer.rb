# frozen_string_literal: true

module MLC
  class IRGen
      # ExpressionTransformer
      # Expression transformation from AST to HighIR
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
            field_type = field_types[idx] || HighIR::Builder.primitive_type("auto")
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
            @var_types[binding] = HighIR::Builder.primitive_type("string")
          end
        end
      end

      def expected_lambda_param_types(object_ir, member_name, transformed_args, index)
        return [] unless object_ir && member_name

        object_type = object_ir.type
        return [] unless object_type

        case member_name
        when "map"
          if index.zero? && object_type.is_a?(HighIR::ArrayType)
            [object_type.element_type]
          else
            []
          end
        when "filter"
          if index.zero? && object_type.is_a?(HighIR::ArrayType)
            [object_type.element_type]
          else
            []
          end
        when "fold"
          if index == 1 && object_type.is_a?(HighIR::ArrayType)
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
        elsif arg.respond_to?(:type) && arg.type.is_a?(HighIR::FunctionType)
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
                         HighIR::Builder.primitive_type("i32")
                       end

        elements.each_with_index do |elem, index|
          next if index.zero?
          ensure_compatible_type(elem.type, element_type, "array element #{index}")
        end

        # Create array type
        array_type = HighIR::ArrayType.new(element_type: element_type)

        HighIR::ArrayLiteralExpr.new(
          elements: elements,
          type: array_type
        )
      end

      def transform_do_expr(expr)
        # Normalise legacy do-blocks into BlockExpr nodes so the statement
        # transformer can handle all control-flow consistently.
        if expr.body.empty?
          block = AST::BlockExpr.new(
            statements: [],
            result_expr: AST::UnitLit.new(origin: expr.origin),
            origin: expr.origin
          )
          return transform_block_expr(block)
        end

        statements = []
        result_expr = nil

        expr.body.each_with_index do |item, index|
          is_last = (index == expr.body.length - 1)

          node = if item.is_a?(AST::Let) && item.body.nil?
                   AST::VariableDecl.new(
                     name: item.name,
                     value: item.value,
                     mutable: item.mutable,
                     type: item.type,
                     origin: item.origin
                   )
                 else
                   item
                 end

          case node
          when AST::Stmt
            statements << node
            result_expr = AST::UnitLit.new(origin: node.origin) if is_last
          when AST::WhileLoop
            if is_last
              statements << AST::ExprStmt.new(expr: node, origin: node.origin)
              result_expr = AST::UnitLit.new(origin: node.origin)
            else
              statements << AST::ExprStmt.new(expr: node, origin: node.origin)
            end
          else
            if is_last
              result_expr = node
            else
              statements << AST::ExprStmt.new(expr: node, origin: node.origin)
            end
          end
        end

        result_expr ||= AST::UnitLit.new(origin: expr.origin)
        block = AST::BlockExpr.new(statements: statements, result_expr: result_expr, origin: expr.origin)
        transform_block_expr(block)
      end

      def transform_block_expr(block_expr)
        # Block expressions reuse the statement pipeline so that we handle the full
        # range of statements (return, break, nested blocks, etc.) consistently.
        # We preserve scope during transformation to allow the trailing expression
        # to see variables defined in the statement portion, and restore the outer
        # scope afterwards to avoid leaking bindings.
        saved_var_types = @var_types.dup

        statements_ir = transform_statements(block_expr.statements)
        result_ir = transform_expression(block_expr.result_expr)
        block_type = result_ir&.type || HighIR::Builder.unit_type

        HighIR::Builder.block_expr(statements_ir, result_ir, block_type)
      ensure
        @var_types = saved_var_types
      end

      def module_member_function_entry(object_node, member_name)
        return unless object_node.is_a?(AST::VarRef)
        module_member_entry(object_node.name, member_name)
      end

      def apply_expression_rules(expr)
        context = {
          transformer: self,
          type_registry: @type_registry,
          function_registry: @function_registry,
          rule_engine: @rule_engine,
          expression_transformer: @expression_transformer_service,
          type_checker: @type_checker_service,
          predicates: @predicate_service,
          context_manager: @context_manager_service,
          type_inference: @type_inference_service,
          record_builder: @record_builder_service
        }
        @rule_engine.apply(:core_ir_expression, expr, context: context)
      end

      def transform_expression(expr)
        with_current_node(expr) do
          result = apply_expression_rules(expr)
          return result unless result.equal?(expr)

          case expr
          when AST::IntLit
            transform_literal(expr)
          when AST::UnitLit
            transform_literal(expr)
          when AST::FloatLit
            transform_literal(expr)
          when AST::StringLit
            transform_literal(expr)
          when AST::RegexLit
            transform_literal(expr)
          when AST::VarRef
            transform_var_ref(expr)
          when AST::BinaryOp
            transform_binary(expr)
          when AST::UnaryOp
            transform_unary(expr)
          when AST::Call
            transform_call(expr)
          when AST::MemberAccess
            transform_member_access(expr)
          when AST::Let
            transform_let(expr)
          when AST::RecordLit
            transform_record_literal(expr)
          when AST::IfExpr
            transform_if_expr(expr)
          when AST::MatchExpr
            transform_match_expr(expr)
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
          when AST::BlockExpr
            transform_block_expr(expr)
          else
            raise "Unknown expression: #{expr.class}"
          end
        end
      end

      def transform_for_loop(for_loop)
        loop_stmt = transform_for_statement(for_loop)
        unit_result = HighIR::Builder.unit_literal(origin: for_loop.origin)
        HighIR::Builder.block_expr(
          [loop_stmt],
          unit_result,
          unit_result.type,
          origin: for_loop.origin
        )
      end

      def transform_literal(expr)
        case expr
        when AST::IntLit
          type = HighIR::Builder.primitive_type("i32")
          HighIR::Builder.literal(expr.value, type)
        when AST::FloatLit
          type = HighIR::Builder.primitive_type("f32")
          HighIR::Builder.literal(expr.value, type)
        when AST::StringLit
          type = HighIR::Builder.primitive_type("string")
          HighIR::Builder.literal(expr.value, type)
        when AST::RegexLit
          type = HighIR::Builder.primitive_type("regex")
          HighIR::Builder.regex(expr.pattern, expr.flags, type)
        when AST::UnitLit
          HighIR::Builder.unit_literal
        else
          raise "Unsupported literal expression: #{expr.class}"
        end
      end

      def transform_var_ref(expr)
        type = infer_type(expr.name)
        HighIR::Builder.var(expr.name, type)
      end

      def transform_binary(expr)
        return transform_pipe(expr) if expr.op == "|>"

        left = transform_expression(expr.left)
        right = transform_expression(expr.right)
        type = infer_binary_type(expr.op, left.type, right.type)
        HighIR::Builder.binary(expr.op, left, right, type)
      end

      def transform_unary(expr)
        operand = transform_expression(expr.operand)
        type = infer_unary_type(expr.op, operand.type)
        HighIR::Builder.unary(expr.op, operand, type)
      end

      def transform_member_access(expr)
        if (entry = module_member_function_entry(expr.object, expr.member))
          canonical_name = entry.name
          HighIR::Builder.var(canonical_name, function_placeholder_type(canonical_name))
        else
          object = transform_expression(expr.object)
          type = infer_member_type(object.type, expr.member)
          HighIR::Builder.member(object, expr.member, type)
        end
      end

      def transform_call(expr)
        if expr.callee.is_a?(AST::VarRef) && IO_RETURN_TYPES.key?(expr.callee.name)
          callee = transform_expression(expr.callee)
          args = expr.args.map { |arg| transform_expression(arg) }
          type = io_return_type(expr.callee.name)
          HighIR::Builder.call(callee, args, type)
        else
          callee_ast = expr.callee
          object_ir = nil
          member_name = nil

          if callee_ast.is_a?(AST::MemberAccess)
            entry = module_member_function_entry(callee_ast.object, callee_ast.member)
            if entry
              canonical_name = entry.name
              callee = HighIR::Builder.var(canonical_name, function_placeholder_type(canonical_name))
            else
              object_ir = transform_expression(callee_ast.object)
              member_name = callee_ast.member
              callee = HighIR::Builder.member(object_ir, member_name, infer_member_type(object_ir.type, member_name))
            end
          elsif callee_ast.is_a?(AST::VarRef)
            var_type = function_placeholder_type(callee_ast.name)
            callee = HighIR::Builder.var(callee_ast.name, var_type)
          else
            callee = transform_expression(callee_ast)
          end

          args = []
          expr.args.each_with_index do |arg, index|
            expected_params = expected_lambda_param_types(object_ir, member_name, args, index)
            transformed_arg = if arg.is_a?(AST::Lambda)
              with_lambda_param_types(expected_params) do
                transform_expression(arg)
              end
            else
              transform_expression(arg)
            end
            args << transformed_arg
          end

          type = infer_call_type(callee, args)
          HighIR::Builder.call(callee, args, type)
        end
      end

      def transform_let(expr)
        # Re-express `let` bindings as block expressions so statement handling
        # (type annotations, mutability checks, scope management) flows through
        # the same code paths as regular blocks.
        variable_decl = AST::VariableDecl.new(
          name: expr.name,
          value: expr.value,
          mutable: expr.mutable,
          type: expr.type,
          origin: expr.origin
        )

        block = AST::BlockExpr.new(
          statements: [variable_decl],
          result_expr: expr.body,
          origin: expr.origin
        )

        transform_block_expr(block)
      end

      def transform_record_literal(expr)
        fields = expr.fields.transform_keys { |key| key.to_s }.transform_values { |value| transform_expression(value) }

        if expr.type_name == "record"
          infer_record_from_context(fields) ||
            infer_record_from_registry(fields) ||
            build_anonymous_record(fields)
        else
          build_named_record(expr.type_name, fields)
        end
      end

      def transform_if_expr(expr)
        condition_ir = transform_expression(expr.condition)
        ensure_boolean_type(condition_ir.type, "if condition", node: expr.condition)

        if unit_branch_ast?(expr.then_branch) && (expr.else_branch.nil? || unit_branch_ast?(expr.else_branch))
          then_block_ir = transform_statement_block(expr.then_branch)
          else_block_ir = expr.else_branch ? transform_statement_block(expr.else_branch) : nil
          if_stmt = HighIR::Builder.if_stmt(condition_ir, then_block_ir, else_block_ir)
          unit_literal = HighIR::Builder.unit_literal
          HighIR::Builder.block_expr([if_stmt], unit_literal, unit_literal.type)
        else
          then_branch_ir = transform_expression(expr.then_branch)
          else_branch_ir = expr.else_branch ? transform_expression(expr.else_branch) : nil

          type = if else_branch_ir
                   ensure_compatible_type(else_branch_ir.type, then_branch_ir.type, "if expression branches")
                   then_branch_ir.type
                 else
                   HighIR::Builder.unit_type
                 end

          HighIR::Builder.if_expr(condition_ir, then_branch_ir, else_branch_ir, type)
        end
      end

      def transform_index_access(index_access)
        # Transform array indexing: arr[index]
        object = transform_expression(index_access.object)
        index = transform_expression(index_access.index)

        unless object.type.is_a?(HighIR::ArrayType)
          type_error("Indexing requires an array, got #{describe_type(object.type)}", node: index_access.object)
        end

        ensure_numeric_type(index.type, "array index", node: index_access.index)

        result_type = object.type.element_type

        HighIR::IndexExpr.new(
          object: object,
          index: index,
          type: result_type
        )
      end

      def transform_lambda(lambda_expr)
        saved_var_types = @var_types.dup

        expected_param_types = current_lambda_param_types

        params = lambda_expr.params.each_with_index.map do |param, index|
          if param.is_a?(AST::LambdaParam)
            param_type = if param.type
                           transform_type(param.type)
                         elsif expected_param_types[index]
                           expected_param_types[index]
                         else
                           HighIR::Builder.primitive_type("i32")
                         end
            @var_types[param.name] = param_type
            HighIR::Param.new(name: param.name, type: param_type)
          else
            param_name = param.respond_to?(:name) ? param.name : param
            param_type = expected_param_types[index] || HighIR::Builder.primitive_type("i32")
            @var_types[param_name] = param_type
            HighIR::Param.new(name: param_name, type: param_type)
          end
        end

        body = transform_expression(lambda_expr.body)

        ret_type = body.type

        param_types = params.map { |p| {name: p.name, type: p.type} }
        function_type = HighIR::FunctionType.new(
          params: param_types,
          ret_type: ret_type
        )

        captures = []

        HighIR::LambdaExpr.new(
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
        element_type = output_expr.type || HighIR::Builder.primitive_type("i32")

        array_type = HighIR::ArrayType.new(element_type: element_type)

        HighIR::ListCompExpr.new(
          element_type: element_type,
          generators: generators,
          filters: filters,
          output_expr: output_expr,
          type: array_type
        )
      ensure
        @var_types = saved_var_types
      end

      def infer_record_from_context(fields)
        nil
      end

      def infer_record_from_registry(fields)
        return nil unless @type_registry

        candidates = @type_registry.types.each_value.filter_map do |type_info|
          next unless type_info.record?

          type_decl = @type_decl_table[type_info.name]
          construct_record_from_info(type_info.name, type_info, fields, type_decl)
        end

        select_best_record_candidate(candidates)
      end

      def build_anonymous_record(fields)
        inferred_fields = fields.map { |name, value| {name: name.to_s, type: value.type} }
        record_type = HighIR::Builder.record_type("record", inferred_fields)
        HighIR::Builder.record("record", fields, record_type)
      end

      def build_named_record(type_name, fields)
        if @type_registry && (type_info = @type_registry.lookup(type_name))
          type_decl = @type_decl_table[type_name]
          constructed = construct_record_from_info(type_name, type_info, fields, type_decl)
          return constructed[:record] if constructed

          base_type = type_info.core_ir_type
        end

        unless defined?(base_type) && base_type
          inferred_fields = fields.map { |name, value| {name: name.to_s, type: value.type} }
          base_type = HighIR::Builder.record_type(type_name, inferred_fields)
        end

        HighIR::Builder.record(type_name, fields, base_type)
      end

      def construct_record_from_info(type_name, type_info, fields, type_decl)
        record_fields = Array(type_info.fields)
        return nil if record_fields.empty?

        literal_field_names = fields.keys.map(&:to_s)
        info_field_names = record_fields.map { |field| field[:name].to_s }
        return nil unless literal_field_names == info_field_names

        type_map = {}

        record_fields.each do |field|
          field_name = field[:name].to_s
          literal_expr = fields[field_name] || fields[field[:name]]
          return nil unless literal_expr

          literal_type = literal_expr.type
          return nil unless literal_type

          matched = unify_type(field[:type], literal_type, type_map, context: "field '#{field_name}' of '#{type_name}'")
          return nil unless matched
        end

        type_params = Array(type_decl&.type_params)
        type_args = if type_params.any?
                      type_params.map do |tp|
                        inferred = type_map[tp.name]
                        return nil unless inferred
                        inferred
                      end
                    else
                      []
                    end

        record_type = if type_args.any?
                        HighIR::Builder.generic_type(type_info.core_ir_type, type_args)
                      else
                        type_info.core_ir_type
                      end

        record_expr = HighIR::Builder.record(type_name, fields, record_type)
        concreteness = type_args.count { |arg| !arg.is_a?(HighIR::TypeVariable) }

        {record: record_expr, concreteness: concreteness}
      end

      def select_best_record_candidate(candidates)
        return nil if candidates.empty?
        best = candidates.max_by { |candidate| candidate[:concreteness] }
        best && best[:record]
      end

      def unify_type(pattern, actual, type_map, context:)
        return false unless pattern && actual

        case pattern
        when HighIR::TypeVariable
          existing = type_map[pattern.name]
          if existing
            type_equivalent?(existing, actual)
          else
            type_map[pattern.name] = actual
            true
          end
        when HighIR::GenericType
          return false unless actual.is_a?(HighIR::GenericType)
          pattern_base = type_name(pattern.base_type)
          actual_base = type_name(actual.base_type)
          return false unless pattern_base == actual_base

          pattern.type_args.zip(actual.type_args).all? do |pattern_arg, actual_arg|
            unify_type(pattern_arg, actual_arg, type_map, context: context)
          end
        when HighIR::ArrayType
          return false unless actual.is_a?(HighIR::ArrayType)
          unify_type(pattern.element_type, actual.element_type, type_map, context: context)
        else
          type_equivalent?(pattern, actual)
        end
      end

      def type_equivalent?(left, right)
        return false if left.nil? || right.nil?
        return true if left.equal?(right)

        if left.is_a?(HighIR::TypeVariable) && right.is_a?(HighIR::TypeVariable)
          return left.name == right.name
        end

        if left.is_a?(HighIR::GenericType) && right.is_a?(HighIR::GenericType)
          left_base = type_name(left.base_type)
          right_base = type_name(right.base_type)
          return false unless left_base == right_base
          return false unless left.type_args.length == right.type_args.length

          return left.type_args.zip(right.type_args).all? { |l_arg, r_arg| type_equivalent?(l_arg, r_arg) }
        end

        if left.is_a?(HighIR::ArrayType) && right.is_a?(HighIR::ArrayType)
          return type_equivalent?(left.element_type, right.element_type)
        end

        type_name(left) == type_name(right)
      end

      def transform_match_expr(match_expr)
        scrutinee_ir = transform_expression(match_expr.scrutinee)

        if match_stmt_applicable?(match_expr)
          return transform_match_expr_to_statement(match_expr, scrutinee_ir)
        end

        transform_match_expr_core(match_expr, scrutinee_ir)
      end

      def transform_match_expr_core(match_expr, scrutinee_ir = nil)
        scrutinee_ir ||= transform_expression(match_expr.scrutinee)

        result = @rule_engine.apply(
          :core_ir_match_expr,
          match_expr,
          context: {
            scrutinee: scrutinee_ir,
            match_analyzer: @match_analyzer,
            transform_arm: method(:transform_match_arm)
          }
        )

        unless result.is_a?(HighIR::MatchExpr)
          raise "Match rule must produce HighIR::MatchExpr, got #{result.class}"
        end

        result
      end

      def transform_match_expr_to_statement(match_expr, scrutinee_ir)
        arms = match_expr.arms.map do |arm|
          transform_match_arm_statement(scrutinee_ir.type, arm)
        end

        match_stmt = HighIR::Builder.match_stmt(scrutinee_ir, arms, origin: match_expr.origin)
        unit_literal = HighIR::Builder.unit_literal(origin: match_expr.origin)
        HighIR::Builder.block_expr([match_stmt], unit_literal, unit_literal.type, origin: match_expr.origin)
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

      def transform_match_arm_statement(scrutinee_type, arm)
        saved_var_types = @var_types.dup
        pattern = transform_pattern(arm[:pattern])
        bind_pattern_variables(pattern, scrutinee_type)
        guard_ir = arm[:guard] ? transform_expression(arm[:guard]) : nil
        body_ir = transform_statement_block(arm[:body])
        {pattern: pattern, guard: guard_ir, body: body_ir}
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

          HighIR::Builder.call(callee, all_args, type)
        else
          # right is just a function name => f(left)
          callee = transform_expression(pipe_expr.right)
          type = infer_call_type(callee, [left])

          HighIR::Builder.call(callee, [left], type)
        end
      end

      def unit_branch_ast?(node)
        node.is_a?(AST::BlockExpr) && node.result_expr.is_a?(AST::UnitLit)
      end

      def match_stmt_applicable?(match_expr)
        match_expr.arms.all? do |arm|
          unit_branch_ast?(arm[:body]) &&
            arm[:guard].nil? &&
            match_stmt_safe_pattern?(arm[:pattern])
        end
      end

      def match_stmt_safe_pattern?(pattern)
        kind = pattern.kind
        return false if kind == :regex
        %i[constructor wildcard var].include?(kind)
      end

      def transform_while_loop(while_loop)
        loop_stmt = transform_while_statement(while_loop.condition, while_loop.body)
        unit_result = HighIR::Builder.unit_literal(origin: while_loop.origin)
        HighIR::Builder.block_expr(
          [loop_stmt],
          unit_result,
          unit_result.type,
          origin: while_loop.origin
        )
      end

      end
  end
end
