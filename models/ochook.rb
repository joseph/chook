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
      ook.id = id
      ook
    end


    def find_unique_id(id_length)
      100.times {
        id = generate_id(id_length)
        return id  unless File.directory?(system_path(id))
      }
      raise "Cannot find a unique path"
    rescue => e
      self.invalidity = e
    end


    def from_zhook(path)
      FileUtils.mkdir_p(system_path)

       `unzip #{path} -d #{system_path}`
      raise "Not a zip file"  unless $?.success?

      # Validate it.
      unless File.exists?(system_path(@id, "index.html"))
        raise "index.html not found"
      end

      unless File.exists?(system_path(@id, "cover.png"))
        raise "cover.png not found"
      end

      # Generate the ochook.manifest file
      generate_manifest

      # Update the Index file to reference the manifest
      insert_manifest_attribute
    rescue => e
      self.invalidity = e
    end


    def system_path(id = @id, contd = [])
      contd = [contd].flatten.compact
      contd.unshift(id)
      contd.unshift("books")
      contd.unshift("public")
      File.join(*contd)
    end


    # def public_path(id = @id, contd = [])
    #   contd = contd.flatten.compact
    #   contd.unshift(id)
    #   contd.unshift("books")
    #   "/#{File.join(*contd)}/"
    # end


    def metadata(name)
      doc = parse_document
      doc.at_css("meta[name=#{name}]")['content']
    end


    def valid?
      @invalidity ? false : true
    end


    def exists?
      File.directory?(system_path)
    end


    def invalidity=(exception)
      #raise exception
      @invalidity = exception
      puts "Ochook invalid: #{@invalid.inspect}"
    end


    def destroy
      FileUtils.rm_rf(system_path)  if @id
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
        manifest = ["CACHE MANIFEST", "NETWORK:", "*", "CACHE:"]
        Dir.glob(File.join(system_path, "**", "*")).each { |path|
          manifest << path.gsub(system_path(''), '')
        }
        File.open(system_path(@id, "ochook.manifest"), 'w') { |f|
          f.write(manifest.join("\n"))
        }
      end


      def insert_manifest_attribute
        doc = parse_document
        doc.at_css('html').set_attribute('manifest', 'ochook.manifest')
        File.open(system_path(@id, "index.html"), "w") { |f|
          f.write(doc.to_html)
        }
      end


      def parse_document
        return @doc  if @doc
        File.open(system_path(@id, "index.html"), 'r') { |f|
          return @doc = Nokogiri::HTML::Document.parse(f)
        }
      end

  end

end
