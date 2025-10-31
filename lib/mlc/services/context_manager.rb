# frozen_string_literal: true

module MLC
  module Services
    # ContextManager - сервис для управления transformation context
    # Заменяет вызовы transformer.send(:within_loop_scope, ...) из правил
    #
    # Использование:
    #   ctx_mgr = context[:context_manager]
    #   ctx_mgr.within_loop { ... }
    class ContextManager
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Выполнить блок внутри loop scope
      def within_loop(&block)
        @transformer.send(:within_loop_scope, &block)
      end

      # Выполнить блок с lambda param types
      def with_lambda_params(param_types, &block)
        @transformer.send(:with_lambda_param_types, param_types, &block)
      end

      # Получить module member function entry
      def module_member_function(object, member)
        @transformer.send(:module_member_function_entry, object, member)
      end

      # Получить текущий return type функции
      def current_function_return
        @transformer.send(:current_function_return)
      end

      # Получить текущие lambda param types
      def current_lambda_param_types
        @transformer.send(:current_lambda_param_types)
      end
    end
  end
end
