# frozen_string_literal: true

module Aurora
  module Backend
    class CppLowering
      # StatementLowerer
      # Statement lowering to C++
      # Auto-extracted from cpp_lowering.rb during refactoring
      module StatementLowerer
      def lower_coreir_statement(stmt)
              case stmt
              when CoreIR::ExprStatement
                if stmt.expression.is_a?(CoreIR::ForLoopExpr)
                  lower_for_loop_statement(stmt.expression)
                elsif stmt.expression.is_a?(CoreIR::WhileLoopExpr)
                  lower_while_loop_statement(stmt.expression)
                elsif should_lower_as_statement?(stmt.expression)
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

      def lower_for_loop_statement(for_loop)
              build_range_for(for_loop.var_name, for_loop.var_type, for_loop.iterable, for_loop.body)
            end

      def lower_while_loop_statement(while_loop)
              temp_stmt = CoreIR::WhileStmt.new(
                condition: while_loop.condition,
                body: while_loop.body,
                origin: while_loop.origin
              )
              lower_while_stmt(temp_stmt)
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

      end
    end
  end
end
