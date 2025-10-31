# frozen_string_literal: true

module Aurora
  module Services
    # TypeChecker - сервис для type checking и type inference
    # Заменяет вызовы transformer.send(:ensure_compatible_type, ...) из правил
    #
    # Использование:
    #   type_checker = context[:type_checker]
    #   type_checker.ensure_compatible(type1, type2, "context message")
    class TypeChecker
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Проверка совместимости типов
      def ensure_compatible(actual_type, expected_type, context_msg, node: nil)
        @transformer.send(:ensure_compatible_type, actual_type, expected_type, context_msg, node: node)
      end

      # Проверка boolean типа
      def ensure_boolean(type, context_msg, node: nil)
        @transformer.send(:ensure_boolean_type, type, context_msg, node: node)
      end

      # Вывести тип члена (member access)
      def infer_member_type(object_type, member_name, node: nil)
        @transformer.send(:infer_member_type, object_type, member_name, node: node)
      end

      # Вывести тип итерируемого значения
      def infer_iterable_type(iterable_type, node: nil)
        @transformer.send(:infer_iterable_type, iterable_type, node: node)
      end

      # Получить placeholder type для функции
      def function_placeholder_type(name = nil)
        @transformer.send(:function_placeholder_type, name) if name
        @transformer.send(:function_placeholder_type) unless name
      end

      # Описать тип (для error messages)
      def describe_type(type)
        @transformer.send(:describe_type, type)
      end

      # Получить имя типа
      def type_name(type)
        @transformer.send(:type_name, type)
      end

      # Проверка void типа
      def void_type?(type)
        @transformer.send(:void_type?, type)
      end

      # Выбросить ошибку типа
      def type_error(message, node: nil)
        @transformer.send(:type_error, message, node: node)
      end

      # Проверка numeric типа
      def ensure_numeric_type(type, context_msg, node: nil)
        @transformer.send(:ensure_numeric_type, type, context_msg, node: node)
      end

      # Получить return type для IO функций
      def io_return_type(function_name)
        @transformer.send(:io_return_type, function_name)
      end

      # Трансформировать AST type в CoreIR type
      def transform_type(type_ast)
        @transformer.send(:transform_type, type_ast)
      end
    end
  end
end
