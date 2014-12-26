require "distributed_file_server/version"
require 'socket'
require 'threadpool'
require 'digest/md5'

module DistributedFileServer
  class Server

    @@temp_folder = File.expand_path("~/.dfs")
    
    def self.run(options)
      pool = Threadpool::Threadpool.new workers: 4
      server = TCPServer.new("localhost", options[:port])
      @@host = "localhost"
      @@port = options[:port]
      @@name = options[:name]
      @@directory = options[:directory]
      @@temp_folder = options[:folder]
      puts "Listening on port: #{options[:port]}"

      self.announce! @@directory

      unless File.directory? @@temp_folder
        Dir.mkdir @@temp_folder
      end

      loop do
        client = server.accept
        puts "Talking to client: #{client}"
        pool.add_task(self.process_request, self, client)
      end
    end

    def self.announce!(directory)
      sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
      sock.puts "PING ME=#{@@name} HOST=#{@@host} PORT=#{@@port}"
      header = sock.gets
      
      unless header.split()[0] == 'PONG'
        @@directory = nil
      end
    end

    def self.register(filename)
     sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
     sock.puts "REGISTER ME=#{@@name} FILE=#{filename}"
     sock.close
    end

    def self.get_file_from_peer(peer, file_name)
      sock = TCPSocket.new peer.split(":")[0], peer.split(":")[1].to_i
      sock.puts "REQUEST FILE=#{file_name}"

      header = sock.gets
      if header.split()[0] == 'ERROR'
        return ""
      end
      content_length = header.split()[1].split('=')[1]
      sock.read(content_length.to_i)
    end

    def self.search_peers(file_name)
      unless @@directory
        return nil
      end

      puts "Searching #{@@directory} for peers with file #{file_name}"

      sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
      sock.puts "SEARCH ME=#{@@name} FILE=#{file_name}"

      header = sock.gets
      if header.split()[0] == 'ERROR'
        return nil
      end
      sock.close
      header.split()[1].split('=')
    end

    def self.invalidate_peers!(file_name)
      unless @@directory
        return
      end

      puts "Invalidating peers copy of #{file_name} via #{@@directory}"
      sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
      sock.puts "INVALIDATE ME=#{@@name} FILE=#{file_name}"
      sock.close
    end

    def self.replicate_to_peers!(file_name)
      unless @@directory
        return
      end

      puts "Replicating copy of #{file_name} to peers via #{@@directory}"
      
      sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
      
      local_file_name = File.join(@@temp_folder, Digest::MD5.hexdigest(file_name))
      filesize = File.size local_file_name
      file_contents = File.read local_file_name
      
      sock.puts "REPLICATE ME=#{@@name} FILE=#{file_name}"
      reply = sock.gets
      sock.close

      unless reply.split()[1].split('=')[1] == "EMPTY"
        peers = reply.split()[1].split('=')[1].split(',')
        peers.each do |peer|
          puts "Replcating #{file_name} to #{peer}"
          ph = peer.split(':')[0]
          pp = peer.split(':')[1].to_i
          TCPSocket.open ph, pp do |peer_sock|
            peer_sock.puts "REPLICATE FILE=#{file_name} CONTENT_LENGTH=#{filesize}"
            peer_sock.write file_contents
          end
        end
      else
        puts "No peers to replicate to"
      end
    end

    def self.process_request()
      Proc.new do |server, client|
        puts "Processing request for: #{client}"

        request = client.gets.strip
        puts "Request: #{request}"
        command_word = request.split()[0]
        file_name = request.split()[1].split('=')[1]
        local_file_name = File.join(@@temp_folder, Digest::MD5.hexdigest(file_name))

        case command_word
        
        when "PING"
          client.write "PONG"
        when "REQUEST"
          unless File.exists? local_file_name
            puts "File #{file_name} doesn't exist locally, searching peers"
            peer = server.search_peers file_name
            if peer
              puts "Found peer: #{peer}"
              file_contents = server.get_file_from_peer peer, file_name
              File.open(local_file_name, "w") { |f| f.write file_contents }
            else
              puts "#{file_name} not found"
              client.puts "ERROR MESSAGE=FileNotFound"
            end 
          else
            puts "File #{file_name} held locally"
            file_contents = File.read local_file_name
            file_length = File.size local_file_name
            return_header = "FILE CONTENT_LENGTH=#{file_length}"
           
            puts "Sending: #{return_header} and file"
           
            client.puts return_header
            client.write file_contents
          end

        when "WRITE"
          size = request.split()[2].split('=')[1].to_i
          puts "Writing a file: #{file_name}, size: #{size}"

          file_contents = client.read size
          puts "File contents: #{file_contents}"
          File.open(local_file_name, "w") { |f| f.write file_contents }
          client.puts "WRITE STATUS=Okay"

          server.invalidate_peers! file_name
          server.replicate_to_peers! file_name
        
        when "EXISTS?"  
          if File.exists? local_file_name
            client.puts "STATUS=Exists"
          else
            peer = server.search_peers file_name
            if peer
              client.puts "STATUS=Exists"
            else
              client.puts "STATUS=DoesNotExist"
            end
          end
        when "INVALIDATE"
          if File.exists? local_file_name
            File.delete local_file_name
          end
          puts "Invalidated #{file_name} as per request"
          client.puts "INVALIDATED"
        when "REPLICATE"
          content_length = request.split()[2].split('=')[1]
          contents = client.read(content_length.to_i)
          File.open(local_file_name, "w") { |f| f.write contents }
          self.register file_name

        puts "Request handled, done."
        $stdout.flush  
        client.close
        end
      end 
    end
  end
end
