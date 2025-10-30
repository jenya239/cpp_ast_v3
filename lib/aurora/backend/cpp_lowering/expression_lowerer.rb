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

              # Apply rules - all expression types should be handled by rules now
              result = apply_cpp_expression_rules(expr)
              return result unless result.equal?(expr)

              # If no rule applied, this is an error - all expression types should be covered
              raise "No rule applied for expression type: #{expr.class}. This should not happen - check rule registration."
            end

      # Helper method: Lower block expression statements with optional return
      # Used by ForRule, BlockRule, and other rules that need to lower block bodies
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

      end
    end
  end
end
