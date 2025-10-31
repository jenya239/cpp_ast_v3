# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR variable references to C++ identifiers
        # Pure function - all logic contained, no delegation
        class VarRefRule < BaseRule
          include Aurora::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::VarExpr)
          end

          def apply(node, _context = {})
            case node.name
            when "true"
              CppAst::Nodes::BooleanLiteral.new(value: true)
            when "false"
              CppAst::Nodes::BooleanLiteral.new(value: false)
            else
              CppAst::Nodes::Identifier.new(name: sanitize_identifier(node.name))
            end
          end
        end
      end
    end
  end
end
