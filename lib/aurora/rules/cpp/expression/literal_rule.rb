# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR literal expressions to C++ literals
        # Pure function - all logic contained, no delegation
        class LiteralRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::LiteralExpr)
          end

          def apply(node, _context = {})
            # Engine already checked applies?, no need to check again
            case node.type.name
            when "i32", "f32"
              CppAst::Nodes::NumberLiteral.new(value: node.value.to_s)
            when "bool"
              CppAst::Nodes::BooleanLiteral.new(value: node.value)
            when "string"
              build_aurora_string(node.value)
            else
              CppAst::Nodes::NumberLiteral.new(value: node.value.to_s)
            end
          end
        end
      end
    end
  end
end
