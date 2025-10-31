# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering HighIR lambda expressions to C++ lambda expressions
        # Generates: [captures](params) { return body; }
        class LambdaRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::LambdaExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]
            type_map = context[:type_map] || {}
            type_registry = context[:type_registry]

            # Build capture clause (without brackets)
            capture = if node.captures.empty?
                       ""
                     else
                       # Build capture list with proper modes (&ref or value)
                       captures = node.captures.map do |cap|
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
                       captures.join(', ')
                     end

            # Build parameter list with types
            params_str = node.params.map do |param|
              param_type = map_type(
                param.type,
                type_map: type_map,
                type_registry: type_registry
              )
              "#{param_type} #{sanitize_identifier(param.name)}"
            end.join(", ")

            # Recursively lower body
            body_expr = lowerer.send(:lower_expression, node.body)

            # Build body string with return statement
            body_str = "return #{body_expr.to_source};"

            # Create C++ lambda expression
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
end
