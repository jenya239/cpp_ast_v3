# frozen_string_literal: true

module CppAst
  module Builder
    class FormattingContext
      # Defaults for different formatting modes
      DEFAULTS = {
        pretty: {
          template_suffix: " ",
          template_params_suffix: "\n",
          rparen_suffix: " ",  # Architecture: space after ) before modifiers
          lbrace_prefix: " ",
          name_suffix_with_underlying: "",
          friend_suffix: " "
        },
        lossless: {
          template_suffix: "",
          template_params_suffix: "",
          rparen_suffix: "",
          lbrace_prefix: "",
          name_suffix_with_underlying: "",
          friend_suffix: ""
        }
      }.freeze
      
      def self.current_mode
        Thread.current[:cpp_ast_formatting_mode] || :pretty
      end
      
      def self.get(key)
        DEFAULTS[current_mode][key]
      end
    end
  end
end
