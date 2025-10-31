# frozen_string_literal: true

module MLC
  class PassManager
      Pass = Struct.new(:name, :callable)

      def initialize
        @passes = []
      end

      def register(name, callable = nil, &block)
        raise ArgumentError, "Provide a callable or a block" if callable.nil? && block.nil?
        raise ArgumentError, "Only one of callable or block is allowed" if callable && block

        @passes << Pass.new(name.to_sym, callable || block)
      end

      def run(context = {})
        @passes.each do |pass|
          pass.callable.call(context)
        rescue StandardError => e
          raise e.class, "Pass #{pass.name} failed: #{e.message}", e.backtrace
        end
        context
      end

      def passes
        @passes.map(&:name)
      end
    end
end
