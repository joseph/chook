require 'fileutils'
require 'nokogiri'

module Chook

  class Ochook

    attr_accessor :id
    attr_reader :invalidity


    def self.from_zhook(path, id_length)
      ook = new
      ook.id = ook.find_unique_id(id_length)
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


    def from_zhook(path)
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
      pave('public', 'books', id, args)
    end


    def public_path(id = @id, *args)
      "/#{pave('books', id, args)}"
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


    def toc_html
      url_for_section = lambda { |sxn|
        sid = sxn.heading['id'] || sxn.node['id']
        return ''  unless sid && !sid.empty?
        sid = "#"+sid
      }

      outliner = Chook::Outliner.new(index_document)
      outliner.process(index_document.root)
      outline_html = outliner.to_html { |section, below|
        heading = section.heading_text
        if heading
          heading = '<a href="'+url_for_section.call(section)+'">'+heading+'</a>'
        elsif section.respond_to?(:container) && section.container && !below.empty?
          heading = '<br class="anon" />'
        end
        heading
      }
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
