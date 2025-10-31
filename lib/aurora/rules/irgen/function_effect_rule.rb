# frozen_string_literal: true

require_relative "../../core_ir/nodes"
require_relative "../../rules/base_rule"

module Aurora
  module Rules
    module IRGen
      class FunctionEffectRule < BaseRule
        def applies?(node, _context = {})
          node.is_a?(Aurora::CoreIR::Func) && !node.external
        end

        def apply(func, context = {})
          analyzer = context[:effect_analyzer]
          return func unless analyzer

          effects = analyzer.analyze(func.body, return_type: func.ret_type)
          return func if effects == func.effects

          Aurora::CoreIR::Func.new(
            name: func.name,
            params: func.params,
            ret_type: func.ret_type,
            body: func.body,
            effects: effects,
            type_params: func.type_params,
            external: func.external,
            origin: func.origin
          )
        end
      end
    end
  end
end
