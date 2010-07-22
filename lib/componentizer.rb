require 'nokogiri'

module Chook

  class Componentizer

    HTML5_TAGNAMES = %w[section nav article aside hgroup header footer]
    COMPONENT_TAGNAMES = %w[body article]
    XHTML_DOCTYPE = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"'+"\n"+
      '  "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'

    attr_reader :components

    def initialize(root)
      @root = root
      @components = []

      walk(@root.clone.at_css('body'))
      @components.reject! { |cmpt| empty_component?(cmpt) }
    end


    def walk(node)
      return  unless component?(node)
      @components.push(node.unlink)
      node.children.each { |c| walk(c) }
    end


    def component?(node)
      return false  unless COMPONENT_TAGNAMES.include?(node.name.downcase)
      siblings = node.parent.children
      siblings = siblings.slice(siblings.index(node) + 1, siblings.size)
      return false  unless siblings.all? { |sib| component?(sib) }
      true
    end


    def empty_component?(node)
      return true  if node.children.empty?
      return true  if node.children.all? { |ch|
        ch.text? && ch.content.strip.empty?
      }
      return false
    end


    def write_components(dir)
      require 'fileutils'
      FileUtils.mkdir_p(dir)

      @components.each_with_index { |cmpt, i|
        write_component(cmpt, File.join(dir, "part#{i+1}.xhtml"))
      }
    end


    protected

      def write_component(cmpt, path)
        shell = @root.clone
        body = shell.at_css('body')
        body.children.remove
        [cmpt.name.upcase == "BODY" ? cmpt.children : cmpt].flatten.each { |ch|
          body.add_child(ch)
        }
        out = doc_to_xhtml(shell)
        File.open(path, 'w') { |f| f.write(out) }
        #puts "\n======\n#{out}\n"
        out
      end


      def doc_to_xhtml(root)
        root.css(HTML5_TAGNAMES.join(', ')).each { |elem| elem.name = "div" }
        XHTML_DOCTYPE + "\n" + root.to_xhtml
      end

  end

end
