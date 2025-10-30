# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR literal expressions to C++ literals
        class LiteralRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::LiteralExpr)
          end

          def apply(node, context = {})
            return node unless applies?(node, context)

            lowerer = context[:lowerer]

            case node.type.name
            when "i32", "f32"
              CppAst::Nodes::NumberLiteral.new(value: node.value.to_s)
            when "bool"
              CppAst::Nodes::BooleanLiteral.new(value: node.value)
            when "string"
              # Call helper method from lowerer
              lowerer.send(:build_aurora_string, node.value)
            else
              CppAst::Nodes::NumberLiteral.new(value: node.value.to_s)
            end
          end
        end
      end
    end
  end
end
