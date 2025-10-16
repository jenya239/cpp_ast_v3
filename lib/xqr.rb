# frozen_string_literal: true

# XQR Language - Alias for Aurora
# This file provides the XQR language interface as an alias for Aurora

require_relative "aurora"

# Alias Aurora as XQR
module XQR
  # Re-export all Aurora functionality
  include Aurora
  
  # XQR-specific extensions can be added here
  module Extensions
    # XQR-specific language features
    # These can extend Aurora with additional syntax or features
  end
end

# Make XQR available as the main module
module XQR
  class << self
    # Delegate all Aurora methods to XQR
    def method_missing(method_name, *args, &block)
      Aurora.send(method_name, *args, &block)
    end
    
    def respond_to_missing?(method_name, include_private = false)
      Aurora.respond_to?(method_name, include_private)
    end
  end
end
