# frozen_string_literal: true

require 'socket'
require 'timeout'
require_relative 'connection_manager'

module Dalli
  module Protocol
    ##
    # Manages the buffer for responses from memcached.
    ##
    class BufferedIO
      ENCODING = Encoding::BINARY
      TERMINATOR = "\r\n".b.freeze
      TERMINATOR_SIZE = TERMINATOR.bytesize
      DEFAULT_CHUNK_SIZE = 1024 * 8
      DEFAULT_SOCKET_TIMEOUT = ConnectionManager::DEFAULTS[:socket_timeout]

      def initialize(io, chunk_size = nil, timeout = nil)
        @io = io
        @buffer = +''
        @offset = 0
        @chunk_size = chunk_size || DEFAULT_CHUNK_SIZE
        @timeout = timeout || DEFAULT_SOCKET_TIMEOUT # seconds
      end

      # Reads line from io and the buffer, value does not include the terminator
      def read_line
        fill_buffer(false) if @offset >= @buffer.bytesize
        until (terminator_index = @buffer.index(TERMINATOR, @offset))
          fill_buffer(false)
        end

        terminator_index += TERMINATOR_SIZE
        line = @buffer.byteslice(@offset, terminator_index - @offset)
        @offset = terminator_index
        line.force_encoding(Encoding::UTF_8)
      end

      # Reads the exact number of bytes from the buffer
      def read(size)
        needed = size - (@buffer.bytesize - @offset)
        fill_buffer(true, needed) if needed.positive?

        str = @buffer.byteslice(@offset, size)
        @offset += size
        str.force_encoding(Encoding::UTF_8)
      end

      private

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/MethodLength
      def fill_buffer(force_size, size = @chunk_size)
        remaining = size
        buffer_size = @buffer.bytesize
        start = @offset - buffer_size
        buffer_is_empty = start >= 0

        loop do
          bytes = if buffer_is_empty
                    @io.read_nonblock([remaining, @chunk_size].max, @buffer, exception: false)
                  else
                    @io.read_nonblock([remaining, @chunk_size].max, exception: false)
                  end

          case bytes
          when String
            if buffer_is_empty
              @offset = start
              @buffer.force_encoding(ENCODING) if @buffer.encoding != ENCODING
            remaining -= bytes.bytesize

            return if !force_size || remaining <= 0
          when :wait_readable
            @offset -= buffer_size if buffer_is_empty && @buffer.empty?

            raise Timeout::Error unless @io.wait_readable(@timeout)
          when nil
            raise EOFError
          else
            raise SystemCallError, 'Unhandled read_nonblock return value'
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength
    end
  end
end
