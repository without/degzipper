module Degzipper
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if method_handled?(env['REQUEST_METHOD']) && encoding_handled?(env['HTTP_CONTENT_ENCODING'])
        puts "env['CONTENT_LENGTH']: #{env['CONTENT_LENGTH']}"
        puts env['rack.input'].read
        env['rack.input'].rewind
        extracted = decode(env['rack.input'], env['HTTP_CONTENT_ENCODING']).tap {|e| puts e}

        env.delete('HTTP_CONTENT_ENCODING')
        env['CONTENT_LENGTH'] = extracted.bytesize
        env['rack.input'] = StringIO.new(extracted).set_encoding('utf-8')
      end
      puts "env['rack.input'].size: #{env['rack.input'].size}"
      puts env['rack.input'].read
      env['rack.input'].rewind

      @app.call(env)
    end

    private

    def method_handled?(method)
      ['POST', 'PUT', 'PATCH'].include? method
    end

    def encoding_handled?(encoding)
      ['gzip', 'zlib', 'deflate'].include? encoding
    end

    def decode(input, content_encoding)
      puts "input.size: #{input.size}"
      puts "input.bytes: #{input.bytes}"
      input.rewind
      # type of input depends on CONTENT_LENGTH
      # if CONTENT_LENGTH < 20k it's StringIO; if more it's Tempfile
      # that's why use only common methods of these types
      case content_encoding
        when 'gzip' then Zlib::GzipReader.new(input).read
        when 'zlib' then Zlib::Inflate.inflate(input.read)
        when 'deflate'
          stream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
          content = stream.inflate(input.read)
          stream.finish
          stream.close
          content
      end
    end
  end
end
