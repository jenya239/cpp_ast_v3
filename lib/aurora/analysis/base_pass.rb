# frozen_string_literal: true

module Aurora
  module Analysis
    # Base class for analysis and transformation passes
    # Supports multi-level IR architecture with pass metadata
    #
    # Usage:
    #   class MyPass < Analysis::BasePass
    #     def input_level
    #       :high_ir  # or :mid_ir, :low_ir
    #     end
    #
    #     def output_level
    #       :high_ir  # same as input for analysis passes
    #     end
    #
    #     def required_keys
    #       [:high_ir, :type_registry]
    #     end
    #
    #     def produced_keys
    #       [:analysis_results]
    #     end
    #
    #     def run(context)
    #       # perform analysis/transformation
    #     end
    #   end
    class BasePass
      attr_reader :name

      def initialize(name: nil)
        @name = name || self.class.name.split('::').last
      end

      # Main entry point for the pass
      # @param context [Hash] Shared context with IR, type_registry, etc.
      # @return [void]
      def run(context)
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      # IR level this pass expects as input
      # @return [Symbol] :ast, :high_ir, :mid_ir, :low_ir, or :target
      def input_level
        :high_ir  # default: operates on high-level IR (CoreIR)
      end

      # IR level this pass produces as output
      # @return [Symbol] :ast, :high_ir, :mid_ir, :low_ir, or :target
      def output_level
        input_level  # default: same as input (analysis pass)
      end

      # Context keys required by this pass
      # @return [Array<Symbol>]
      def required_keys
        []
      end

      # Context keys produced/modified by this pass
      # @return [Array<Symbol>]
      def produced_keys
        []
      end

      # Is this a transformation pass (changes IR level)?
      # @return [Boolean]
      def transformation?
        input_level != output_level
      end

      # Validate that required context keys are present
      # @param context [Hash]
      # @raise [ArgumentError] if required keys are missing
      def validate_context!(context)
        missing = required_keys - context.keys
        unless missing.empty?
          raise ArgumentError, "Pass #{name} missing required context keys: #{missing.inspect}"
        end
      end

      # Convert pass to a callable for PassManager
      def to_callable
        method(:run)
      end
    end
  end
end
