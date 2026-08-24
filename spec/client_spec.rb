# frozen_string_literal: true

require "estate/jobs/client"
require "socket"

RSpec.describe Estate::Jobs::Client do
  # A one-request HTTP server in-process: no WebMock dependency, real sockets.
  def with_server(status, body)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    thread = Thread.new do
      loop do
        client = server.accept rescue break
        request = client.readuntil("\r\n\r\n") rescue ""
        client.print "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
        client.close
      end
    end
    yield "http://127.0.0.1:#{port}/internal/jobs"
  ensure
    thread&.kill
    server&.close
  end

  it "returns the parsed payload on success" do
    with_server(200, '{"app":"X","solid_queue":{}}') do |url|
      result = described_class.fetch(url, token: "t")
      expect(result[:ok]).to be(true)
      expect(result[:payload][:app]).to eq("X")
    end
  end

  it "reports non-200 as words, not exceptions" do
    with_server(401, '{"error":"unauthorized"}') do |url|
      result = described_class.fetch(url, token: "wrong")
      expect(result[:ok]).to be(false)
      expect(result[:error]).to eq("HTTP 401")
    end
  end

  it "reports an unreachable reporter as words" do
    result = described_class.fetch("http://127.0.0.1:1/internal/jobs", token: "t", timeout: 1)
    expect(result[:ok]).to be(false)
    expect(result[:error]).to be_present
  end
end
