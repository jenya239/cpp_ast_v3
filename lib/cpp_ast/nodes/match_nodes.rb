# frozen_string_literal: true

module CppAst
  module Nodes
    # Match expression - generates std::visit with overloaded
    class MatchExpression < Expression
      attr_accessor :value, :arms, :arm_separators

      def initialize(value:, arms:, arm_separators: [])
        @value = value
        @arms = arms
        @arm_separators = arm_separators
      end

      def to_source
        result = +"std::visit(overloaded{\n"
        
        arms.each_with_index do |arm, i|
          result << "  " << arm.to_source
          result << arm_separators[i] if i < arm_separators.length
        end
        
        result << "\n}, "
        value_str = value.respond_to?(:to_source) ? value.to_source : value.to_s
        result << value_str << ")"
        result
      end
    end

    # Match arm - generates lambda for one case
    class MatchArm < Node
      attr_accessor :case_name, :bindings, :body

      def initialize(case_name:, bindings: [], body:)
        @case_name = case_name
        @bindings = bindings
        @body = body
      end

      def to_source
        result = +"[&](const #{case_name}& #{case_name.downcase}) { "
        
        if bindings.any?
          # Generate structured binding: auto [binding1, binding2] = case;
          binding_list = bindings.join(", ")
          result << "auto [#{binding_list}] = #{case_name.downcase}; "
        end
        
        body_str = body.respond_to?(:to_source) ? body.to_source : body.to_s
        result << "return #{body_str}; }"
        result
      end
    end
  end
end
