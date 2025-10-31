# frozen_string_literal: true

require_relative "base_pass"

module MLC
  module Analysis
    # EffectAnalysisPass - analyzes HighIR functions for effects (constexpr, noexcept)
    # This pass walks through all functions in a HighIR module and annotates them
    # with effects based on their body and return type.
    #
    # Results stored in context[:function_effects] = { function_name => [:constexpr, :noexcept] }
    #
    # Usage:
    #   pass = EffectAnalysisPass.new(effect_analyzer: analyzer)
    #   pass.run(context)
    #   effects = context[:function_effects]
    class EffectAnalysisPass < BasePass
      def initialize(effect_analyzer:, name: "effect_analysis")
        super(name: name)
        @effect_analyzer = effect_analyzer
      end

      def required_keys
        [:core_ir]
      end

      def produced_keys
        [:function_effects]
      end

      def run(context)
        core_ir = context[:core_ir]
        return unless core_ir

        function_effects = {}

        # Analyze each function in the module
        core_ir.items.each do |item|
          next unless item.is_a?(HighIR::Func)

          effects = @effect_analyzer.analyze(item.body, return_type: item.ret_type)
          function_effects[item.name] = effects
        end

        # Store results in context for other passes or lowering
        context[:function_effects] = function_effects
      end
    end
  end
end
