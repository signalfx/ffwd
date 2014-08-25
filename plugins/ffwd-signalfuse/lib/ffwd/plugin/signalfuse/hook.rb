# $LICENSE
# Copyright 2013-2014 SignalFuse All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'json'

require_relative 'utils'
require_relative 'version'
require 'ffwd/logging'

require 'ffwd/flushing_output_hook'

module FFWD::Plugin::Signalfuse
  class Hook < FFWD::FlushingOutputHook
    include FFWD::Logging

    API_PATH = "/v1/datapoint"

    def initialize url, apitoken
      @c = nil
      @url = url
      @apitoken = apitoken
    end

    def active?
      not @c.nil?
    end

    def connect
      @c = EM::HttpRequest.new(@url)
    end

    def close
      @c.close
      @c = nil
    end

    def send metrics
      headers = {
        :'Content-Type' => 'application/json',
        :'X-SF-TOKEN' => @apitoken,
        :'User-Agent' => "ffwd/" + FFWD::Plugin::Signalfuse::VERSION
      }
      metrics = Utils.make_metrics(metrics)
      body = ""
      metrics.each do |m|
        body += JSON.dump(m)
      end

      http_post = @c.post(
        :path => API_PATH,
        :head => headers,
        :body => body)

      http_post.errback { |http|
        log.warn("HTTP post error: error=#{http.error}/resp=#{http.response}")
      }

      http_post.callback { |http|
        if http.response_header.status != 200
          log.warning("Could not post points: error=#{http.error}/resp=#{http_post.response}/status=#{http.response_header.status}")
        end
      }

      http_post
    end

    def reporter_meta
      {:component => :signalfuse}
    end
  end
end
