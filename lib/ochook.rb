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


    # Turns an ochook into a Monocle-style raw book object. Options:
    #
    # * :componentize - true/false. Splits Index file into components.
    #     Defaults to false.
    #
    def to_book(options = {})
      bk = Chook::Book.new

      # Components
      cmpt_lookup = {}
      if options[:componentize]
        componentizer = Chook::Componentizer.new(index_document)
        componentizer.process(index_document.root.at_css('body'))
        componentizer.components.each_with_index { |cmpt, i|
          uri = i == 0 ? "index.html" : "part#{"%03d" % i}.html"
          cmpt_lookup.update(cmpt => uri)
          doc = componentizer.generate_component(cmpt)
          bk.components.push(uri => doc.to_html)
        }
      else
        bk.components.push(index_document.to_html, "index.html")
        cmpt_lookup.update(index_document.at_css('body') => "index.html")
      end

      # Contents
      outliner = Chook::Outliner.new(index_document)
      outliner.process(index_document.root)
      curse = lambda { |sxn|
        # Find the component parent
        n = sxn.node || sxn.heading
        while n && n.respond_to?(:parent)
          break if cmptURI = cmpt_lookup[n]
          n = n.parent
        end

        if cmptURI
          # get URI for section
          sid = sxn.heading['id']  if sxn.heading
          sid ||= sxn.node['id']  if sxn.node
          cmptURI += "#"+sid  if sid && !sid.empty?

          chapter = {
            :title => sxn.heading_text,
            :src => cmptURI
          }

          # identify any relevant child sections
          children = sxn.sections.collect { |ch|
            curse.call(ch)  unless ch.empty?
          }.compact

          chapter[:children] = children  if children.any?

          chapter
        else
          nil
        end
      }
      bk.contents = curse.call(outliner.result_root)[:children]

      # Strip blank roots from contents
      while bk.contents.length == 1 && bk.contents.first[:title].nil?
        bk.contents = bk.contents.first[:children]
      end

      # Metadata
      index_document.css('head meta[name]').each { |meta|
        bk.metadata.update(meta['name'] => meta['content'])
      }

      bk
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
