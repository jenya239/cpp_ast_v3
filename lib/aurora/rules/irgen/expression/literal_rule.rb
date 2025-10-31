# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # LiteralRule: Transform AST literals to CoreIR literals
        # Contains FULL logic (no delegation to transformer)
        class LiteralRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::IntLit) ||
              node.is_a?(Aurora::AST::FloatLit) ||
              node.is_a?(Aurora::AST::StringLit) ||
              node.is_a?(Aurora::AST::RegexLit) ||
              node.is_a?(Aurora::AST::UnitLit)
          end

          def apply(node, _context = {})
            case node
            when Aurora::AST::IntLit
              type = Aurora::CoreIR::Builder.primitive_type("i32")
              Aurora::CoreIR::Builder.literal(node.value, type)
            when Aurora::AST::FloatLit
              type = Aurora::CoreIR::Builder.primitive_type("f32")
              Aurora::CoreIR::Builder.literal(node.value, type)
            when Aurora::AST::StringLit
              type = Aurora::CoreIR::Builder.primitive_type("string")
              Aurora::CoreIR::Builder.literal(node.value, type)
            when Aurora::AST::RegexLit
              type = Aurora::CoreIR::Builder.primitive_type("regex")
              Aurora::CoreIR::Builder.regex(node.pattern, node.flags, type)
            when Aurora::AST::UnitLit
              Aurora::CoreIR::Builder.unit_literal
            else
              raise "Unsupported literal expression: #{node.class}"
            end
          end
        end
      end
    end
  end
end
