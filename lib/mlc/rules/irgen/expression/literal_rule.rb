# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # LiteralRule: Transform AST literals to HighIR literals
        # Contains FULL logic (no delegation to transformer)
        class LiteralRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::IntLit) ||
              node.is_a?(MLC::AST::FloatLit) ||
              node.is_a?(MLC::AST::StringLit) ||
              node.is_a?(MLC::AST::RegexLit) ||
              node.is_a?(MLC::AST::UnitLit)
          end

          def apply(node, _context = {})
            case node
            when MLC::AST::IntLit
              type = MLC::HighIR::Builder.primitive_type("i32")
              MLC::HighIR::Builder.literal(node.value, type)
            when MLC::AST::FloatLit
              type = MLC::HighIR::Builder.primitive_type("f32")
              MLC::HighIR::Builder.literal(node.value, type)
            when MLC::AST::StringLit
              type = MLC::HighIR::Builder.primitive_type("string")
              MLC::HighIR::Builder.literal(node.value, type)
            when MLC::AST::RegexLit
              type = MLC::HighIR::Builder.primitive_type("regex")
              MLC::HighIR::Builder.regex(node.pattern, node.flags, type)
            when MLC::AST::UnitLit
              MLC::HighIR::Builder.unit_literal
            else
              raise "Unsupported literal expression: #{node.class}"
            end
          end
        end
      end
    end
  end
end
