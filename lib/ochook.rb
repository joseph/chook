require 'fileutils'
require 'nokogiri'

module Chook

  class Ochook

    attr_accessor :id
    attr_reader :invalidity


    def self.from_zhook(path, options)
      if options[:id]
        ook = from_id(options[:id])
      else
        ook = new
        id_length = { "public" => 4, "private" => 24 }[options[:security]]
        ook.id = ook.find_unique_id(id_length)
      end
      ook.from_zhook(path)
      ook
    end


    def self.from_id(id)
      ook = new
      ook.id = id.to_s
      ook
    end


    def find_unique_id(id_length)
      100.times {
        id = generate_id(id_length)
        return id  unless File.directory?(system_path(id))
      }
      raise "Cannot find a unique id"
    rescue => e
      self.invalidity = e
    end


    def private?
      @id.length >= 24
    end


    def from_zhook(path)
      # Delete any zhook at that path (for re-publishing)
      FileUtils.rm_rf(system_path)
      FileUtils.rm_rf(pave('public', 'format', @id))

      FileUtils.mkdir_p(system_path)
      `unzip #{path} -d #{system_path}`
      raise "Not a zip file"  unless $?.success?

      unless File.exists?(system_path(@id, "index.html"))
        raise "index.html not found"
      end

      unless File.exists?(system_path(@id, "cover.png"))
        raise "cover.png not found"
      end

      generate_manifest

      insert_manifest_attribute
    rescue => e
      self.invalidity = e
    end


    def system_path(id = @id, *args)
      pave('public', 'book', id, args)
    end


    def public_path(id = @id, *args)
      "/#{pave('book', id, args)}"
    end


    def index_document
      return @doc  if @doc
      File.open(system_path(@id, "index.html"), 'r') { |f|
        return @doc = Nokogiri::HTML::Document.parse(f)
      }
    end


    def metadata(name)
      doc = index_document
      if node = doc.at_css("meta[name=#{name}]")
        node['content']
      else
        nil
      end
    end


    def valid?
      @invalidity ? false : true
    end


    def exists?
      File.directory?(system_path)
    end


    def invalidity=(exception)
      if Sinatra::Application.environment == :development
        raise exception
      else
        @invalidity = exception
        #puts "Ochook invalid: #{@invalidity.inspect}"
      end
    end


    def destroy
      FileUtils.rm_rf(system_path)  if @id
    end


    def toc_html(path = '')
      link_to_section = lambda { |sxn, heading|
        sid = sxn.heading['id'] || sxn.node['id']
        return heading  unless sid && !sid.empty?
        '<a href="'+path+'#'+sid+'">'+heading+'</a>'
      }

      outliner = Chook::Outliner.new(index_document)
      outliner.process(index_document.root)
      outline_html = outliner.to_html { |sxn, below|
        heading = sxn.heading_text
        if heading
          heading = link_to_section.call(sxn, heading)
        elsif sxn.respond_to?(:container) && sxn.container && !below.empty?
          heading = '<br class="anon" />'
        end
        heading
      }
    end


    def loi_html(path = '')
      out = nil
      index_document.css('figure[id], div.figure[id]').each { |fig|
        next  unless caption = fig.at_css('figcaption, .figcaption')
        p = block_given? ? yield(fig) : path+'#'+fig['id']
        out ||= "<ol>"
        out << '<li><a href="'+p+'">'+caption.content+'</a></li>'
      }
      out ? out+"</ol>" : nil
    end


    protected

      def generate_id(len = 4)
        require 'digest/sha1'
        s = Digest::SHA1.new
        s << Time.now.to_s
        s << String(Time.now.usec)
        s << String(rand(0))
        s << String($$)
        str = s.hexdigest
        str.slice(rand(str.size - len), len)
      end


      def generate_manifest
        manifest = [
          "CACHE MANIFEST",
          "NETWORK:",
          "*",
          "CACHE:",
          "/read/#{@id}/"
        ]
        Dir.glob(File.join(system_path, "**", "*")).each { |path|
          manifest << path.gsub(/^public/, '')  unless File.directory?(path)
        }
        File.open(system_path(@id, "ochook.manifest"), 'w') { |f|
          f.write(manifest.join("\n"))
        }
      end


      def insert_manifest_attribute
        doc = index_document
        doc.at_css('html').set_attribute('manifest', 'ochook.manifest')
        File.open(system_path(@id, "index.html"), "w") { |f|
          f.write(doc.to_html)
        }
      end


      # A simple File.join shortcut
      def pave(*args)
        File.join(*(args.flatten.compact))
      end

  end

end
