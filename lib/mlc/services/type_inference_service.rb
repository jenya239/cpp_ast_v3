# frozen_string_literal: true

module MLC
  module Services
    # TypeInferenceService - сервис для type inference
    # Заменяет вызовы transformer.send(:infer_type, ...) из правил
    #
    # Использование:
    #   type_inferrer = context[:type_inference]
    #   type = type_inferrer.infer_variable_type(var_name)
    class TypeInferenceService
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Базовый type inference для переменных
      def infer_variable_type(name)
        @transformer.send(:infer_type, name)
      end

      # Вывод типа вызова функции
      def infer_call_type(callee, args)
        @transformer.send(:infer_call_type, callee, args)
      end

      # Вывод типа унарной операции
      def infer_unary_type(op, operand_type)
        @transformer.send(:infer_unary_type, op, operand_type)
      end

      # Вывод типа бинарной операции
      def infer_binary_type(op, left_type, right_type)
        @transformer.send(:infer_binary_type, op, left_type, right_type)
      end

      # Ожидаемые типы для lambda параметров
      def expected_lambda_param_types(object_ir, member_name, args, index)
        @transformer.send(:expected_lambda_param_types, object_ir, member_name, args, index)
      end
    end
  end
end
