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
              # Apply rules - all statement types should be handled by rules now
              result = apply_cpp_statement_rules(stmt)
              return result unless result.equal?(stmt)

              # If no rule applied, this is an error - all statement types should be covered
              raise "No rule applied for statement type: #{stmt.class}. This should not happen - check rule registration."
            end

      # Helper method: Lower IfExpr with unit type as if statement (not expression)
      # Used by ExprStatementRule and IfRule when handling unit-type if expressions

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

      # Helper method: Lower body expression/block as C++ block statement
      # Used by IfRule, WhileRule, ForRule, and MatchRule for lowering statement blocks

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
