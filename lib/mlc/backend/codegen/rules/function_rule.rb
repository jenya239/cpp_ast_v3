# frozen_string_literal: true

require_relative "../../../../cpp_ast/nodes/statements"
require_relative "../../../rules/base_rule"

module MLC
  module Backend
    class CodeGen
      module Rules
        class FunctionRule < MLC::Rules::BaseRule
          def applies?(node, context = {})
            node.is_a?(CppAst::Nodes::FunctionDeclaration) && context[:core_func].is_a?(MLC::HighIR::Func)
          end

          def apply(node, context = {})
            func = context[:core_func]
            effects = Array(func.effects)
            event_bus = context[:event_bus]

            if effects.include?(:constexpr)
              node.prefix_modifiers = merge_prefix_modifier(node.prefix_modifiers, "constexpr")
            end

            if effects.include?(:noexcept)
              node.modifiers_text = merge_suffix_modifier(node.modifiers_text, "noexcept")
            end

            event_bus&.publish(
              :cpp_function_rule_applied,
              name: func.name,
              effects: effects
            )

            node
          end

          private

          def merge_prefix_modifier(existing, modifier)
            tokens = existing.to_s.split(/\s+/).reject(&:empty?)
            tokens.unshift(modifier) unless tokens.include?(modifier)
            tokens.empty? ? "" : "#{tokens.join(' ')} "
          end

          def merge_suffix_modifier(existing, modifier)
            text = existing.to_s
            return text if text.include?(modifier)

            suffix = modifier.start_with?(" ") ? modifier : " #{modifier}"
            text + suffix
          end
        end
      end
    end
  end
end
