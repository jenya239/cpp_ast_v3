# frozen_string_literal: true

module Aurora
  module TypeSystem
    class MatchAnalyzer
      Analysis = Struct.new(:arms, :result_type)

      def initialize(ensure_compatible_type:)
        @ensure_compatible_type = ensure_compatible_type
      end

      def analyze(scrutinee_type:, arms:, transform_arm:)
        transformed_arms = arms.map do |arm|
          transform_arm.call(scrutinee_type, arm)
        end

        if transformed_arms.empty?
          raise ArgumentError, "match expression requires at least one arm"
        end

        first_body = transformed_arms.first[:body]
        result_type = first_body&.type
        raise ArgumentError, "match arm body must have a type" unless result_type

        transformed_arms.each_with_index do |arm, index|
          body = arm[:body]
          raise ArgumentError, "match arm body must be present" unless body

          body_type = body.type
          raise ArgumentError, "match arm body must have a type" unless body_type

          @ensure_compatible_type.call(body_type, result_type, "match arm #{index + 1}")
        end

        Analysis.new(transformed_arms, result_type)
      end
    end
  end
end
