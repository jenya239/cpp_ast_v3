# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR variable references to C++ identifiers
        class VarRefRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::VarExpr)
          end

          def apply(node, context = {})
            return node unless applies?(node, context)

            lowerer = context[:lowerer]

            case node.name
            when "true"
              CppAst::Nodes::BooleanLiteral.new(value: true)
            when "false"
              CppAst::Nodes::BooleanLiteral.new(value: false)
            else
              CppAst::Nodes::Identifier.new(name: lowerer.send(:sanitize_identifier, node.name))
            end
          end
        end
      end
    end
  end
end
