require "aws-sdk-dynamodb"
require 'fileutils'
require 'erb'
require 'yaml'

module Dynomite
  module DbConfig
    def self.included(base)
      base.extend(ClassMethods)
    end

    def db
      self.class.db
    end

    module ClassMethods
      @@db = nil
      def db
        return @@db if @@db

        endpoint = Dynomite.config.endpoint
        check_dynamodb_local!(endpoint)

        # Normally, do not set the endpoint to use the current configured region.
        # Probably want to stay in the same region anyway for db connections.
        #
        # List of regional endpoints: https://docs.aws.amazon.com/general/latest/gr/rande.html#ddb_region
        # Example:
        #   endpoint: https://dynamodb.us-east-1.amazonaws.com
        options = endpoint ? { endpoint: endpoint } : {}
        @@db ||= Aws::DynamoDB::Client.new(options)
      end

      # When endoint has been configured to point at dynamodb local: localhost:8000
      # check if port 8000 is listening and timeout quickly. Or else it takes a
      # for DynamoDB local to time out, about 10 seconds...
      # This wastes less of the users time.
      def check_dynamodb_local!(endpoint)
        return unless endpoint && endpoint.include?("8000")

        open = port_open?("127.0.0.1", 8000, 0.2)
        unless open
          raise "You have configured your app to use DynamoDB local, but it is not running.  Please start DynamoDB local. Example: brew cask install dynamodb-local && dynamodb-local"
        end
      end

      # Thanks: https://gist.github.com/ashrithr/5305786
      def port_open?(ip, port, seconds=1)
        # => checks if a port is open or not
        Timeout::timeout(seconds) do
          begin
            TCPSocket.new(ip, port).close
            true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
            false
          end
        end
      rescue Timeout::Error
        false
      end

      # useful for specs
      def db=(db)
        @@db = db
      end

      def table_namespace(*args)
        case args.size
        when 0
          get_table_namespace
        when 1
          set_table_namespace(args[0])
        end
      end

      def get_table_namespace
        return @table_namespace if defined?(@table_namespace)
        @table_namespace = Dynomite.config.table_namespace
      end

      def set_table_namespace(value)
        @table_namespace = value
      end
    end
  end
end
