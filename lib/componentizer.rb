require 'nokogiri'

module Chook

  class Componentizer

    attr_reader :components

    def initialize(doc)
      @document = doc
      @shell = @document.root.dup
      @components = []
    end


    def process(from)
      @components = []
      walk(from)
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


    def write_component(node, path, &blk)
      shell = generate_component(node)
      out = block_given? ? blk.call(shell) : shell.to_html
      File.open(path, 'w') { |f| f.write(out) }
      out
    end


    def generate_component(node)
      nodes = (node && node.name.downcase == "body") ? node.children : node
      bdy = @shell.at_css('body')
      bdy.children.remove
      [nodes].flatten.compact.each { |node| bdy.add_child(node.dup) }
      @shell
    end

  end

end
