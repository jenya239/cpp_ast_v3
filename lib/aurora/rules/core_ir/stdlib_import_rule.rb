# frozen_string_literal: true

require_relative "../../rules/base_rule"

module Aurora
  module Rules
    module CoreIR
      class StdlibImportRule < BaseRule
        def applies?(import_decl, context = {})
          registry = context[:stdlib_registry]
          registry && registry.module_info(import_decl.path)
        end

        def apply(import_decl, context = {})
          registry = context.fetch(:stdlib_registry)
          module_info = registry.module_info(import_decl.path)
          return unless module_info

          import_all = import_decl.import_all
          requested_items = Array(import_decl.items)

          function_handler = context[:register_stdlib_function]
          type_handler = context[:register_stdlib_type]
          missing_handler = context[:on_missing_item]
          event_bus = context[:event_bus]
          module_alias = context[:module_alias]

          missing_items = []

          if import_all
            module_info.functions.each_value do |metadata|
              function_handler&.call(metadata, module_info, module_alias)
              event_bus&.publish(
                :stdlib_function_imported,
                module: module_info.name,
                function: metadata.name,
                origin: import_decl.origin
              )
            end

            module_info.types.each_value do |metadata|
              type_handler&.call(metadata.ast_node, module_info.namespace, module_info.name)
              event_bus&.publish(
                :stdlib_type_imported,
                module: module_info.name,
                type: metadata.name,
                origin: import_decl.origin
              )
            end
          else
            requested_items.each do |name|
              if (func_meta = module_info.functions[name])
                function_handler&.call(func_meta, module_info, module_alias)
                event_bus&.publish(
                  :stdlib_function_imported,
                  module: module_info.name,
                  function: func_meta.name,
                  origin: import_decl.origin
                )
              elsif (type_meta = module_info.types[name])
                type_handler&.call(type_meta.ast_node, module_info.namespace, module_info.name)
                event_bus&.publish(
                  :stdlib_type_imported,
                  module: module_info.name,
                  type: type_meta.name,
                  origin: import_decl.origin
                )
              else
                missing_items << name
              end
            end
          end

          missing_items.uniq.each do |missing|
            event_bus&.publish(
              :stdlib_missing_item,
              module: module_info.name,
              item: missing,
              origin: import_decl.origin
            )
            missing_handler.call(missing, import_decl.origin) if missing_handler
          end
        end
      end
    end
  end
end
