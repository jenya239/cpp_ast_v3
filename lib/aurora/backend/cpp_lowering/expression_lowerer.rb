# frozen_string_literal: true

module Aurora
  module Backend
    class CppLowering
      # ExpressionLowerer
      # Expression lowering to C++
      # Auto-extracted from cpp_lowering.rb during refactoring
      module ExpressionLowerer
      # Apply registered C++ expression rules before falling back to imperative code
      def apply_cpp_expression_rules(expr)
        context = {
          lowerer: self,
          type_registry: @type_registry,
          function_registry: @function_registry,
          type_map: @type_map,
          rule_engine: @rule_engine,
          runtime_policy: @runtime_policy,
          event_bus: @event_bus
        }
        @rule_engine.apply(:cpp_expression, expr, context: context)
      end

      def lower_expression(expr)
              return CppAst::Nodes::NumberLiteral.new(value: "0") if expr.nil?

              # Try rules first
              result = apply_cpp_expression_rules(expr)
              return result unless result.equal?(expr)

              # Fallback to imperative lowering
              case expr
              when CoreIR::UnitLiteral
                # Unit literal should not appear in expression context
                # If it does, it's an error in the compiler
                raise "Internal error: UnitLiteral should not be lowered as expression"
              when CoreIR::LiteralExpr
                lower_literal(expr)
              when CoreIR::RegexExpr
                lower_regex(expr)
              when CoreIR::VarExpr
                lower_variable(expr)
              when CoreIR::BinaryExpr
                lower_binary(expr)
              when CoreIR::UnaryExpr
                lower_unary(expr)
              when CoreIR::CallExpr
                lower_call(expr)
              when CoreIR::MemberExpr
                lower_member(expr)
              when CoreIR::RecordExpr
                lower_record(expr)
              when CoreIR::IfExpr
                lower_if(expr)
              when CoreIR::MatchExpr
                lower_match(expr)
              when CoreIR::LambdaExpr
                lower_lambda(expr)
              when CoreIR::ArrayLiteralExpr
                lower_array_literal(expr)
              when CoreIR::IndexExpr
                lower_index(expr)
              when CoreIR::ListCompExpr
                lower_list_comprehension(expr)
              when CoreIR::BlockExpr
                lower_block_expr(expr)
              else
                raise "Unknown expression: #{expr.class}"
              end
            end

      def lower_literal(lit)
              case lit.type.name
              when "i32"
                CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
              when "f32"
                CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
              when "bool"
                CppAst::Nodes::BooleanLiteral.new(value: lit.value)
              when "string"
                build_aurora_string(lit.value)
              else
                CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
              end
            end

      def lower_regex(regex_expr)
              # Generate: aurora::regex_i(String("pattern")) or aurora::regex(String("pattern"))
              pattern_string = build_aurora_string(regex_expr.pattern)
      
              # Choose function based on flags
              func_name = if regex_expr.flags.include?("i")
                            "aurora::regex_i"
                          else
                            "aurora::regex"
                          end
      
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: func_name),
                arguments: [pattern_string],
                argument_separators: []
              )
            end

      def lower_variable(var)
              case var.name
              when "true"
                CppAst::Nodes::BooleanLiteral.new(value: true)
              when "false"
                CppAst::Nodes::BooleanLiteral.new(value: false)
              else
                CppAst::Nodes::Identifier.new(name: sanitize_identifier(var.name))
              end
            end

      def lower_binary(binary)
              left = lower_expression(binary.left)
              right = lower_expression(binary.right)
              
              CppAst::Nodes::BinaryExpression.new(
                left: left,
                operator: binary.op,
                right: right,
                operator_prefix: " ",
                operator_suffix: " "
              )
            end

      def lower_unary(unary)
              operand = lower_expression(unary.operand)
      
              CppAst::Nodes::UnaryExpression.new(
                operator: unary.op,
                operand: operand,
                operator_suffix: unary.op == "!" ? "" : "",
                prefix: true
              )
            end

      def lower_call(call)
              # Check for IO functions
              if call.callee.is_a?(CoreIR::VarExpr) && IO_FUNCTIONS.key?(call.callee.name)
                return lower_io_function(call)
              end

              if call.callee.is_a?(CoreIR::VarExpr)
                name = call.callee.name

                if (override_expr = lower_stdlib_override(name, call))
                  return override_expr
                end

                unless @user_functions&.include?(name)
                  qualified_name = qualified_function_name(name)
                  if qualified_name.nil? && @stdlib_scanner
                    qualified_name = @stdlib_scanner.cpp_function_name(name)
                  end

                  if qualified_name
                    args = call.args.map { |arg| lower_expression(arg) }
                    num_separators = [args.size - 1, 0].max
                    return CppAst::Nodes::FunctionCallExpression.new(
                      callee: CppAst::Nodes::Identifier.new(name: qualified_name),
                      arguments: args,
                      argument_separators: Array.new(num_separators, ", ")
                    )
                  end
                end
              end

              # Check if this is an array method call that needs translation
              if call.callee.is_a?(CoreIR::MemberExpr) && call.callee.object.type.is_a?(CoreIR::ArrayType)
                method_name = call.callee.member
                array_obj = lower_expression(call.callee.object)
      
                case method_name
                when "length"
                  member_access = CppAst::Nodes::MemberAccessExpression.new(
                    object: array_obj,
                    operator: ".",
                    member: CppAst::Nodes::Identifier.new(name: "size")
                  )
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: member_access,
                    arguments: [],
                    argument_separators: []
                  )
                when "is_empty"
                  member_access = CppAst::Nodes::MemberAccessExpression.new(
                    object: array_obj,
                    operator: ".",
                    member: CppAst::Nodes::Identifier.new(name: "empty")
                  )
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: member_access,
                    arguments: [],
                    argument_separators: []
                  )
                when "push"
                  member_access = CppAst::Nodes::MemberAccessExpression.new(
                    object: array_obj,
                    operator: ".",
                    member: CppAst::Nodes::Identifier.new(name: "push_back")
                  )
                  args = call.args.map { |arg| lower_expression(arg) }
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: member_access,
                    arguments: args,
                    argument_separators: Array.new([args.size - 1, 0].max, ", ")
                  )
                when "pop"
                  member_access = CppAst::Nodes::MemberAccessExpression.new(
                    object: array_obj,
                    operator: ".",
                    member: CppAst::Nodes::Identifier.new(name: "pop_back")
                  )
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: member_access,
                    arguments: [],
                    argument_separators: []
                  )
                when "map"
                  func_arg = call.args.first ? lower_expression(call.args.first) : nil
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::map"),
                    arguments: [array_obj, func_arg].compact,
                    argument_separators: func_arg ? [", "] : []
                  )
                when "filter"
                  predicate = call.args.first ? lower_expression(call.args.first) : nil
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::filter"),
                    arguments: [array_obj, predicate].compact,
                    argument_separators: predicate ? [", "] : []
                  )
                when "fold"
                  init_arg = call.args[0] ? lower_expression(call.args[0]) : nil
                  func_arg = call.args[1] ? lower_expression(call.args[1]) : nil
                  arguments = [array_obj]
                  separators = []
                  if init_arg
                    arguments << init_arg
                    separators << ", "
                  end
                  if func_arg
                    arguments << func_arg
                    separators << ", "
                  end
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::fold"),
                    arguments: arguments,
                    argument_separators: separators
                  )
                else
                  # Fallback: call method directly
                  member_access = CppAst::Nodes::MemberAccessExpression.new(
                    object: array_obj,
                    operator: ".",
                    member: CppAst::Nodes::Identifier.new(name: method_name)
                  )
                  args = call.args.map { |arg| lower_expression(arg) }
                  CppAst::Nodes::FunctionCallExpression.new(
                    callee: member_access,
                    arguments: args,
                    argument_separators: Array.new([args.size - 1, 0].max, ", ")
                  )
                end
              else
                # Regular function call
                callee = lower_expression(call.callee)
                args = call.args.map { |arg| lower_expression(arg) }
      
                # Calculate separators - need n-1 separators for n arguments, minimum 0
                num_separators = [args.size - 1, 0].max
      
                CppAst::Nodes::FunctionCallExpression.new(
                  callee: callee,
                  arguments: args,
                  argument_separators: Array.new(num_separators, ", ")
                )
              end
            end

      def lower_io_function(call)
              target = IO_FUNCTIONS[call.callee.name]
              callee = CppAst::Nodes::Identifier.new(name: target)
              args = call.args.map { |arg| lower_expression(arg) }
              num_separators = [args.size - 1, 0].max

              CppAst::Nodes::FunctionCallExpression.new(
                callee: callee,
                arguments: args,
                argument_separators: Array.new(num_separators, ", ")
              )
            end

      def lower_stdlib_override(name, call)
              override = STDLIB_FUNCTION_OVERRIDES[name]
              return nil unless override

              case name
              when "to_f32"
                arg = call.args.first ? lower_expression(call.args.first) : CppAst::Nodes::Identifier.new(name: "0")
                CppAst::Nodes::FunctionCallExpression.new(
                  callee: CppAst::Nodes::Identifier.new(name: override),
                  arguments: [arg],
                  argument_separators: []
                )
              else
                nil
              end
            end

      def lower_member(member)
              object = lower_expression(member.object)
      
              CppAst::Nodes::MemberAccessExpression.new(
                object: object,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: sanitize_identifier(member.member))
              )
            end

      def lower_record(record)
              # For record literals, we need to create a constructor call
              # Use the actual type (which may be generic) instead of just the name
              type_str = map_type(record.type)
              fields = record.fields

              # Create constructor call with field values
              args = fields.values.map { |value| lower_expression(value) }
              CppAst::Nodes::BraceInitializerExpression.new(
                type: type_str,
                arguments: args,
                argument_separators: args.size > 1 ? Array.new(args.size - 1, ", ") : []
              )
            end

      def lower_if(if_expr)
              # Unit type if-expressions should be lowered as statements, not expressions
              if should_lower_as_statement?(if_expr)
                raise "Internal error: Unit type if-expression should not be lowered as expression. Use lower_if_expr_as_statement instead."
              end

              condition = lower_expression(if_expr.condition)
              then_branch = lower_expression(if_expr.then_branch)

              # For value-producing expressions, use ternary operator
              else_branch = if_expr.else_branch ? lower_expression(if_expr.else_branch) : CppAst::Nodes::NumberLiteral.new(value: "0")

              CppAst::Nodes::TernaryExpression.new(
                condition: condition,
                true_expression: then_branch,
                false_expression: else_branch,
                question_prefix: " ",
                colon_prefix: " ",
                question_suffix: " ",
                colon_suffix: " "
              )
            end

      def lower_match(match_expr)
              scrutinee = lower_expression(match_expr.scrutinee)
      
              # Check if any arms have regex patterns
              has_regex = match_expr.arms.any? { |arm| arm[:pattern][:kind] == :regex }
      
              if has_regex
                # Generate if-else chain for regex matching
                lower_match_with_regex(match_expr, scrutinee)
              else
                # Generate MatchArm for each arm
                arms = match_expr.arms.map do |arm|
                  lower_match_arm(arm)
                end
      
                # Use MatchExpression which generates std::visit with overloaded
                CppAst::Nodes::MatchExpression.new(
                  value: scrutinee,
                  arms: arms,
                  arm_separators: Array.new([arms.size - 1, 0].max, ",\n")
                )
              end
            end

      def lower_match_with_regex(match_expr, scrutinee)
              # Generate an IIFE (Immediately Invoked Function Expression) lambda
              # that contains if-else chain for regex matching:
              # [&]() {
              #   if (regex1.test(scrutinee)) return value1;
              #   if (regex2.test(scrutinee)) return value2;
              #   return default_value;
              # }()
      
              # Build if-else chain body
              statements = []
      
              match_expr.arms.each do |arm|
                pattern = arm[:pattern]
                body = lower_expression(arm[:body])
      
                case pattern[:kind]
                when :regex
                  regex_pattern = pattern[:pattern]
                  regex_flags = pattern[:flags] || ""
                  bindings = pattern[:bindings] || []
      
                  # Create regex object
                  pattern_string = build_aurora_string(regex_pattern)
                  func_name = regex_flags.include?("i") ? "aurora::regex_i" : "aurora::regex"
                  regex_obj = CppAst::Nodes::FunctionCallExpression.new(
                    callee: CppAst::Nodes::Identifier.new(name: func_name),
                    arguments: [pattern_string],
                    argument_separators: []
                  )
      
                  if bindings.empty?
                    # No capture groups - use test()
                    test_call = CppAst::Nodes::MemberAccessExpression.new(
                      object: regex_obj,
                      member: CppAst::Nodes::Identifier.new(name: "test"),
                      operator: "."
                    )
      
                    test_result = CppAst::Nodes::FunctionCallExpression.new(
                      callee: test_call,
                      arguments: [scrutinee],
                      argument_separators: []
                    )
      
                    return_stmt = CppAst::Nodes::ReturnStatement.new(expression: body)
                    if_stmt = CppAst::Nodes::IfStatement.new(
                      condition: test_result,
                      then_statement: return_stmt,
                      else_statement: nil
                    )
                    statements << if_stmt
                  else
                    # Has capture groups - use match() and extract captures
                    # Generate: if (auto match_opt = regex.match(text)) { auto match = *match_opt; auto user = match.get(1).text(); ... return body; }
      
                    regex_src = regex_obj.to_source
                    scrutinee_src = scrutinee.to_source
                    body_src = body.to_source
      
                    # Build capture variable declarations
                    capture_decls = []
                    bindings.each_with_index do |binding, idx|
                      next if binding == "_"  # Skip wildcards
                      # Generate: auto user = match.get(1).text();
                      capture_decls << "auto #{binding} = match.get(#{idx}).text();"
                    end
      
                    # Build if statement with match and captures
                    if_body = [
                      "auto match = *match_opt;",
                      *capture_decls,
                      "return #{body_src};"
                    ].join(" ")
      
                    # Create raw if statement as string
                    # We'll wrap this in a RawCode node
                    if_str = "if (auto match_opt = #{regex_src}.match(#{scrutinee_src})) { #{if_body} }"
      
                    # Add as raw statement (we'll use a simple wrapper)
                    statements << CppAst::Nodes::RawStatement.new(code: if_str)
                  end
      
                when :wildcard, :var
                  # Default case - just return
                  return_stmt = CppAst::Nodes::ReturnStatement.new(expression: body)
                  statements << return_stmt
      
                else
                  # Other patterns not yet supported in regex match
                  # Treat as wildcard for now
                  return_stmt = CppAst::Nodes::ReturnStatement.new(expression: body)
                  statements << return_stmt
                end
              end
      
              # Build body string from statements
              body_str = statements.map { |stmt| stmt.to_source }.join(" ")
      
              # Create IIFE lambda: [&]() { ... }()
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::LambdaExpression.new(
                  capture: "&",
                  parameters: "",
                  specifiers: "",
                  body: body_str,
                  capture_suffix: "",
                  params_suffix: ""
                ),
                arguments: [],
                argument_separators: []
              )
            end

      def lower_match_arm(arm)
              pattern = arm[:pattern]
              body = lower_expression(arm[:body])
      
              case pattern[:kind]
              when :constructor
                # Generate MatchArm with constructor pattern
                case_name = pattern[:name]
                bindings = pattern[:bindings] || pattern[:fields] || []
      
                CppAst::Nodes::MatchArm.new(
                  case_name: case_name,
                  bindings: bindings.reject { |f| f == "_" },  # Filter out wildcards
                  body: body
                )
              when :wildcard, :var
                # For wildcard or variable patterns, we need a generic lambda
                # This is tricky - we'll treat as a default case
                # Generate a lambda that matches anything
                var_name = pattern[:kind] == :var ? pattern[:name] : "_unused"
      
                # Create a catch-all arm using a generic type
                # We'll use a helper that generates: [&](auto&&) { return body; }
                CppAst::Nodes::WildcardMatchArm.new(
                  var_name: var_name,
                  body: body
                )
              when :literal
                # Literal patterns need special handling
                # For now, treat as wildcard with a check
                CppAst::Nodes::WildcardMatchArm.new(
                  var_name: "_v",
                  body: body
                )
              when :regex
                # Regex pattern matching
                # Generate code that checks if regex matches and extracts capture groups
                lower_regex_pattern_arm(pattern, body)
              else
                raise "Unknown pattern kind: #{pattern[:kind]}"
              end
            end

      def lower_regex_pattern_arm(pattern, body)
              # For regex patterns, we need to generate an if-like check
              # This will be a WildcardMatchArm but with special handling
              # For now, generate a comment indicating this is a regex match
              # Full implementation would require more complex C++ generation
      
              # Create a wildcard arm that will match and extract groups
              # The actual matching logic will be in the body wrapper
              CppAst::Nodes::WildcardMatchArm.new(
                var_name: "_text",
                body: body
              )
            end

      def lower_array_literal(array_lit)
              # Generate C++ std::vector initializer list
              # Example: std::vector<int>{1, 2, 3}
      
              # Get element type
              element_type = map_type(array_lit.type.element_type)
      
              # Lower each element
              elements = array_lit.elements.map { |elem| lower_expression(elem) }
      
              # Generate brace initializer: std::vector<int>{1, 2, 3}
              CppAst::Nodes::BraceInitializerExpression.new(
                type: "std::vector<#{element_type}>",
                arguments: elements,
                argument_separators: elements.size > 1 ? Array.new(elements.size - 1, ", ") : []
              )
            end

      def lower_index(index_expr)
              # Generate C++ array subscript: arr[index]
              array = lower_expression(index_expr.object)
              index = lower_expression(index_expr.index)
      
              CppAst::Nodes::ArraySubscriptExpression.new(
                array: array,
                index: index
              )
            end

      def lower_list_comprehension(list_comp)
              element_cpp_type = map_type(list_comp.element_type)
              vector_type = "std::vector<#{element_cpp_type}>"
      
              result_decl = CppAst::Nodes::VariableDeclaration.new(
                type: vector_type,
                declarators: ["result"],
                declarator_separators: [],
                type_suffix: " "
              )
      
              lambda_statements = [result_decl]
      
              body_statements = []
      
              list_comp.filters.each do |filter_expr|
                condition_expr = lower_expression(filter_expr)
                parenthesized = CppAst::Nodes::ParenthesizedExpression.new(
                  expression: condition_expr
                )
                negated = CppAst::Nodes::UnaryExpression.new(
                  operator: "!",
                  operand: parenthesized,
                  prefix: true,
                  operator_suffix: ""
                )
      
                continue_stmt = CppAst::Nodes::ContinueStatement.new
                continue_block = CppAst::Nodes::BlockStatement.new(
                  statements: [continue_stmt],
                  statement_trailings: ["\n"],
                  lbrace_suffix: "\n",
                  rbrace_prefix: ""
                )
      
                body_statements << CppAst::Nodes::IfStatement.new(
                  condition: negated,
                  then_statement: continue_block,
                  else_statement: nil,
                  if_suffix: " ",
                  condition_lparen_suffix: "",
                  condition_rparen_suffix: "",
                  else_prefix: "",
                  else_suffix: ""
                )
              end
      
              push_call = CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::MemberAccessExpression.new(
                  object: CppAst::Nodes::Identifier.new(name: "result"),
                  operator: ".",
                  member: CppAst::Nodes::Identifier.new(name: "push_back")
                ),
                arguments: [lower_expression(list_comp.output_expr)],
                argument_separators: []
              )
      
              body_statements << CppAst::Nodes::ExpressionStatement.new(expression: push_call)
      
              body_block = CppAst::Nodes::BlockStatement.new(
                statements: body_statements,
                statement_trailings: Array.new(body_statements.length, "\n"),
                lbrace_suffix: "\n",
                rbrace_prefix: ""
              )
      
              current_body = body_block
              outer_range_stmt = nil
      
              list_comp.generators.reverse_each do |generator|
                var_type_str = map_type(generator[:var_type])
                variable = ForLoopVariable.new(var_type_str, generator[:var_name])
                container_expr = lower_expression(generator[:iterable])
      
                range_stmt = CppAst::Nodes::RangeForStatement.new(
                  variable: variable,
                  container: container_expr,
                  body: current_body
                )
      
                outer_range_stmt = range_stmt
                current_body = CppAst::Nodes::BlockStatement.new(
                  statements: [range_stmt],
                  statement_trailings: ["\n"],
                  lbrace_suffix: "\n",
                  rbrace_prefix: ""
                )
              end
      
              if outer_range_stmt
                lambda_statements << outer_range_stmt
              else
                lambda_statements.concat(body_statements)
              end
      
              lambda_statements << CppAst::Nodes::ReturnStatement.new(
                expression: CppAst::Nodes::Identifier.new(name: "result")
              )
      
              body_str = lambda_statements.map(&:to_source).join("\n")
      
              lambda_expr = CppAst::Nodes::LambdaExpression.new(
                capture: "&",
                parameters: "",
                specifiers: "",
                body: body_str,
                capture_suffix: "",
                params_suffix: ""
              )
      
              CppAst::Nodes::FunctionCallExpression.new(
                callee: lambda_expr,
                arguments: [],
                argument_separators: []
              )
            end

      def lower_block_expr(block_expr)
              # Analyze block complexity to choose lowering strategy
              analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(block_expr)
              strategy = @runtime_policy.strategy_for_block(analyzer)

              case strategy
              when :iife
                lower_block_expr_as_iife(block_expr)
              when :scope_tmp
                lower_block_expr_as_scope_tmp(block_expr)
              when :gcc_expr
                lower_block_expr_as_gcc_expr(block_expr)
              when :inline
                # For trivial blocks, just return the result expression
                lower_expression(block_expr.result) if block_expr.result
              else
                # Fallback to IIFE (conservative)
                lower_block_expr_as_iife(block_expr)
              end
            end

      private

      # IIFE strategy: [&]() { ... return val; }()
      def lower_block_expr_as_iife(block_expr)
              statements = lower_block_expr_statements(block_expr, emit_return: true)
              body_lines = statements.map { |stmt| "  #{stmt.to_source}" }
              lambda_body = "\n#{body_lines.join("\n")}\n"

              lambda_expr = CppAst::Nodes::LambdaExpression.new(
                capture: "&",
                parameters: "",
                specifiers: "",
                body: lambda_body,
                capture_suffix: "",
                params_suffix: ""
              )

              CppAst::Nodes::FunctionCallExpression.new(
                callee: lambda_expr,
                arguments: [],
                argument_separators: []
              )
            end

      # Scope + tmp strategy: ({ ... val; })
      def lower_block_expr_as_scope_tmp(block_expr)
              # For expression context, we need GCC extension or IIFE
              # Prefer GCC extension if enabled
              if @runtime_policy.use_gcc_extensions
                lower_block_expr_as_gcc_expr(block_expr)
              else
                # For standard C++, use IIFE (compiler will optimize)
                lower_block_expr_as_iife(block_expr)
              end
            end

      # GCC expression statement: ({ ... })
      def lower_block_expr_as_gcc_expr(block_expr)
              # GCC/Clang extension: ({ statement; ... value; })
              # This creates a compound statement that returns a value
              # Example: ({ int x = 1; int y = 2; x + y; })

              statements = []

              # Lower all statements
              block_expr.statements.each do |stmt|
                statements << lower_coreir_statement(stmt)
              end

              # Add result expression as final statement (no return needed in GCC expr)
              if block_expr.result && !block_expr.result.is_a?(CoreIR::UnitLiteral)
                result_expr = lower_expression(block_expr.result)
                statements << CppAst::Nodes::ExpressionStatement.new(expression: result_expr)
              end

              # Generate compound expression: ({ ... })
              # Format with proper indentation
              body_lines = statements.map { |stmt| "  #{stmt.to_source}" }
              compound_body = "\n#{body_lines.join("\n")}\n"

              # Return as raw code wrapped in parentheses
              # We'll use a special node for this
              CppAst::Nodes::RawExpression.new(code: "(#{compound_body})")
            end

      public

      def lower_block_expr_statements(block_expr, emit_return: true)
              statements = block_expr.statements.map { |stmt| lower_coreir_statement(stmt) }

              if block_expr.result
                # Skip unit literals - they represent void/no value
                unless block_expr.result.is_a?(CoreIR::UnitLiteral)
                  result_expr = lower_expression(block_expr.result)
                  if emit_return
                    statements << CppAst::Nodes::ReturnStatement.new(expression: result_expr)
                  else
                    statements << CppAst::Nodes::ExpressionStatement.new(expression: result_expr)
                  end
                end
              end

              statements
            end

      def lower_lambda(lambda_expr)
              # Generate C++ lambda: [captures](params) { return body; }
      
              # Build capture clause (without brackets)
              if lambda_expr.captures.empty?
                capture = ""
              else
                # Build capture list
                captures = lambda_expr.captures.map do |cap|
                  sanitized = sanitize_identifier(cap[:name])
                  case cap[:mode]
                  when :ref
                    "&#{sanitized}"
                  when :value
                    sanitized
                  else
                    sanitized
                  end
                end
                capture = captures.join(', ')
              end

              # Build parameter list
              params_str = lambda_expr.params.map do |param|
                "#{map_type(param.type)} #{sanitize_identifier(param.name)}"
              end.join(", ")
      
              # Lower body
              body_expr = lower_expression(lambda_expr.body)
      
              # Build body string with return statement
              body_str = "return #{body_expr.to_source};"
      
              # Create C++ lambda expression
              # LambdaExpression expects strings for parameters, not array
              CppAst::Nodes::LambdaExpression.new(
                capture: capture,
                parameters: params_str,
                specifiers: "",
                body: body_str,
                capture_suffix: "",
                params_suffix: " "
              )
            end

      end
    end
  end
end
