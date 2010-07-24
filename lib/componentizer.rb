require 'nokogiri'

module Chook

  class Componentizer

    attr_reader :components

    def initialize(root)
      @root = root
      @shell = @root.dup
      @components = []

      walk(@root.at_css('body'))
      @components.reject! { |cmpt| empty_component?(cmpt) }
    end


    def walk(node)
      return  unless component?(node)
      @components.push(node.unlink)
      node.children.each { |c| walk(c) }
    end


    def component?(node)
      begin
        return false  unless (
          %w[body article].include?(node.name.downcase) ||
          (node.name.downcase == "div" && node['class'].match(/\barticle\b/))
        )
      end while node = node.next
      true
    end


    def empty_component?(node)
      return true  if node.children.empty?
      return true  if node.children.all? { |ch|
        ch.text? && ch.content.strip.empty?
      }
      return false
    end


    def write_component(cmpt, path, &blk)
      nodes = (cmpt && cmpt.name.downcase == "body") ? cmpt.children : cmpt
      shell = generate_component(nodes)
      out = block_given? ? blk.call(shell) : shell.to_html
      File.open(path, 'w') { |f| f.write(out) }
      out
    end


    protected

      def generate_component(nodes)
        bdy = @shell.at_css('body')
        bdy.children.remove
        [nodes].flatten.compact.each { |ch| bdy.add_child(ch) }
        @shell
      end

  end

end
