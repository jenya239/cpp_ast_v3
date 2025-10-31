# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # LambdaRule: Transform AST lambda expressions to HighIR lambda expressions
        # Contains FULL logic (no delegation to transformer)
        # Manages parameter type inference and scoping
        class LambdaRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::Lambda)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            context_mgr = context.fetch(:context_manager)

            # Save current var_types for scoping
            saved_var_types = transformer.instance_variable_get(:@var_types).dup

            # Get expected parameter types from context (for map/filter/fold)
            expected_param_types = context_mgr.current_lambda_param_types

            # Transform parameters with type inference
            params = node.params.each_with_index.map do |param, index|
              if param.is_a?(MLC::AST::LambdaParam)
                param_type = if param.type
                               type_checker.transform_type(param.type)
                             elsif expected_param_types[index]
                               expected_param_types[index]
                             else
                               MLC::HighIR::Builder.primitive_type("i32")
                             end
                transformer.instance_variable_get(:@var_types)[param.name] = param_type
                MLC::HighIR::Param.new(name: param.name, type: param_type)
              else
                param_name = param.respond_to?(:name) ? param.name : param
                param_type = expected_param_types[index] || MLC::HighIR::Builder.primitive_type("i32")
                transformer.instance_variable_get(:@var_types)[param_name] = param_type
                MLC::HighIR::Param.new(name: param_name, type: param_type)
              end
            end

            # Transform lambda body with parameters in scope
            body = expr_svc.transform_expression(node.body)

            # Build function type from parameters and return type
            ret_type = body.type
            param_types = params.map { |p| {name: p.name, type: p.type} }
            function_type = MLC::HighIR::FunctionType.new(
              params: param_types,
              ret_type: ret_type
            )

            # Build HighIR lambda expression (captures empty for now)
            captures = []

            MLC::HighIR::LambdaExpr.new(
              captures: captures,
              params: params,
              body: body,
              function_type: function_type
            )
          ensure
            # Restore previous var_types scope
            transformer.instance_variable_set(:@var_types, saved_var_types) if saved_var_types
          end
        end
      end
    end
  end
end
