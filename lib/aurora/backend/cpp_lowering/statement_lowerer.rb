# frozen_string_literal: true

module Aurora
  module Backend
    class CppLowering
      # StatementLowerer
      # Statement lowering to C++
      # Auto-extracted from cpp_lowering.rb during refactoring
      module StatementLowerer
      # Apply C++ statement lowering rules
      def apply_cpp_statement_rules(stmt)
        context = {
          lowerer: self,
          type_registry: @type_registry,
          function_registry: @function_registry,
          rule_engine: @rule_engine,
          runtime_policy: @runtime_policy,
          event_bus: @event_bus
        }
        @rule_engine.apply(:cpp_statement, stmt, context: context)
      end

      def lower_coreir_statement(stmt)
              # Try rules first
              result = apply_cpp_statement_rules(stmt)
              return result unless result.equal?(stmt)

              # Fallback to imperative lowering
              case stmt
              when CoreIR::ExprStatement
                if should_lower_as_statement?(stmt.expression)
                  # Expression with unit type should be lowered as statement
                  # Currently only IfExpr with unit type
                  if stmt.expression.is_a?(CoreIR::IfExpr)
                    lower_if_expr_as_statement(stmt.expression)
                  else
                    raise "Unknown statement-like expression: #{stmt.expression.class}"
                  end
                else
                  expr = lower_expression(stmt.expression)
                  CppAst::Nodes::ExpressionStatement.new(expression: expr)
                end
              when CoreIR::VariableDeclStmt
                type_str = map_type(stmt.type)
                use_auto = type_requires_auto?(stmt.type, type_str)
                init_expr = lower_expression(stmt.value)
                decl_type = use_auto ? "auto" : type_str
                identifier = sanitize_identifier(stmt.name)
                declarator = "#{identifier} = #{init_expr.to_source}"
                # Don't add const for pointer types (they end with *)
                is_pointer = type_str.end_with?("*")
                prefix = (stmt.mutable || is_pointer) ? "" : "const "
                CppAst::Nodes::VariableDeclaration.new(
                  type: decl_type,
                  declarators: [declarator],
                  declarator_separators: [],
                  type_suffix: " ",
                  prefix_modifiers: prefix
                )
              when CoreIR::AssignmentStmt
                left_expr = lower_expression(stmt.target)
                right_expr = lower_expression(stmt.value)
                assignment = CppAst::Nodes::AssignmentExpression.new(
                  left: left_expr,
                  operator: "=",
                  right: right_expr
                )
                CppAst::Nodes::ExpressionStatement.new(expression: assignment)
              when CoreIR::IfStmt
                lower_if_stmt(stmt)
              when CoreIR::WhileStmt
                lower_while_stmt(stmt)
              when CoreIR::ForStmt
                lower_for_stmt(stmt)
              when CoreIR::MatchStmt
                lower_match_stmt(stmt)
              when CoreIR::Return
                if stmt.expr
                  expr = lower_expression(stmt.expr)
                  CppAst::Nodes::ReturnStatement.new(expression: expr)
                else
                  CppAst::Nodes::ReturnStatement.new(expression: nil, keyword_suffix: " ")
                end
              when CoreIR::BreakStmt
                CppAst::Nodes::BreakStatement.new
              when CoreIR::ContinueStmt
                CppAst::Nodes::ContinueStatement.new
              else
                desugared = stmt.respond_to?(:desugared_expr) ? stmt.desugared_expr : nil
                return lower_expression(desugared) if desugared
                raise "Unsupported block statement: #{stmt.class}"
              end
            end

      def lower_for_stmt(for_stmt)
              build_range_for(for_stmt.var_name, for_stmt.var_type, for_stmt.iterable, for_stmt.body)
            end

      def lower_if_stmt(if_stmt)
              condition = lower_expression(if_stmt.condition)
              then_statement = lower_statement_block(if_stmt.then_body)
              else_statement = if_stmt.else_body ? lower_statement_block(if_stmt.else_body) : nil

              CppAst::Nodes::IfStatement.new(
                condition: condition,
                then_statement: then_statement,
                else_statement: else_statement,
                if_suffix: " ",
                condition_lparen_suffix: "",
                condition_rparen_suffix: "",
                else_prefix: " ",
                else_suffix: " "
              )
            end

      def lower_if_expr_as_statement(if_expr)
              # Lower IfExpr with unit type as if statement (not expression)
              condition = lower_expression(if_expr.condition)
              then_statement = lower_statement_block(if_expr.then_branch)
              else_statement = if_expr.else_branch ? lower_statement_block(if_expr.else_branch) : nil

              CppAst::Nodes::IfStatement.new(
                condition: condition,
                then_statement: then_statement,
                else_statement: else_statement,
                if_suffix: " ",
                condition_lparen_suffix: "",
                condition_rparen_suffix: " ",
                else_prefix: " ",
                else_suffix: " "
              )
            end

      def lower_while_stmt(while_stmt)
              condition = lower_expression(while_stmt.condition)
              body_statement = lower_statement_block(while_stmt.body)
      
              CppAst::Nodes::WhileStatement.new(
                condition: condition,
                body: body_statement,
                while_suffix: " ",
                condition_lparen_suffix: "",
                condition_rparen_suffix: ""
              )
            end

      def build_range_for(var_name, var_type, iterable_ir, body_ir)
              container = lower_expression(iterable_ir)
              var_type_str = map_type(var_type)
              variable = ForLoopVariable.new(var_type_str, sanitize_identifier(var_name))
              body_block = lower_for_body(body_ir)
      
              CppAst::Nodes::RangeForStatement.new(
                variable: variable,
                container: container,
                body: body_block
              )
            end

      def lower_for_body(body_ir)
              if body_ir.is_a?(CoreIR::BlockExpr)
                stmts = lower_block_expr_statements(body_ir, emit_return: false)
                CppAst::Nodes::BlockStatement.new(
                  statements: stmts,
                  statement_trailings: Array.new(stmts.length, "\n"),
                  lbrace_suffix: "\n",
                  rbrace_prefix: ""
                )
              else
                expr = lower_expression(body_ir)
                CppAst::Nodes::BlockStatement.new(
                  statements: [CppAst::Nodes::ExpressionStatement.new(expression: expr)],
                  statement_trailings: [";"],
                  lbrace_suffix: "",
                  rbrace_prefix: ""
                )
              end
            end

      def lower_statement_block(body_ir)
              if body_ir.is_a?(CoreIR::BlockExpr)
                stmts = lower_block_expr_statements(body_ir, emit_return: false)
                CppAst::Nodes::BlockStatement.new(
                  statements: stmts,
                  statement_trailings: Array.new(stmts.length, "\n"),
                  lbrace_suffix: "\n",
                  rbrace_prefix: ""
                )
              else
                expr = lower_expression(body_ir)
                CppAst::Nodes::BlockStatement.new(
                  statements: [CppAst::Nodes::ExpressionStatement.new(expression: expr)],
                  statement_trailings: ["\n"],
                  lbrace_suffix: "\n",
                  rbrace_prefix: ""
                )
              end
            end

      def lower_match_stmt(match_stmt)
              scrutinee = lower_expression(match_stmt.scrutinee)
              arms = match_stmt.arms.map { |arm| lower_match_arm_statement(arm) }
              CppAst::Nodes::MatchStatement.new(
                value: scrutinee,
                arms: arms,
                arm_separators: Array.new([arms.length - 1, 0].max, ",\n")
              )
            end

      def lower_match_arm_statement(arm)
              pattern = arm[:pattern]
              body_block = lower_statement_block(arm[:body])

              case pattern[:kind]
              when :constructor
                case_name = pattern[:name]
                var_name = sanitize_identifier(case_name.downcase)
                bindings = Array(pattern[:bindings] || pattern[:fields]).compact.reject { |name| name == "_" }
                sanitized_bindings = bindings.map { |name| sanitize_identifier(name) }
                block_with_binding = sanitized_bindings.any? ? add_structured_binding(body_block, sanitized_bindings, var_name) : body_block
                CppAst::Nodes::MatchArmStatement.new(
                  case_name: case_name,
                  var_name: var_name,
                  body: block_with_binding
                )
              when :wildcard
                CppAst::Nodes::WildcardMatchArmStatement.new(
                  var_name: "_unused",
                  body: body_block
                )
              when :var
                var_name = sanitize_identifier(pattern[:name])
                CppAst::Nodes::WildcardMatchArmStatement.new(
                  var_name: var_name,
                  body: body_block
                )
              else
                raise "Unsupported pattern kind for statement match: #{pattern[:kind]}"
              end
            end

      def add_structured_binding(block_stmt, bindings, source_var)
              binding_list = bindings.join(", ")
              declarator = "[#{binding_list}] = #{source_var}"
              declaration = CppAst::Nodes::VariableDeclaration.new(
                type: "auto",
                declarators: [declarator],
                declarator_separators: [],
                type_suffix: " ",
                prefix_modifiers: ""
              )

              statements = [declaration] + block_stmt.statements
              trailings = ["\n"] + block_stmt.statement_trailings

              CppAst::Nodes::BlockStatement.new(
                statements: statements,
                statement_trailings: trailings,
                lbrace_suffix: block_stmt.lbrace_suffix,
                rbrace_prefix: block_stmt.rbrace_prefix
              )
            end

      # Extracted statement lowering methods for rule delegation

      def lower_expr_statement(stmt)
        if should_lower_as_statement?(stmt.expression)
          # Expression with unit type should be lowered as statement
          # Currently only IfExpr with unit type
          if stmt.expression.is_a?(CoreIR::IfExpr)
            lower_if_expr_as_statement(stmt.expression)
          else
            raise "Unknown statement-like expression: #{stmt.expression.class}"
          end
        else
          expr = lower_expression(stmt.expression)
          CppAst::Nodes::ExpressionStatement.new(expression: expr)
        end
      end

      def lower_variable_decl_stmt(stmt)
        type_str = map_type(stmt.type)
        use_auto = type_requires_auto?(stmt.type, type_str)
        init_expr = lower_expression(stmt.value)
        decl_type = use_auto ? "auto" : type_str
        identifier = sanitize_identifier(stmt.name)
        declarator = "#{identifier} = #{init_expr.to_source}"
        # Don't add const for pointer types (they end with *)
        is_pointer = type_str.end_with?("*")
        prefix = (stmt.mutable || is_pointer) ? "" : "const "
        CppAst::Nodes::VariableDeclaration.new(
          type: decl_type,
          declarators: [declarator],
          declarator_separators: [],
          type_suffix: " ",
          prefix_modifiers: prefix
        )
      end

      def lower_assignment_stmt(stmt)
        left_expr = lower_expression(stmt.target)
        right_expr = lower_expression(stmt.value)
        assignment = CppAst::Nodes::AssignmentExpression.new(
          left: left_expr,
          operator: "=",
          right: right_expr
        )
        CppAst::Nodes::ExpressionStatement.new(expression: assignment)
      end

      def lower_return_stmt(stmt)
        if stmt.expr
          expr = lower_expression(stmt.expr)
          CppAst::Nodes::ReturnStatement.new(expression: expr)
        else
          CppAst::Nodes::ReturnStatement.new(expression: nil, keyword_suffix: " ")
        end
      end

      def lower_break_stmt(stmt)
        CppAst::Nodes::BreakStatement.new
      end

      def lower_continue_stmt(stmt)
        CppAst::Nodes::ContinueStatement.new
      end

      end
    end
  end
end
