# frozen_string_literal: true

require_relative "../../high_ir/nodes"
require_relative "../../rules/base_rule"

module MLC
  module Rules
    module IRGen
      class FunctionEffectRule < BaseRule
        def applies?(node, _context = {})
          node.is_a?(MLC::HighIR::Func) && !node.external
        end

        def apply(func, context = {})
          analyzer = context[:effect_analyzer]
          return func unless analyzer

          effects = analyzer.analyze(func.body, return_type: func.ret_type)
          return func if effects == func.effects

          MLC::HighIR::Func.new(
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
