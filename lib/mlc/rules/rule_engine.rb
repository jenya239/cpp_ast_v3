# frozen_string_literal: true

require_relative "base_rule"

module MLC
  module Rules
    class RuleEngine
      attr_reader :registry

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = [] }
      end

      def register(stage, rule)
        registry[stage.to_sym] << rule
      end

      def apply(stage, node, context: {})
        result = node

        registry[stage.to_sym].each do |rule|
          instance = ensure_rule_instance(rule)
          next unless instance.applies?(result, context)

          applied = instance.apply(result, context)
          result = applied unless applied.nil?
        end

        result
      end

      private

      def ensure_rule_instance(rule)
        return rule if rule.respond_to?(:apply)
        rule.new
      end
    end
  end
end
