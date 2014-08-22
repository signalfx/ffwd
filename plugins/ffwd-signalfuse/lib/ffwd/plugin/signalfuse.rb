# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
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

require 'eventmachine'
require 'em-http'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/reporter'
require 'ffwd/flushing_output'

require_relative 'signalfuse/hook'

module FFWD::Plugin::Signalfuse
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "signalfuse"

  DEFAULT_URL = "https://api.signalfuse.com"
  DEFAULT_FLUSH_INTERVAL = 1
  DEFAULT_BUFFER_LIMIT = 10000

  def self.setup_output config
    config[:url] ||= DEFAULT_URL
    config[:flush_interval] ||= DEFAULT_FLUSH_INTERVAL
    config[:buffer_limit] ||= DEFAULT_BUFFER_LIMIT

    unless config[:apitoken]
      raise "apitoken must be specified"
    end

    hook = Hook.new(config[:url], config[:apitoken])

    FFWD.flushing_output log, hook, config
  end
end
