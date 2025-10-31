# frozen_string_literal: true

module MLC
  module Services
    # RecordBuilderService - сервис для построения record типов
    # Заменяет вызовы transformer.send(:build_anonymous_record, ...) из правил
    #
    # Использование:
    #   record_builder = context[:record_builder]
    #   type = record_builder.build_named(type_name, fields)
    class RecordBuilderService
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Вывести record тип из контекста
      def infer_from_context(fields)
        @transformer.send(:infer_record_from_context, fields)
      end

      # Вывести record тип из registry
      def infer_from_registry(fields)
        @transformer.send(:infer_record_from_registry, fields)
      end

      # Построить анонимный record
      def build_anonymous(fields)
        @transformer.send(:build_anonymous_record, fields)
      end

      # Построить именованный record
      def build_named(type_name, fields)
        @transformer.send(:build_named_record, type_name, fields)
      end
    end
  end
end
