# frozen_string_literal: true

module Aurora
  module Services
    # PredicateService - сервис для проверки свойств AST nodes
    # Заменяет вызовы transformer.send(:unit_branch_ast?, ...) из правил
    #
    # Использование:
    #   predicates = context[:predicates]
    #   is_unit = predicates.unit_branch?(node)
    class PredicateService
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Проверка unit branch в AST
      def unit_branch?(node)
        @transformer.send(:unit_branch_ast?, node)
      end

      # Проверка void типа
      def void_type?(type)
        @transformer.send(:void_type?, type)
      end
    end
  end
end
