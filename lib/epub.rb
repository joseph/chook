require 'fileutils'

module Chook

  class Epub

    HTML5_TAGNAMES = %w[section nav article aside hgroup header footer figure figcaption] # FIXME: Which to divify? Which to leave as-is?
    XHTML_DOCTYPE = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"'+"\n"+
      '  "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
    MIMETYPE_MAP = {
      '.gif' => 'image/gif',
      '.jpg' => 'image/jpeg',
      '.png' => 'image/png',
      '.svg' => 'image/svg+xml',
      '.html' => 'application/xhtml+xml',
      '.odt' => 'application/x-dtbook+xml',
      '.css' => 'text/css',
      '.xml' => 'application/xml',
      '.ncx' => 'application/x-dtbncx+xml'
    }
    OEBPS = "OEBPS"
    NCX = "superfluous"


    attr_accessor :ochook, :src_doc, :id

    def self.from_ochook(ochook)
      # Initialize the EPUB object.
      epub = new
      epub.ochook = ochook
      epub.id = ochook.id
      epub.src_doc = ochook.index_document

      epub.find_chapters_and_components_in_index_document

      # Assemble all the EPUB guff.
      epub.build_oebps_container
      epub.build_ncx
      epub.write_components
      epub.build_opf
      epub.zip_it_up
      epub.cleanup
    end


    def initialize
      @component_paths = {}
      @spine_paths = []
    end


    def find_chapters_and_components_in_index_document
      # Process the Zhook index file into chapters and components.
      outliner.process(@src_doc.root)
      componentizer.process(@src_doc.root.at_css('body'))
    end


    def build_oebps_container
      build_xml_file(working_path("META-INF", "container.xml")) { |xml|
        xml.container(
          :xmlns => "urn:oasis:names:tc:opendocument:xmlns:container",
          :version => "1.0"
        ) {
          xml.rootfiles {
            xml.rootfile(
              'full-path' => "OEBPS/content.opf",
              'media-type' => "application/oebps-package+xml"
            )
          }
        }
      }
    end


    def build_ncx
      x = 0
      curse = lambda { |xml, section|
        if cmpt = url_for_node(section.heading, section.node)
          xml.navPoint(:id => "navPoint#{x+=1}", :playOrder => x) {
            xml.navLabel { xml.text_(section.heading_text) }
            xml.content(:src => cmpt)
            section.sections.each { |ch|
              curse.call(xml, ch)  unless ch.heading_text.nil?
            }
          }
        end
      }

      p = build_xml_file(working_path(OEBPS, "#{NCX}.ncx")) { |xml|
        xml.ncx(
          'xmlns' => "http://www.daisy.org/z3986/2005/ncx/",
          :version => "2005-1"
        ) {
          xml.head {
            xml.meta(:name => "dtb:uid", :content => unique_identifier)
            xml.meta(:name => "dtb:depth", :content => "-1") # FIXME: -1?
            xml.meta(:name => "dtb:totalPageCount", :content => "0")
            xml.meta(:name => "dtb:maxPageNumber", :content => "0")
          }
          xml.docTitle {
            xml.text_(metadata(:title))
          }
          xml.navMap {
            outliner.result_root.sections.each { |ch| curse.call(xml, ch) }
          }
        }
      }
      @component_paths[NCX] = p
    end


    def write_components
      xhtmlize = lambda { |root|
        root.remove_attribute('manifest')
        root.css(HTML5_TAGNAMES.join(', ')).each { |elem|
          k = elem['class']
          elem['class'] = "#{k.nil? || k.empty? ? '' : "#{k} " }#{elem.name}"
          elem.name = "div"
        }
        # FIXME? Seems to result in duplicate attributes in 2.7.6.
        root.set_attribute('xmlns', "http://www.w3.org/1999/xhtml")
        "#{XHTML_DOCTYPE}\n#{root.to_xhtml(:indent => 2)}"
      }

      # non-components (stylesheets, images, etc)
      Dir.glob(@ochook.system_path(@id, '**', '*')).each { |path|
        next  if File.directory?(path)
        next  if ["index.html", "ochook.manifest"].include?(File.basename(path))
        p = working_path(OEBPS, path.gsub(/^#{@ochook.system_path(@id)}/, ''))
        FileUtils.mkdir_p(File.dirname(p))
        @component_paths[File.basename(p, File.extname(p))] = p
        FileUtils.cp_r(path, p)
      }

      # main content components
      dir = working_path(OEBPS)
      componentizer.components.each_with_index { |cmpt, i|
        @spine_paths << File.join(dir, "part#{i+1}.html")
        componentizer.write_component(cmpt, @spine_paths.last, &xhtmlize)
      }
      @spine_paths.each { |path|
        @component_paths[File.basename(path, File.extname(path))] = path
      }

      # toc.html
      @component_paths['toc'] = working_path(OEBPS, "toc.html")
      outline_html = outliner.to_html { |section, below|
        heading = section.heading_text
        if heading
          url = url_for_node(section.heading, section.node)
          heading = '<a href="'+url+'">'+heading+'</a>'
        elsif section.respond_to?(:container) && section.container && !below.empty?
          heading = '<br class="anon" />'
        end
        heading
      }
      componentizer.write_component(
        Nokogiri::HTML.fragment(outline_html),
        @component_paths['toc'],
        &xhtmlize
      )

      # loi.html
      if loi_html = @ochook.loi_html { |fig| url_for_node(fig) }
        @component_paths['loi'] = working_path(OEBPS, "loi.html")
        componentizer.write_component(
          Nokogiri::HTML.fragment(loi_html),
          @component_paths['loi'],
          &xhtmlize
        )
      end

      # cover.html
      @component_paths['cover-image'] = @component_paths['cover']
      @component_paths['cover'] = working_path(OEBPS, "cover.html")
      componentizer.write_component(
        Nokogiri::HTML::Builder.new { |html|
          html.div(:id => "cover") {
            html.img(:src => "cover.png", :alt => metadata(:title))
          }
        }.doc.root,
        @component_paths['cover'],
        &xhtmlize
      )
    end


    def build_opf
      build_xml_file(working_path(OEBPS, "content.opf")) { |xml|
        xml.package(
          'xmlns' => "http://www.idpf.org/2007/opf",
          'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
          'version' => "2.0",
          'unique-identifier' => 'bookid'
        ) {
          xml.metadata {
            xml['dc'].title(metadata(:title) || 'Untitled')
            xml['dc'].identifier(unique_identifier, :id => 'bookid')
            xml['dc'].language(metadata(:language) || 'en')
            [
              :creator,
              :subject,
              :description,
              :publisher,
              :contributor,
              :date,
              :source,
              :relation,
              :coverage,
              :rights
            ].each { |dc|
              val = metadata(dc)
              xml['dc'].send(dc, val)  if val
            }
            xml.meta(:name => "cover", :content => "cover")
          }
          xml.manifest {
            @component_paths.each_pair { |id, href|
              href = href.gsub(/^#{working_path(OEBPS)}\//, '')
              ext = File.extname(href)
              xml.item(
                'id' => id,
                'href' => href,
                'media-type' => MIMETYPE_MAP[ext] || 'application/unknown'
              )
            }
          }
          xml.spine(:toc => NCX) {
            xml.itemref(:idref => 'cover', :linear => 'no')
            xml.itemref(:idref => 'toc', :linear => 'no')
            @spine_paths.each { |path|
              xml.itemref(:idref => File.basename(path, File.extname(path)))
            }
          }
          xml.guide {
            xml.reference(
              :type => "cover",
              :title => "Cover",
              :href => "cover.html"
            )
            xml.reference(
              :type => "toc",
              :title => "Table of Contents",
              :href => "toc.html"
            )
            xml.reference(
              :type => "loi",
              :title => "List of Illustrations",
              :href => "loi.html"
            )
          }
        }
      }
    end


    def zip_it_up
      File.open(working_path("mimetype"), 'w') { |f|
        f.write("application/epub+zip")
      }
      zip_path = system_path(@id, "#{@id}.epub")
      File.unlink(zip_path)  if File.exists?(zip_path)
      cmd = [
        "cd #{working_path}",
        "zip -0Xq '../#{@id}.epub' mimetype",
        "zip -Xr9Dq '../#{@id}.epub' *"
      ]
      `#{cmd.join(" && ")}`
      zip_path
    end


    def cleanup
      # TODO: delete the working directory...
    end


    def system_path(id = @id, *args)
      pave('public', 'format', id, args)
    end


    def working_path(*args)
      pave('public', 'format', @id, 'epub', args)
    end


    def metadata(name)
      @ochook.metadata(name)
    end


    protected

      def pave(*args)
        File.join(*(args.flatten.compact))
      end


      def build_xml_file(path)
        raise ArgumentError  unless block_given?
        builder = Nokogiri::XML::Builder.new { |xml|
          yield(xml)
        }
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w') { |f|
          builder.doc.write_xml_to(f, :encoding => 'UTF-8', :indent => 2)
        }
        path
      end


      def unique_identifier
        metadata(:identifier) ||
        metadata(:isbn) ||
        "org.ochook.reader-EPUB-#{@id}"
      end


      def outliner
        @outliner ||= Chook::Outliner.new(@src_doc)
      end


      def componentizer
        @componentizer ||= Chook::Componentizer.new(@src_doc)
      end


      def url_for_node(*nodes)
        node = nodes.compact.detect { |n| n['id'] && !n['id'].empty? }
        node ||= nodes.first
        return nil  unless node

        n = node
        while n && n.respond_to?(:parent)
          if cmptIndex = componentizer.components.index(n)
            fragment = "##{node['id']}"  if node['id'] && !node['id'].empty?
            return "part#{cmptIndex+1}.html#{fragment}"
          end
          n = n.parent
        end
        nil
      end

  end

end
