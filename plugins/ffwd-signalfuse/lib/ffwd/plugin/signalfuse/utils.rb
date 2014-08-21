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

module FFWD::Plugin::Signalfuse
  module Utils
    def self.make_metrics buffer
      datapoints = []

      buffer.each do |m|
        datapoints << {
          :source => safe_string(m.host),
          :metric => safe_string(m.key),
          :value => m.value
        }
      end

      return datapoints
    end

    def self.safe_string string
      # : and ' ' make searching complicated
      string = string.to_s
      string = string.gsub ' ', '_'
      string.gsub ':', '_'
    end
  end
end
