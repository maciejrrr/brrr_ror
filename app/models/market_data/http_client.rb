require "json"
require "net/http"
require "timeout"
require "uri"

module MarketData
  class HttpClient
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_TIMEOUT = 10
    MAX_RETRY_AFTER = 60

    def initialize(base_url:, max_retries: DEFAULT_MAX_RETRIES, timeout: DEFAULT_TIMEOUT, sleeper: ->(seconds) { sleep(seconds) })
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @max_retries = max_retries
      @timeout = timeout
      @sleeper = sleeper
    end

    def get_json(path, params: {})
      uri = URI.join(@base_url, path.delete_prefix("/"))
      uri.query = URI.encode_www_form(params) if params.any?

      attempts = 0
      loop do
        response = request(uri)
        begin
          return JSON.parse(response.body)
        rescue JSON::ParserError => error
          raise MarketData::Error, "Invalid JSON from provider: #{error.message}"
        end
      rescue MarketData::ProviderUnavailable
        raise
      rescue StandardError => error
        raise unless retryable?(error) && attempts < @max_retries

        delay = retry_delay(error, attempts)
        raise if delay == :abort

        @sleeper.call(delay)
        attempts += 1
      end
    end

    private
      def request(uri)
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @timeout,
          read_timeout: @timeout
        ) do |http|
          http.get(uri.request_uri)
        end

        case response
        when Net::HTTPSuccess
          response
        when Net::HTTPTooManyRequests
          raise HttpError.new(response.code.to_i, response.body, retry_after: retry_after(response))
        else
          if response.code.to_i == 418
            raise MarketData::ProviderUnavailable.new(
              "Market data provider rejected the request (#{response.code})",
              retry_after: retry_after(response)
            )
          end

          raise HttpError.new(response.code.to_i, response.body)
        end
      rescue Timeout::Error, SocketError, SystemCallError => error
        raise NetworkError, error.message
      end

      def retryable?(error)
        error.is_a?(NetworkError) || (error.is_a?(HttpError) && (error.status == 429 || error.status >= 500))
      end

      def retry_delay(error, attempt)
        default_delay = 2**attempt
        return default_delay unless error.respond_to?(:retry_after)

        advised = error.retry_after
        return default_delay if advised.nil?
        return :abort if advised > MAX_RETRY_AFTER

        advised
      end

      def retry_after(response)
        value = response["retry-after"]
        return if value.blank?

        seconds = Integer(value, exception: false)
        return seconds if seconds && seconds >= 0

        begin
          parsed_time = Time.httpdate(value)
          diff = (parsed_time - Time.current).ceil
          [ diff, 0 ].max
        rescue ArgumentError
          nil
        end
      end

      class NetworkError < MarketData::Error; end
      class HttpError < MarketData::Error
        attr_reader :status, :retry_after

        def initialize(status, body, retry_after: nil)
          @status = status
          @retry_after = retry_after
          super("Market data provider returned HTTP #{status}: #{body.to_s.first(200)}")
        end
      end
  end
end
