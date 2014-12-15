require "distributed_file_server/version"
require 'socket'
require 'threadpool'

module DistributedFileServer
  class Server
    
    def self.run(options)
      pool = Threadpool::Threadpool.new workers: 4
      server = TCPServer.new("localhost", options[:port])
      puts "Listening on port: #{options[:port]}"
      loop do
        server.accept do |client|
          pool.add_task(self.process_request, client, options[:peers])
        end
      end
    end

    def self.process_request(client, peers)
      puts "Talking to client: #{client}"
    end
  end
end
