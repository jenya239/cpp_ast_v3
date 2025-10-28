# frozen_string_literal: true

module Aurora
  # FunctionRegistry provides a central repository for function metadata and
  # signatures used throughout the Aurora compilation pipeline.
  #
  # Responsibilities:
  # - Track function signatures (param/return types) for inference and lowering
  # - Preserve metadata about module/namespace placement and exports
  # - Maintain alias mapping introduced through imports (`import Foo::{bar as baz}`)
  # - Surface simple queries used by later passes (exported functions, namespaces, etc.)
  class FunctionRegistry
    # Rich metadata about a registered function.
    class Entry
      attr_reader :name, :effects
      attr_accessor :info, :namespace, :module_name, :ast_node, :origin

      def initialize(name:, info:, namespace: nil, module_name: nil, exported: false, external: false,
                     ast_node: nil, origin: nil, effects: nil)
        @name = name
        @info = info
        @namespace = namespace
        @module_name = module_name
        @exported = !!exported
        @external = !!external
        @ast_node = ast_node
        @origin = origin
        @effects = normalize_effects(effects)
        @aliases = []
      end

      def exported?
        @exported
      end

      def exported=(value)
        @exported = !!value
      end

      def external?
        @external
      end

      def external=(value)
        @external = !!value
      end

      def add_alias(alias_name)
        @aliases << alias_name unless @aliases.include?(alias_name)
      end

      def remove_alias(alias_name)
        @aliases.delete(alias_name)
      end

      def aliases
        @aliases.dup
      end

      def replace_effects(effects)
        @effects = normalize_effects(effects)
      end

      def add_effect(effect)
        effect_sym = effect&.to_sym
        return unless effect_sym
        @effects << effect_sym unless @effects.include?(effect_sym)
      end

      def qualified_name
        namespace ? "#{namespace}::#{info.name}" : info.name
      end

      private

      def normalize_effects(effects)
        Array(effects).compact.map(&:to_sym).uniq
      end
    end

    def initialize
      @functions = {}  # name => Entry
      @aliases = {}    # alias => canonical_name
      @namespaces = Hash.new { |hash, key| hash[key] = [] }
      @modules = Hash.new { |hash, key| hash[key] = [] }
    end

    # Register or overwrite a function signature, optionally augmenting metadata.
    #
    # @param name [String] function name (canonical)
    # @param info [Object] typically a FunctionInfo struct
    # @param metadata [Hash] optional metadata (namespace, module_name, exported, external, ast_node, origin, effects, aliases)
    # @return [Object] the stored FunctionInfo (for backwards compatibility)
    def register(name, info, metadata = nil)
      metadata = normalize_metadata(metadata)

      entry = @functions[name] || begin
        @functions[name] = Entry.new(name: name, info: info)
      end

      previous_namespace = entry.namespace
      previous_module = entry.module_name

      entry.info = info
      apply_metadata(entry, metadata)
      track_collection_changes(entry, previous_namespace, previous_module)

      Array(metadata[:aliases]).each do |alias_name|
        register_alias(alias_name, entry.name)
      end

      entry.info
    end

    # Fetch the function signature by name or alias.
    # @param name [String]
    # @return [Object, nil]
    def fetch(name)
      fetch_entry(name)&.info
    end

    # Fetch metadata entry by name or alias.
    # @param name [String]
    # @return [Entry, nil]
    def fetch_entry(name)
      return @functions[name] if @functions.key?(name)

      canonical = @aliases[name]
      canonical ? @functions[canonical] : nil
    end

    # Fetch function info using container/member notation (e.g., "Math.add").
    # @param container [String]
    # @param member [String]
    # @return [Object, nil]
    def fetch_member(container, member)
      return nil unless container && member
      fetch([container, member].join("."))
    end

    # Fetch entry using container/member notation.
    # @param container [String]
    # @param member [String]
    # @return [Entry, nil]
    def fetch_entry_for_member(container, member)
      return nil unless container && member
      fetch_entry([container, member].join("."))
    end

    # Returns the canonical name for a function or alias.
    # @param name [String]
    # @return [String, nil]
    def canonical_name(name)
      return name if @functions.key?(name)
      @aliases[name]
    end

    # Update metadata for an existing function (name or alias).
    # @param name [String]
    # @param metadata [Hash]
    # @return [Object] the stored FunctionInfo
    def update(name, metadata = nil)
      entry = fetch_entry(name)
      raise KeyError, "Unknown function '#{name}'" unless entry

      metadata = normalize_metadata(metadata)
      previous_namespace = entry.namespace
      previous_module = entry.module_name

      apply_metadata(entry, metadata)
      track_collection_changes(entry, previous_namespace, previous_module)

      Array(metadata[:aliases]).each do |alias_name|
        register_alias(alias_name, entry.name)
      end

      entry.info
    end

    # Register an alias pointing to an existing function.
    # @param alias_name [String]
    # @param target_name [String] canonical name of the function
    def register_alias(alias_name, target_name)
      entry = fetch_entry(target_name)
      raise KeyError, "Unknown function '#{target_name}'" unless entry

      if @functions.key?(alias_name)
        raise ArgumentError, "Alias '#{alias_name}' conflicts with existing function"
      end

      old_target = @aliases[alias_name]
      if old_target && old_target != entry.name
        @functions[old_target]&.remove_alias(alias_name)
      end

      @aliases[alias_name] = entry.name
      entry.add_alias(alias_name)
      entry.info
    end

    # Remove a function or alias from the registry.
    # @param name [String]
    # @return [Object, nil] removed FunctionInfo (or nil if not found)
    def delete(name)
      if (entry = @functions.delete(name))
        cleanup_collections(entry)
        entry.aliases.each { |alias_name| @aliases.delete(alias_name) }
        entry.aliases.each { |alias_name| entry.remove_alias(alias_name) }
        return entry.info
      end

      if (canonical = @aliases.delete(name))
        entry = @functions[canonical]
        entry&.remove_alias(name)
        return entry&.info
      end

      nil
    end

    # Clear all registered functions and metadata.
    def clear
      @functions.clear
      @aliases.clear
      @namespaces.clear
      @modules.clear
    end

    # Test if a function (or alias) has already been registered.
    def registered?(name)
      !!fetch_entry(name)
    end

    # Iterate over all registered function infos.
    def each
      return enum_for(:each) unless block_given?
      @functions.each_value { |entry| yield entry.info }
    end

    # Iterate over metadata entries.
    def each_entry
      return enum_for(:each_entry) unless block_given?
      @functions.each_value { |entry| yield entry }
    end

    # Map of canonical names to function info (copies values for safety).
    def to_h
      @functions.transform_values(&:info)
    end

    # All registered canonical function names.
    def names
      @functions.keys
    end

    # All known aliases.
    def aliases
      @aliases.keys
    end

    # Aliases for a given function or alias.
    def aliases_for(name)
      fetch_entry(name)&.aliases || []
    end

    # Retrieve entries belonging to a namespace.
    def functions_in_namespace(namespace)
      (@namespaces[namespace] || []).map { |name| @functions[name] }.compact
    end

    # Retrieve entries belonging to a module.
    def functions_in_module(module_name)
      (@modules[module_name] || []).map { |name| @functions[name] }.compact
    end

    # Exported functions only.
    def exported_functions
      @functions.values.select(&:exported?)
    end

    # External (extern) functions only.
    def external_functions
      @functions.values.select(&:external?)
    end

    # Number of registered canonical functions.
    def size
      @functions.size
    end

    def empty?
      @functions.empty?
    end

    private

    def normalize_metadata(metadata)
      return {} unless metadata
      unless metadata.is_a?(Hash)
        raise ArgumentError, "metadata must be a Hash or nil"
      end
      metadata.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_sym] = value
      end
    end

    def apply_metadata(entry, metadata)
      entry.namespace = metadata[:namespace] if metadata.key?(:namespace)

      module_value = if metadata.key?(:module_name)
        metadata[:module_name]
      elsif metadata.key?(:module)
        metadata[:module]
      end
      entry.module_name = module_value if module_value

      entry.ast_node = metadata[:ast_node] if metadata.key?(:ast_node)
      entry.origin = metadata[:origin] if metadata.key?(:origin)
      entry.exported = metadata[:exported] if metadata.key?(:exported)
      entry.external = metadata[:external] if metadata.key?(:external)

      entry.replace_effects(metadata[:effects]) if metadata.key?(:effects)
      Array(metadata[:append_effects]).each { |effect| entry.add_effect(effect) }
    end

    def track_collection_changes(entry, previous_namespace, previous_module)
      if previous_namespace && previous_namespace != entry.namespace
        @namespaces[previous_namespace].delete(entry.name)
      end
      if entry.namespace
        namespace_list = @namespaces[entry.namespace]
        namespace_list << entry.name unless namespace_list.include?(entry.name)
      end

      if previous_module && previous_module != entry.module_name
        @modules[previous_module].delete(entry.name)
      end
      if entry.module_name
        module_list = @modules[entry.module_name]
        module_list << entry.name unless module_list.include?(entry.name)
      end
    end

    def cleanup_collections(entry)
      if entry.namespace
        list = @namespaces[entry.namespace]
        list.delete(entry.name)
        @namespaces.delete(entry.namespace) if list.empty?
      end

      if entry.module_name
        list = @modules[entry.module_name]
        list.delete(entry.name)
        @modules.delete(entry.module_name) if list.empty?
      end
    end
  end
end
