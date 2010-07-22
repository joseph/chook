require 'nokogiri'

module Chook

  class Outliner

    REGEXES = {
      :section_root => /^BLOCKQUOTE|BODY|DETAILS|FIELDSET|FIGURE|TD$/i,
      :section_content => /^ARTICLE|ASIDE|NAV|SECTION$/i,
      :heading => /^H[1-6]|HGROUP$/i
    }

    class Utils

      def self.section_root?(el)
        element_name_is?(el, REGEXES[:section_root])
      end


      def self.section_content?(el)
        element_name_is?(el, REGEXES[:section_content])
      end


      def self.heading?(el)
        element_name_is?(el, REGEXES[:heading])
      end


      def self.named?(el, name)
        element_name_is?(el, /^#{name}$/)
      end


      def self.heading_rank(el)
        raise "Not a heading: #{el.inspect}"  unless heading?(el)
        if named?(el, 'HGROUP')
          1.upto(6) { |n| return n  if el.at_css("h#{n}") }
          raise "Heading not found in HGROUP: #{el.inspect}" # FIXME: how to handle?
        else
          el.name.reverse.to_i
        end
      end


      def self.element_name_is?(el, pattern)
        return false  unless el
        return false  unless el.respond_to?(:name)
        return false  if el.name.nil? || el.name.empty?
        el.name.upcase.match(pattern) ? true : false
      end

    end



    class Outline

      attr_accessor :sections


      def initialize(sections)
        self.sections = [sections].flatten
      end


      def subsections_html(options = {})
        out = sections.collect { |s|
          o = s.to_html(options).strip
          (o.nil? || o.empty?) ? "" : "<li>#{o}</li>"
        }.join.strip
        (out.nil? || out.empty?) ? '' : "<ol>#{out}</ol>\n"
      end

      alias :to_html :subsections_html

    end



    class Section < Outline

      attr_accessor :sections, :heading, :container, :node


      def initialize(node = nil)
        self.node = node
        self.sections = []
      end


      def append(subsection)
        subsection.container = self
        sections.push(subsection)
      end


      def to_html(options = {})
        s = subsections_html(options)
        h = heading_html(options)
        h ||= '<br class="anonHeading" />'  unless s.empty?
        "#{h}#{s}"
      end


      def heading_html(options = {})
        anon = options[:title_empty_sections] ?
          "<i>Untitled#{node ? " #{node.name.upcase}" : nil}</i>" :
          nil
        return anon  unless Utils.heading?(heading)
        h = heading
        h = h.at_css("h#{Utils.heading_rank(h)}")  if Utils.named?(h, 'HGROUP')
        if h
          t = h.inner_text.strip
          t = anon  if t.nil? || t.empty?
          options[:heading_wrapper] == false ? t : "<div>#{t}</div>"
        end
      end


      def heading_rank
        # FIXME: some doubt as to whether 1 is the sensible default
        Utils.heading?(heading) ? Utils.heading_rank(heading) : 1
      end

    end



    def initialize(root)
      @outlinee = nil
      @outlines = {}
      @section = Section.new
      @stack = []

      walk(root)
    end


    def walk(node)
      return  unless node
      enter_node(node)
      node.children.each { |ch| walk(ch) }
      exit_node(node)
    end


    def enter_node(node)
      return  if Utils.heading?(@stack.last)

      if Utils.section_content?(node) || Utils.section_root?(node)
        @stack.push(@outlinee)  unless @outlinee.nil?
        @outlinee = node
        @section = Section.new(node)
        @outlines[@outlinee] = Outline.new(@section)
        return
      end

      return  if @outlinee.nil?

      if Utils.heading?(node)
        node_rank = Utils.heading_rank(node)
        if !@section.heading
          @section.heading = node
        elsif node_rank <= @outlines[@outlinee].sections.last.heading_rank
          @section = Section.new
          @section.heading = node
          @outlines[@outlinee].sections.push(@section)
        else
          candidate = @section
          while true
            if node_rank > candidate.heading_rank
              @section = Section.new
              candidate.append(@section)
              @section.heading = node
              break
            end
            candidate = candidate.container
          end
        end
        @stack.push(node)
      end
    end


    def exit_node(node)
      if Utils.heading?(@stack.last)
        @stack.pop  if @stack.last == node
        return
      end

      # H5O's modification would go here...

      if Utils.section_content?(node) && !@stack.empty?
        @outlinee = @stack.pop
        @section = @outlines[@outlinee].sections.last
        @outlines[node].sections.each { |s| @section.append(s) }
        return
      end

      if Utils.section_root?(node) && !@stack.empty?
        @outlinee = @stack.pop
        @section = @outlines[@outlinee].sections.last
        while @section.sections.any?
          @section = @section.sections.last
        end
        return
      end

      if Utils.section_content?(node) || Utils.section_root?(node)
        @section = @outlines[@outlinee].sections.first
        return
      end
    end


    def to_html(options = {})
      @outlines[@outlinee].to_html(options)
    end


    def recurse_through_sections(&blk)
      recursion = lambda { |section|
        blk.call(section)
        section.sections.each { |sub| recursion.call(sub) }
      }
      recursion.call(@outlines[@outlinee])
    end

  end

end
