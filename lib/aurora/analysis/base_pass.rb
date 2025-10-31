# frozen_string_literal: true

module Aurora
  module Analysis
    # Base class for analysis passes that can be integrated with PassManager
    # Each pass operates on CoreIR and can read/write analysis results to context
    #
    # Usage:
    #   class MyPass < Analysis::BasePass
    #     def run(context)
    #       module_ir = context[:core_ir]
    #       # perform analysis...
    #       context[:my_results] = results
    #     end
    #   end
    class BasePass
      attr_reader :name

      def initialize(name: nil)
        @name = name || self.class.name.split('::').last
      end

      # Main entry point for the pass
      # @param context [Hash] Shared context with core_ir, type_registry, etc.
      # @return [void]
      def run(context)
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      # Convert pass to a callable for PassManager
      def to_callable
        method(:run)
      end
    end
  end
end
