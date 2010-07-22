require 'nokogiri'

module Chook

  class Componentizer

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


    def generate_component(nodes)
      shell = @root.clone
      body = shell.at_css('body')
      body.children.remove
      [nodes].flatten.compact.each { |ch| body.add_child(ch) }
      shell
    end


    def write_components(dir, &blk)
      require 'fileutils'
      FileUtils.mkdir_p(dir)
      paths = []
      @components.each_with_index { |cmpt, i|
        paths << File.join(dir, "part#{i+1}.html")
        write_component(cmpt, paths.last, &blk)
      }
      paths
    end


    def write_component(node, path, &blk)
      shell = generate_component(
        (node && node.name.upcase == "BODY") ? node.children : node
      )
      out = block_given? ? blk.call(shell) : shell.to_html
      File.open(path, 'w') { |f| f.write(out) }
      #puts "\n======\n#{out}\n"
      out
    end

  end

end
