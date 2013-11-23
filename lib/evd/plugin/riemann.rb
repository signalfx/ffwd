require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'

require 'eventmachine'

require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

module EVD::Plugin
  module Riemann
    include EVD::Plugin
    include EVD::Logging

    register_plugin "riemann"

    class OutputBase
      attr_accessor :connected
      attr_reader :dropped_messages

      def initialize(tags, attributes)
        @tags = tags
        @attributes = attributes
        @connected = nil
        @dropped_messages = 0
      end

      def make_event(event)
        ::Riemann::Event.new(
          :service => event[:key],
          :metric => event[:value],
          :description => event[:message],
          :tags => @tags,
          :attributes => @attributes
        )
      end

      def make_message(message)
        ::Riemann::Message.new(
          :events => message[:events]
        )
      end

      protected

      def handle_event(event); raise "Not implemented: handle_event"; end

      def collect_events(buffer)
        buffer.pop do |event|
          handle_single_event event
          collect_events buffer
        end
      end

      private

      def handle_single_event(event)
        if @connected.nil?
          @dropped_messages += 1
          return
        end

        handle_event event
      end
    end

    class RiemannTCPOutput < OutputBase
      include EVD::Logging

      INITIAL_TIMEOUT = 2

      attr_reader :peer

      class Connection < EventMachine::Connection
        include EVD::Logging

        def initialize(out)
          @bad_acks = 0
          @out = out
        end

        def connection_completed
          log.info "Connected to #{@out.peer}"
          @out.connected = self
        end

        def unbind
          log.info "Disconnected from #{@out.peer}"
          @out.connected = nil
          @out.reconnect
        end

        def receive_data(data)
          message = ::Riemann::Message.decode data

          # Not a lot to do to handle the situation.
          if not message.ok
            @bad_acks += 1
            log.warning "Bad acknowledge from #{@out.peer}"
          end
        end
      end

      def initialize(host, port, tags, attributes, flush_period)
        super tags, attributes

        @host = host
        @port = port
        @flush_period = flush_period

        @peer = "#{@host}:#{@port}"

        @events = []
        @timeout = INITIAL_TIMEOUT
      end

      def handle_event(event)
        @events << event
      end

      #
      # Flush buffered events (if any).
      #
      def flush_events
        return if @events.empty?

        events = @events.map{|e| make_event(e)}
        message = make_message :events => event

        @events = []

        begin
          data = message.encode_with_length
          connected.send_data data
        rescue
          log.error "Failed to send events: #{$!}"
        end
      end

      #
      # Setup riemann tcp connection.
      #
      def setup(buffer)
        connect
        collect_events buffer

        EventMachine::PeriodicTimer.new(@flush_period) do
          flush_events
        end
      end

      def connected=(value)
        super value
        # reset timeout if this is a new connection.
        @timeout = INITIAL_TIMEOUT unless value.nil?
      end

      def connect
        return unless connected.nil?
        EventMachine.connect(@host, @port, Connection, self)
      end

      def reconnect
        log.info "Reconnecting to #{peer} in #{@timeout}s"

        EventMachine::Timer.new(@timeout) do
          @timeout *= 2
          connect
        end
      end
    end

    class RiemannUDPOutput < OutputBase
      include EVD::Logging

      def initialize(host, port, tags, attributes)
        super tags, attributes

        @host = host
        @port = port

        @bind_host = "0.0.0.0"
        @host_ip = nil
      end

      def handle_event(event)
        e = make_event(event)
        m = make_message :events => [e]
        @connected.send_datagram m.encode, @host_ip, @port
      end

      def setup(buffer)
        @host_ip = resolve_host_ip @host

        if @host_ip.nil?
          log.error "Could not resolve '#{@host}'"
          return
        end

        log.info "Resolved server as #{@host_ip}"

        EventMachine.open_datagram_socket(@bind_host, nil) do |connected|
          @connected = connected
          collect_events buffer
        end
      end

      private

      def resolve_host_ip(host)
        Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
          next if item[0] != "AF_INET"
          return item[3]
        end

        return nil
      end
    end

    DEFAULT_PORT = {
      "tcp" => 5555,
      "udp" => 5555,
    }

    def self.output_setup(opts={})
      host = opts[:host] || "localhost"
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      port = opts[:port] || DEFAULT_PORT[protocol.name]
      tags = opts[:tags] || []
      attributes = opts[:attributes] || {}

      if protocol == EVD::TCPProtocol
        flush_period = opts[:flush_period]
        return RiemannTCPOutput.new host, port, tags, attributes, flush_period
      end

      return RiemannUDPOutput.new host, port, tags, attributes
    end
  end
end