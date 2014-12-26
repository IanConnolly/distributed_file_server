require "distributed_file_server/version"
require 'socket'
require 'threadpool'

module DistributedFileServer
  class Server

    @@temp_folder = File.expand_path("~/.dfs")
    
    def self.run(options)
      pool = Threadpool::Threadpool.new workers: 4
      server = TCPServer.new("localhost", options[:port])
      @@directory = options[:directory]
      puts "Listening on port: #{options[:port]}"

      unless File.directory? @@temp_folder
        Dir.mkdir @@temp_folder
      end

      loop do
        client = server.accept
        puts "Talking to client: #{client}"
        pool.add_task(self.process_request, self, client, options[:peers])
      end
    end


    def self.get_file_from_peer(peer, file_name)
      sock = TCPSocket.new peer.split(":")[0], peer.split(":")[1].to_i
      sock.write "REQUEST FILE=#{file_name}"

      header = sock.gets
      if header.split()[0] == 'ERROR'
        return ""
      end
      content_length = header.split()[1].split('=')[1]
      sock.recv(content_length.to_i)
    end

    def self.search_peers(file_name)
      unless @@directory
        return ""
      end

      sock = TCPSocket.new @@directory.split(":")[0], @@directory.split(":")[1].to_i
      sock.write "SEARCH FILE=#{file_name}"

      header = sock.gets
      if header.split()[0] == 'ERROR'
        return ""
      end
      header.split()[1].split('=')
    end

    def self.invalidate_peers!(file_name)
      unless @@directory
        return
      end
    end

    def self.replicate_to_peers!(file_name)
      unless @@directory
        return
      end
    end

    def self.process_request()
      Proc.new do |server, client, peers|
        puts "Processing request for: #{client}"

        request = client.gets.strip
        puts "Request: #{request}"
        command_word = request.split()[0]

        case command_word
        
        when "REQUEST"
          file_name = request.split()[1].split('=')[1]
          local_file_name = File.join(@@temp_folder, file_name.hash)
          unless File.exists? local_file_name
            peer = server.search_peers file_name
            if peer
              file_contents = server.get_file_from_peer peer, file_name
              File.open(local_file_name, "w") { |f| f.write file_contents }
            else
              puts "#{file_name} not found"
              client.puts "ERROR MESSAGE=FileNotFound"
            end 
          else
            file_contents = File.read local_file_name
            return_header = "FILE CONTENT_LENGTH=#{file_length}"
           
            puts "Sending: #{return_header} and file"
           
            client.puts return_header
            client.puts file_contents
          end

        when "WRITE"
          file_name = request.split()[1].split('=')[1]
          size = request.split()[2].split('=')[1]
          local_file_name = File.join(@@temp_folder, file_name.hash)
          
          file_contents = client.recv size
          File.open(local_file_name, "w") { |f| f.write file_contents }
          client.puts "WRITE STATUS=Okay"

          server.invalidate_peers! file_name
          server.replicate_to_peers! file_name
        
        when "EXISTS?"
          file_name = request.split()[1].split('=')[1]
          local_file_name = File.join(@@temp_folder, file_name.hash)
          
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
          file_name = request.split()[1].split('=')[1]
          local_file_name = File.join(@@temp_folder, file_name.hash)
          if File.exists? local_file_name
            File.delete local_file_name
          end
          client.puts "INVALIDATED"
        when "REPLICATE"
          file_name = request.split()[1].split('=')[1]
          content_length = request.split()[2].split('=')[1]
          contents = client.recv(content_length.to_i)
          local_file_name = File.join(@@temp_folder, file_name.hash)
          File.open(local_file_name, "w") { |f| f.write contents }
        client.close
        end
      end 
    end
  end
end
