module Jekyll
  require 'coderay'

  class CodeBlock < Liquid::Block
    def initialize(tag_name, lang, tokens)
      @lang = lang.strip.downcase.to_sym
      super
    end

    def render(context)
      CodeRay.scan(super.strip, @lang).div(:css => :style)
    end
  end
end

Liquid::Template.register_tag('code', Jekyll::CodeBlock)
