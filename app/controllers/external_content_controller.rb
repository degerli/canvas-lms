#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class ExternalContentController < ApplicationController
  protect_from_forgery :except => [:selection_test]
  def success
    @retrieved_data = {}
    # TODO: poll for data if it's oembed
    if params[:service] == 'equella'
      params.each do |key, value|
        if key.to_s.match(/\Aeq_/)
          @retrieved_data[key.to_s.gsub(/\Aeq_/, "")] = value
        end
      end
    elsif params[:service] == 'external_tool'
      params[:embed_type] = nil unless ['oembed', 'basic_lti', 'link', 'image', 'iframe'].include?(params[:embed_type])
      @retrieved_data = request.query_parameters
      if @retrieved_data[:url] && ['oembed', 'basic_lti'].include?(params[:embed_type])
        begin
          uri = URI.parse(@retrieved_data[:url])
          unless uri.scheme
            value = "http://#{value}"
            uri = URI.parse(value)
          end
          @retrieved_data[:url] = uri.to_s
        rescue URI::InvalidURIError
          @retrieved_data[:url] = nil
        end
      end
    end
    @headers = false
  end
  
  def oembed_retrieve
    endpoint = params[:endpoint]
    url = params[:url]
    uri = URI.parse(endpoint + (endpoint.match(/\?/) ? '&url=' : '?url=') + CGI.escape(url) + '&format=json')
    res = Net::HTTP.get(uri) rescue "{}"
    data = JSON.parse(res) rescue {}
    if data['type']
      if data['type'] == 'photo' && data['url'].try(:match, /^http/)
        @retrieved_data = {
          :embed_type => 'image',
          :url => data['url'],
          :width => data['width'].to_i,   # width and height are required according to the spec
          :height => data['height'].to_i,
          :alt => data['title']
        }
      elsif data['type'] == 'link' && data['url'].try(:match, /^(http|https|mailto)/)
        @retrieved_data = {
          :embed_type => 'link',
          :url => data['url'] || params[:url],
          :title => data['title'],
          :text => data['title']
        }
      elsif data['type'] == 'video' || data['type'] == 'rich'
        @retrieved_data = {
          :embed_type => 'rich_content',
          :html => data['html']
        }
      end
    else
      @retrieved_data = {
        :embed_type => 'error',
        :message => t("#application.errors.invalid_oembed_url", "There was a problem retrieving this resource. The external tool provided invalid information about the resource.")
      }
    end
    render :json => @retrieved_data.to_json
  end
  
  def selection_test
    @headers = false
  end
  
  def cancel
    @headers = false
  end
end
